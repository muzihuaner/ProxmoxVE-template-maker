#!/bin/bash
set -e 

# =================================================================
# 1. 环境依赖检查
# =================================================================
if ! command -v virt-customize &> /dev/null; then
    echo "--- 正在安装必要工具: libguestfs-tools ---"
    apt update && apt install -y libguestfs-tools wget
fi

# =================================================================
# 2. 配置区域
# =================================================================
STORAGE="local"       # 存储 ID (支持 Directory/LVM/ZFS)
BRIDGE="vmbr0"        # 默认网桥
DISK_SIZE="40G"       # 自动扩容的目标大小

declare -A IMAGES
IMAGES=(
    ["1"]="Debian-13|https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    ["2"]="Debian-12|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
    ["3"]="Ubuntu-22.04|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    ["4"]="Ubuntu-24.04|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ["5"]="Rocky-9|https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
    ["6"]="AlmaLinux-9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
)

# =================================================================
# 3. 交互与准备
# =================================================================
echo "====================================================="
echo "       Proxmox Cloud-Init Template Creator"
echo "====================================================="
for key in $(echo ${!IMAGES[@]} | tr ' ' '\n' | sort -n); do
    NAME=$(echo ${IMAGES[$key]} | cut -d'|' -f1)
    echo "  $key) $NAME"
done

read -p "请选择系统编号 [1-6]: " CHOICE
read -p "请输入欲创建的 VM ID (建议 9000+): " VMID

SELECTED=${IMAGES[$CHOICE]}
if [ -z "$SELECTED" ]; then echo "错误: 无效选择"; exit 1; fi

OS_NAME=$(echo $SELECTED | cut -d'|' -f1)
IMG_URL=$(echo $SELECTED | cut -d'|' -f2)
IMG_FILE=$(basename $IMG_URL)

# 下载镜像
if [ ! -f "$IMG_FILE" ]; then
    echo "--- 正在下载 $OS_NAME 镜像 ---"
    wget -q --show-progress -O "$IMG_FILE" "$IMG_URL"
fi

# =================================================================
# 4. 离线注入配置 (核心修复部分)
# =================================================================
echo "--- 正在外科手术式修改镜像配置 ---"

virt-customize -a "$IMG_FILE" \
    --install qemu-guest-agent,cloud-init \
    --run-command "rm -f /etc/ssh/sshd_config.d/*.conf" \
    --run-command "sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config" \
    --run-command "sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config" \
    --run-command "echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config" \
    --run-command "echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config" \
    --run-command "systemctl enable qemu-guest-agent" \
    --run-command "userdel -r ubuntu || userdel -r debian || userdel -r cloud-user || true" \
    --truncate /etc/machine-id \
    --run-command "rm -f /etc/ssh/ssh_host_*" \
    --run-command "cloud-init clean --logs" \
    --run-command "find /var/log -type f -exec truncate -s 0 {} \;"

# =================================================================
# 5. 构建 PVE 虚拟机
# =================================================================
echo "--- 正在创建虚拟机并导入磁盘 (ID: $VMID) ---"

# 创建 VM 基础配置
qm create $VMID --name "tpl-$OS_NAME" --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE

# 导入磁盘：使用 import-from 自动处理路径与命名
qm set $VMID --scsihw virtio-scsi-pci \
    --scsi0 $STORAGE:0,import-from=$(pwd)/$IMG_FILE,discard=on

# 添加 Cloud-Init CD-ROM
qm set $VMID --ide2 $STORAGE:cloudinit

# 关键系统设置
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --serial0 socket --vga serial0
qm set $VMID --agent enabled=1

# 调整磁盘大小
echo "--- 扩展磁盘空间至 $DISK_SIZE ---"
qm disk resize $VMID scsi0 $DISK_SIZE

# 转换成模版
echo "--- 转换为 PVE 模版 ---"
qm template $VMID

echo "====================================================="
echo "  创建成功！"
echo "  模版名称: tpl-$OS_NAME"
echo "  模版 ID:  $VMID"
echo "====================================================="
echo "使用建议："
echo "1. 在部署(Clone)前，请在 Web UI 的 Cloud-Init 栏目设置用户密码。"
echo "2. 建议先点击 'Regenerate Image' (重生成) 再启动。"
echo "====================================================="