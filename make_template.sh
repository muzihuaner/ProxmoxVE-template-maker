#!/bin/bash
set -e 

# =================================================================
# 配置区域
# =================================================================
STORAGE="local"       
BRIDGE="vmbr0"
DISK_SIZE="30G"       

declare -A IMAGES
IMAGES=(
    ["1"]="Debian-12|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
    ["2"]="Ubuntu-22.04|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    ["3"]="Ubuntu-24.04|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ["4"]="Rocky-9|https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
)

# =================================================================
# 菜单与检查
# =================================================================
echo "---------------------------------------------------"
echo "   PVE Cloud-Init 模板自动化工具 (Final Fix)"
echo "---------------------------------------------------"

if ! pvesm status -storage $STORAGE >/dev/null 2>&1; then
    echo "错误: 存储 $STORAGE 未找到。"
    exit 1
fi

for key in $(echo ${!IMAGES[@]} | tr ' ' '\n' | sort -n); do
    echo "$key) ${IMAGES[$key]%%|*}"
done
read -p "请选择系统编号 [1-4]: " choice

[[ -z "${IMAGES[$choice]}" ]] && { echo "错误：无效选择！"; exit 1; }

SELECTED_INFO=${IMAGES[$choice]}
OS_NAME=${SELECTED_INFO%%|*}
URL=${SELECTED_INFO##*|}
FILE_NAME=$(basename "$URL")

read -p "请输入虚拟机 ID (默认 1000): " VM_ID
VM_ID=${VM_ID:-1000}
read -p "请输入模板名称 (默认 $OS_NAME-template): " VM_NAME
VM_NAME=$(echo "${VM_NAME:-$OS_NAME-template}" | tr ' _' '-')

# 1. 镜像处理
if [ -f "$FILE_NAME" ]; then
    echo ">>> 使用本地镜像: $FILE_NAME"
else
    echo ">>> 开始下载镜像..."
    wget -c "$URL" -O "$FILE_NAME"
fi

echo ">>> 正在自定义镜像配置..."
virt-customize -a "$FILE_NAME" \
    --install "qemu-guest-agent,htop,curl,net-tools" \
    --timezone "Asia/Shanghai" \
    --run-command "systemctl enable qemu-guest-agent" \
    --firstboot-command "truncate -s 0 /etc/machine-id"

# 2. VM 创建
echo ">>> 正在创建 VM $VM_ID..."
[ "$(qm status $VM_ID 2>/dev/null)" ] && qm destroy $VM_ID --purge

qm create $VM_ID --name "$VM_NAME" --onboot 1 --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE

# 3. 磁盘导入与修复
echo ">>> 正在导入磁盘并扩容..."
# 导入并强制使用 qcow2 格式
IMPORT_OUT=$(qm importdisk $VM_ID "$FILE_NAME" $STORAGE --format qcow2)
# 提取路径
DISK_REF=$(echo "$IMPORT_OUT" | grep -oP "(?<=successfully imported disk ').*(?=')" || true)
if [ -z "$DISK_REF" ]; then
    DISK_REF=$(qm config $VM_ID | grep "unused0" | awk '{print $2}')
fi

# 关键修复点：使用正确的 qm disk resize 命令
qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 "$DISK_REF"
echo ">>> 执行扩容: qm disk resize $VM_ID scsi0 $DISK_SIZE"
qm disk resize $VM_ID scsi0 $DISK_SIZE

# 4. 最后配置
qm set $VM_ID --boot c --bootdisk scsi0
qm set $VM_ID --ide2 $STORAGE:cloudinit
qm set $VM_ID --serial0 socket --vga serial0
qm set $VM_ID --agent enabled=1

echo ">>> 转换为模板..."
qm template $VM_ID

echo "---------------------------------------------------"
echo "所有操作已成功完成！"
echo "您现在可以基于 ID:$VM_ID 进行克隆了。"
echo "---------------------------------------------------"