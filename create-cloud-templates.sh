#!/bin/bash
set -euo pipefail

# 云镜像定义：名称 -> URL 用户名
declare -A CLOUD_IMAGES=(
  ["ubuntu-24.04"]="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img ubuntu"
  ["debian-12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 debian"
  ["centos-9"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 centos"
  ["rocky-9"]="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2 rocky"
  ["alma-9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2 almalinux"
  ["fedora-42"]="https://mirrors.tuna.tsinghua.edu.cn/fedora/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2 fedora"
)

# 全局变量设置（可修改）
STORAGE="local"
VMID_START=9000
DISK_SIZE="30G"         # 默认硬盘大小
BRIDGE="vmbr0"
CPU_CORES=2             # 默认 CPU 核心数
MEMORY_SIZE=2048        # 默认内存大小（MB）
DEFAULT_PASSWORD="changeme"  # 默认登录密码（不安全，仅测试用途）

mkdir -p cloud-images

# 遍历云镜像配置
for image_name in "${!CLOUD_IMAGES[@]}"; do
    IFS=' ' read -r URL USERNAME <<< "${CLOUD_IMAGES[$image_name]}"
    FILE_NAME=$(basename "$URL")
    IMAGE_PATH="cloud-images/$FILE_NAME"

    echo "🔽 正在下载 $image_name ..."
    if [ ! -f "$IMAGE_PATH" ]; then
        wget -O "$IMAGE_PATH" "$URL" || { echo "❌ 下载失败：$URL"; continue; }
    else
        echo "✅ 已存在: $IMAGE_PATH"
    fi

    VMID=$((VMID_START++))
    echo "🛠 创建 VM 模板：$image_name (VMID=$VMID, 用户=$USERNAME, CPU=${CPU_CORES}, MEM=${MEMORY_SIZE}MB)"

    # 创建空 VM
    qm create "$VMID" --name "$image_name" --memory "$MEMORY_SIZE" --cores "$CPU_CORES" \
        --net0 virtio,bridge="$BRIDGE"

    # 导入磁盘
    qm importdisk "$VMID" "$IMAGE_PATH" "$STORAGE" --format qcow2

    # 设置磁盘名（根据存储类型处理）
    DISK_NAME="vm-${VMID}-disk-0"
    if [[ "$STORAGE" == "local" ]]; then
        # 对于目录存储，需要使用子目录格式
        DISK_REF="${STORAGE}:${VMID}/${DISK_NAME}.qcow2"
    else
        # 对于 LVM/ZFS 存储，不需要子目录
        DISK_REF="${STORAGE}:${DISK_NAME}"
    fi

    # 连接磁盘并设置为 scsi0
    qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DISK_REF"

    # 扩展磁盘大小
    qm resize "$VMID" scsi0 "$DISK_SIZE"

    # 添加 Cloud-Init 支持（仅使用密码登录）
    qm set "$VMID" --ide2 "$STORAGE":cloudinit
    qm set "$VMID" --boot c --bootdisk scsi0
    qm set "$VMID" --serial0 socket --vga serial0
    qm set "$VMID" --ciuser "$USERNAME" --cipassword "$DEFAULT_PASSWORD"

    # 转换为模板
    qm template "$VMID"
    echo "✅ 模板 $image_name 创建完成 (VMID=$VMID)"
    echo "-------------------------------------------"
done

echo "🎉 所有云模板生成完成！（仅密码登录，默认密码：$DEFAULT_PASSWORD）"
