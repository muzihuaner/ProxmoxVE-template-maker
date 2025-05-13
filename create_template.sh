#!/bin/bash

# 设置错误处理
set -e
trap 'echo "错误发生在第 $LINENO 行"; exit 1' ERR

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_MEMORY=2048
DEFAULT_CORES=2
DISK_RESIZE="+10G"

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示使用方法
show_usage() {
    echo "用法: $0 <存储名称> <网络桥接> [初始用户名] [初始密码] [镜像名称或VMID]"
    echo "示例: $0 local-lvm vmbr0 myuser mypass ubuntu2204-jammy"
    exit 1
}

# 参数校验
[[ $# -lt 2 ]] && show_usage

# 参数定义
storage=$1
bridge=$2
username=${3:-"root"}
password=${4:-"password"}
image_arg=${5:-"全部镜像"}

# 操作系统镜像列表
declare -A os_images=(
    ["2000,ubuntu2204-jammy"]="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cloud-images/jammy/current/jammy-server-cloudimg-amd64.img"
    ["2001,debian12-bookworm"]="https://cloud.debian.org/images/cloud/bookworm/current/debian-12-generic-amd64.qcow2"
    ["2002,debian11-bullseye"]="https://cloud.debian.org/images/cloud/bullseye/current/debian-11-generic-amd64.qcow2"
    ["2003,almalinux8"]="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
    ["2004,almalinux9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    ["2005,rockylinux9"]="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
    ["2006,rockylinux8"]="https://dl.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2"
)

# 验证存储和网桥是否存在
check_prerequisites() {
    if ! pvesm status | grep -q "^$storage"; then
        log_error "存储 '$storage' 不存在"
        exit 1
    fi
    
    if ! ip link show "$bridge" >/dev/null 2>&1; then
        log_error "网桥 '$bridge' 不存在"
        exit 1
    fi
}

# 获取磁盘路径
get_disk_path() {
    local storage_type=$(pvesm status | awk -v storage="$storage" '$1 == storage {print $2}')
    case $storage_type in
        dir|nfs|cifs)
            echo "$storage:$1/vm-$1-disk-0.qcow2"
            ;;
        lvm|zfs)
            echo "$storage:vm-$1-disk-0"
            ;;
        *)
            log_error "未知存储类型: $storage_type"
            exit 1
            ;;
    esac
}

# 创建虚拟机模板
create_template() {
    local vmid=$1
    local img_name=$2
    local img_url=$3
    local temp_dir
    
    log_info "开始处理: ${img_name} (VMID: ${vmid})"
    
    # 检查VMID是否存在
    if qm status "$vmid" >/dev/null 2>&1; then
        log_warn "VMID ${vmid} 已存在，跳过处理..."
        return
    }
    
    # 创建临时目录并下载镜像
    temp_dir=$(mktemp -d)
    local img_file="${temp_dir}/$(basename "${img_url}")"
    
    log_info "正在下载镜像..."
    if ! wget -q --show-progress "${img_url}" -O "${img_file}"; then
        log_error "镜像下载失败"
        rm -rf "${temp_dir}"
        return
    }
    
    # 创建和配置虚拟机
    log_info "正在创建和配置虚拟机..."
    qm create "${vmid}" --name "${img_name}-template" \
        --memory ${DEFAULT_MEMORY} --cores ${DEFAULT_CORES} --cpu host \
        --net0 virtio,bridge="${bridge}" \
        --agent enabled=1 || { log_error "虚拟机创建失败"; return; }
    
    # 导入和配置磁盘
    qm importdisk "${vmid}" "${img_file}" "${storage}" --format qcow2
    local disk_path=$(get_disk_path "$vmid")
    qm set "${vmid}" --scsihw virtio-scsi-pci --scsi0 "$disk_path"
    
    # 配置Cloud-Init
    log_info "正在配置Cloud-Init..."
    qm set "${vmid}" --ide2 "${storage}:cloudinit" \
        --boot c --bootdisk scsi0 \
        --serial0 socket --vga serial0 \
        --ciuser "${username}" \
        --cipassword "${password}"
    
    # 调整磁盘大小
    log_info "正在调整磁盘大小..."
    qm resize "${vmid}" scsi0 ${DISK_RESIZE}
    
    # 转换为模板
    qm template "${vmid}"
    log_info "模板创建成功: VMID ${vmid}"
    
    # 清理
    rm -rf "${temp_dir}"
}

# 主程序
main() {
    log_info "ProxmoxVE Cloud-Init 模板生成工具 v2.0"
    log_info "作者: muzihuaner"
    echo "------------------------"
    
    check_prerequisites
    
    # 选择镜像
    selected_images=()
    if [[ "$image_arg" == "全部镜像" ]]; then
        log_info "处理所有镜像..."
        selected_images=("${!os_images[@]}")
    else
        log_info "查找匹配的镜像: $image_arg"
        for key in "${!os_images[@]}"; do
            IFS=',' read -r vmid name <<< "$key"
            if [[ "$image_arg" == "$vmid" || "$image_arg" == "$name" ]]; then
                selected_images+=("$key")
                break
            fi
        done
        
        if [[ ${#selected_images[@]} -eq 0 ]]; then
            log_error "未找到匹配的镜像或VMID: $image_arg"
            exit 1
        fi
    fi
    
    # 处理选中的镜像
    total=${#selected_images[@]}
    current=0
    for key in "${selected_images[@]}"; do
        ((current++))
        IFS=',' read -r vmid img_name <<< "$key"
        log_info "处理进度: [$current/$total] ${img_name}"
        create_template "$vmid" "$img_name" "${os_images[$key]}"
    done
    
    log_info "所有操作已完成!"
}

main