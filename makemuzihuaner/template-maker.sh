#!/bin/bash

# 操作系统名字和链接，按需自行拓展和更新
declare -A os_images=(
    ["2000,ubuntu2204-jammy"]="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cloud-images/jammy/current/jammy-server-cloudimg-amd64.img"
    ["2001,debian12-bookworm"]="https://cloud.debian.org/images/cloud/bookworm/20230612-1409/debian-12-generic-amd64-20230612-1409.qcow2"
    ["2002,debian11-bullseye"]="https://cloud.debian.org/images/cloud/bullseye/20230601-1398/debian-11-generic-amd64-20230601-1398.qcow2"
    ["2003,almalinux8"]="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
    ["2004,almalinux9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    ["2005,rockylinux9"]="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
    ["2006,rockylinux8"]="https://dl.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2"
)

echo "------------------------"
echo "Auto image maker by muzihuaner"
echo "------------------------"

echo "全部镜像:"
for os_key in "${!os_images[@]}"; do
    IFS=',' read -r vmid os_name <<< "$os_key"
    echo "VMID: $vmid | 名称: $os_name"
done

echo "------------------------"

# 下载操作系统镜像并创建虚拟机
download_image_and_create_vm() {
    local vmid=$1
    local osname=$2
    local image_url=$3

    local image_file="${download_dir}/$(basename "$image_url")"

    echo "下载镜像: $osname"
    if ! wget -q --show-progress -c "$image_url" -O "$image_file"; then
        echo "镜像下载失败: $image_url"
        exit 1
    fi

    # 清理现有虚拟机
    echo "清理现有虚拟机 (VMID: $vmid)..."
    qm stop "$vmid" >/dev/null 2>&1 || echo "停止虚拟机 $vmid 失败，可能未运行"
    if ! qm destroy "$vmid" --destroy-unreferenced-disks=1 --purge=1 >/dev/null 2>&1; then
        echo "删除虚拟机 $vmid 失败，可能不存在"
    fi

    # 创建新虚拟机
    local template_name="Template-$osname"
    echo "创建虚拟机: $template_name (VMID: $vmid)..."
    qm create "$vmid" --name "$template_name" --memory 1024 --net0 virtio,bridge="$vmbr" >/dev/null 2>&1 || exit 1

    echo "导入磁盘到存储 '$storage'..."
    qm disk import "$vmid" "$image_file" "$storage" >/dev/null 2>&1 || exit 1

    echo "配置虚拟机..."
    qm set "$vmid" \
        --ostype l26 \
        --ciuser "$user" \
        --cipassword "$password" \
        --virtio0 "$storage:vm-$vmid-disk-0" \
        --boot c \
        --bootdisk virtio0 \
        --ide2 "$storage:cloudinit" \
        --scsihw virtio-scsi-pci \
        --serial0 socket \
        --vga serial0 >/dev/null 2>&1 || exit 1

    # 转换为模板
    qm template "$vmid" >/dev/null 2>&1 || exit 1

    echo "镜像制作完成: $osname (VMID: $vmid)"
    echo "------------------------"
}

# 参数检查
if [ $# -lt 2 ]; then
    echo "使用方法: $0 <存储名称> <网络桥接> [用户名] [密码] [镜像名称或VMID]"
    echo "示例:"
    echo "创建全部镜像: $0 local-lvm vmbr0"
    echo "创建单个镜像: $0 local-lvm vmbr0 root password ubuntu2204-jammy"
    exit 1
fi

# 参数处理
storage=$1
vmbr=$2
user=${3:-root}          # 默认用户 root
password=${4:-password}  # 默认密码 password
image=${5:-}             # 镜像名称或VMID

# 检查存储是否存在
if ! pvesm list | grep -qw "$storage"; then
    echo "错误: 存储 '$storage' 不存在!"
    exit 1
fi

# 创建下载缓存目录
download_dir="/tmp/images_cache"
mkdir -p "$download_dir"

# 镜像选择逻辑
if [ -n "$image" ]; then
    echo "正在查找镜像: $image..."
    selected_os=""
    for os_key in "${!os_images[@]}"; do
        IFS=',' read -r key_vmid key_osname <<< "$os_key"
        if [[ "$image" == "$key_vmid" || "$image" == "$key_osname" ]]; then
            selected_os="$os_key"
            break
        fi
    done

    if [ -z "$selected_os" ]; then
        echo "错误：没有找到匹配的镜像 (名称或VMID: $image)"
        echo "可用镜像:"
        for os_key in "${!os_images[@]}"; do
            IFS=',' read -r vmid os_name <<< "$os_key"
            echo "  $os_name (VMID: $vmid)"
        done
        exit 1
    fi

    IFS=',' read -r vmid osname <<< "$selected_os"
    echo "开始制作镜像: $osname (VMID: $vmid)"
    download_image_and_create_vm "$vmid" "$osname" "${os_images[$selected_os]}"
else
    echo "开始制作全部镜像..."
    for os_key in "${!os_images[@]}"; do
        IFS=',' read -r vmid osname <<< "$os_key"
        download_image_and_create_vm "$vmid" "$osname" "${os_images[$os_key]}"
    done
    echo "所有镜像制作完成!"
fi
