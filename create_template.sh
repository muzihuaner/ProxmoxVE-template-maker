#!/bin/bash
# ProxmoxVE Cloud Image Template Generator
# Supports: Ubuntu/Debian/CentOS/Rocky/AlmaLinux/Fedora
# Usage: ./create-cloud-template.sh

set -euo pipefail

# 配置区域 - 根据实际环境修改
STORAGE="local"       # Proxmox存储名称
BRIDGE="vmbr0"            # 网络桥接接口
MEMORY="2048"             # 内存(MB)
CORES="2"                 # CPU核心数
DISK_SIZE="10G"           # 磁盘扩展大小
SSH_KEY=""                # 可选SSH公钥路径(如 ~/.ssh/id_rsa.pub)

# 云镜像定义 (名称,下载URL,默认用户名)
declare -A CLOUD_IMAGES=(
  ["ubuntu-24.04"]="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img ubuntu"
  ["debian-12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 debian"
  ["centos-9"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 centos"
  ["rocky-9"]="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2 rocky"
  ["alma-9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2 almalinux"
  ["fedora-42"]="https://hkg.mirror.rackspace.com/fedora/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2 fedora"
)

# 检查依赖项
check_dependencies() {
  for cmd in wget qm virt-customize; do
    if ! command -v $cmd &> /dev/null; then
      echo "错误: 未找到 $cmd 命令"
      exit 1
    fi
  done
}

# 下载镜像函数
download_image() {
  local url=$1
  local filename=$(basename "$url")
  local save_path="/tmp/$filename"
  
  if [ ! -f "$save_path" ]; then
    echo "正在下载: $filename"
    wget --show-progress -qO "$save_path" "$url" || {
      echo "下载失败: $url"
      rm -f "$save_path"
      exit 1
    }
  else
    echo "使用缓存: $filename"
  fi
  echo "$save_path"
}

# 配置Cloud-Init
configure_cloudinit() {
  local vm_id=$1
  local user=$2
  
  echo "正在配置Cloud-Init (VMID: $vm_id)"
  qm set $vm_id --ciuser "$user" \
    --citype nocloud \
    --ide2 "$STORAGE:cloudinit" \
    --sshkeys "${SSH_KEY:-}" \
    --ipconfig0 "ip=dhcp" \
    --agent enabled=1 \
    --autostart 1
}

# 主处理函数
process_image() {
  local name=$1
  local url=${2% *}
  local user=${2##* }
  local filename=$(basename "$url")
  local vm_id=""
  
  # 为不同系统分配唯一VMID
  case $name in
    ubuntu*)   vm_id="9000" ;;
    debian*)   vm_id="9001" ;;
    centos*)   vm_id="9002" ;;
    rocky*)    vm_id="9003" ;;
    alma*)     vm_id="9004" ;;
    fedora*)   vm_id="9005" ;;
    *)         vm_id="9006" ;;
  esac

  echo -e "\n开始处理: $name (用户: $user)"
  
  # 检查VMID是否已存在
  if qm list | grep -q "^ $vm_id "; then
    echo "模板 $vm_id 已存在，跳过创建"
    return
  fi

  # 下载镜像
  local img_path=$(download_image "$url")
  
  # 创建虚拟机
  echo "创建虚拟机 (VMID: $vm_id)"
  qm create $vm_id --name "$name" --memory $MEMORY --cores $CORES --net0 virtio,bridge=$BRIDGE
  qm importdisk $vm_id "$img_path" $STORAGE
  qm set $vm_id --scsihw virtio-scsi-pci --scsi0 "$STORAGE:vm-$vm_id-disk-0"
  qm set $vm_id --boot order=scsi0
  
  # 扩展磁盘空间
  echo "扩展磁盘: +$DISK_SIZE"
  qm resize $vm_id scsi0 "+$DISK_SIZE"
  
  # 配置Cloud-Init
  configure_cloudinit $vm_id "$user"
  
  # 安装QEMU Guest Agent
  echo "安装QEMU Guest Agent"
  virt-customize -a "$img_path" --install qemu-guest-agent --run-command "systemctl enable qemu-guest-agent"
  
  # 转换为模板
  echo "转换为模板"
  qm set $vm_id --description "自动生成的云镜像模板"
  qm template $vm_id
  
  echo "成功创建模板: $name (VMID: $vm_id)"
}

# 主执行流程
main() {
  check_dependencies
  echo -e "\n===== ProxmoxVE 云镜像生成器 ====="
  
  # 处理所有镜像
  for name in "${!CLOUD_IMAGES[@]}"; do
    process_image "$name" "${CLOUD_IMAGES[$name]}"
  done

  echo -e "\n所有操作已完成! 模板列表:"
  qm list | grep -E "$(printf '%s|' "${!CLOUD_IMAGES[@]}" | sed 's/|$//')"
}

# 执行主函数
main
