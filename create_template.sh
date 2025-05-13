#!/bin/bash

# 参数校验
if [ $# -lt 2 ]; then
    echo "Usage: $0 <存储名称> <网络桥接> [初始用户名] [初始密码] [镜像名称或VMID]"
    echo "示例: $0 local-lvm vmbr0 myuser mypass ubuntu2204-jammy"
    exit 1
fi

# 参数定义
storage=$1
bridge=$2
username=${3:-"root"}
password=${4:-"password"}
image_arg=${5:-"全部镜像"}

# 操作系统镜像列表
declare -A os_images=(
    ["2000,ubuntu2404"]="https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
    ["2001,debian12"]="https://cloud.debian.org/images/cloud/bookworm/20230612-1409/debian-12-generic-amd64-20230612-1409.qcow2"
    ["2002,debian11"]="https://cloud.debian.org/images/cloud/bullseye/20230601-1398/debian-11-generic-amd64-20230601-1398.qcow2"
    ["2003,almalinux8"]="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
    ["2004,almalinux9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    ["2005,rockylinux9"]="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
    ["2006,rockylinux8"]="https://dl.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2"
)

echo "------------------------"
echo "ProxmoxVE Cloud-Init 模板生成工具"
echo "作者: muzihuaner"
echo "项目地址：https://github.com/muzihuaner/ProxmoxVE-template-maker"
echo "------------------------"

# 选择镜像处理模式
selected_images=()
if [[ "$image_arg" == "全部镜像" ]]; then
    echo "正在处理所有镜像..."
    for key in "${!os_images[@]}"; do
        selected_images+=("$key")
    done
else
    echo "正在查找匹配的镜像: $image_arg"
    found=0
    for key in "${!os_images[@]}"; do
        IFS=',' read -r vmid name <<< "$key"
        if [[ "$image_arg" == "$vmid" || "$image_arg" == "$name" ]]; then
            selected_images+=("$key")
            found=1
        fi
    done
    if [[ $found -eq 0 ]]; then
        echo "错误: 未找到匹配的镜像或VMID: $image_arg"
        exit 1
    fi
fi

# 主处理循环
for key in "${selected_images[@]}"; do
    IFS=',' read -r vmid img_name <<< "$key"
    img_url="${os_images[$key]}"
    
    echo -e "\n正在处理: ${img_name} (VMID: ${vmid})"
    echo "镜像URL: ${img_url}"

    # 检查VMID冲突
    if qm status $vmid >/dev/null 2>&1; then
        echo "警告: VMID ${vmid} 已存在，跳过处理..."
        continue
    fi

    # 创建临时目录
    temp_dir=$(mktemp -d)
    echo "创建临时目录: ${temp_dir}"

    # 下载镜像
    img_file="${temp_dir}/$(basename "${img_url}")"
    echo "正在下载镜像..."
    if ! wget -q --show-progress "${img_url}" -O "${img_file}"; then
        echo "错误: 镜像下载失败!"
        rm -rf "${temp_dir}"
        continue
    fi

    # 创建虚拟机
    echo "正在创建虚拟机..."
    qm create "${vmid}" --name "${img_name}-template" \
        --memory 2048 --cores 2 --cpu host --net0 virtio,bridge="${bridge}" \
        --agent enabled=1 >/dev/null 2>&1

    # 导入磁盘
    echo "正在导入磁盘..."
    qm importdisk "${vmid}" "${img_file}" "${storage}" --format qcow2 >/dev/null 2>&1
    # 配置存储
    echo "正在配置磁盘..."
    # 函数：生成正确的磁盘路径
    get_disk_path() {
    local storage_type=$(pvesm status | awk -v storage="$storage" '$1 == storage {print $2}')
    
    case $storage_type in
        dir|nfs|cifs)  # 需要子目录的存储类型
        echo "$storage:$vmid/vm-$vmid-disk-0.qcow2"
        ;;
        lvm|zfs)       # 直接使用卷名的存储类型
        echo "$storage:vm-$vmid-disk-0"
        ;;
        *)
        echo "未知存储类型: $storage_type"
        exit 1
        ;;
    esac
    }
    disk_path=$(get_disk_path)
    qm set "${vmid}" --scsihw virtio-scsi-pci --scsi0 "$disk_path"> /dev/null 2>&1

    # 配置Cloud-Init
    echo "正在配置Cloud-Init..."
    qm set "${vmid}" --ide2 "${storage}:cloudinit" >/dev/null 2>&1
    qm set "${vmid}" --boot c --bootdisk scsi0 >/dev/null 2>&1
    qm set "${vmid}" --serial0 socket --vga serial0 >/dev/null 2>&1

    # 调整磁盘大小（可选）
    echo "正在调整磁盘大小..."
    qm resize "${vmid}" scsi0 +10G >/dev/null 2>&1

    # 转换为模板
    qm template "${vmid}" >/dev/null 2>&1
    echo "成功创建模板: VMID ${vmid}"

    # 清理临时文件
    rm -rf "${temp_dir}"
done

echo -e "\n所有操作已完成!"
