# Proxmox VE Cloud-Init 模版全自动创建脚本

这是一个用于 **Proxmox VE (PVE)** 的 Shell 脚本，旨在通过官方 Cloud-Init 镜像快速、自动化地生成开箱即用的虚拟机模版。

### 🚀 核心功能

- **一键集成**：自动下载官方镜像、创建 VM、配置硬件、导入磁盘并转换为模版。
- **外科手术式配置**：利用 `virt-customize` 在离线状态下注入配置，无需手动开机进入系统。
- **SSH 强力开启**：自动强制开启 Root 登录和密码认证，移除 `sshd_config.d` 中的官方限制。
- **极致兼容性**：支持本地目录 (Directory)、LVM、ZFS 等多种 PVE 存储后端。
- **预装工具**：自动安装 `qemu-guest-agent`，确保 PVE 面板能显示 VM IP 地址。

------

## 🛠️ 准备工作

在运行脚本之前，请确保你的 PVE 宿主机已安装 `libguestfs-tools`（用于修改镜像内容）：

```
apt update && apt install -y libguestfs-tools wget 
```

------

## 📖 使用指南

1. **下载脚本**：将代码保存为 `create_template.sh`。

2. **赋予执行权限**：

   ```
   chmod +x create_template.sh
   ```

3. **运行脚本**：

   ```
   ./create_template.sh
   ```

4. **交互操作**：根据提示选择你需要的操作系统，并输入一个唯一的 VM ID（建议使用 `9000` 以上的 ID 以防冲突）。

------

## 📝 脚本逻辑说明

脚本遵循以下标准流程，确保生成的模版 100% 可用：

1. **基础系统分区**：采用官方 Cloud 镜像，确保根分区位于末尾，配合 `cloud-utils-growpart` 实现首启动自动扩容。
2. **SSH 访问控制**：
   - 删除 `/etc/ssh/sshd_config.d/*.conf` 以防止配置覆盖。
   - 在 `/etc/ssh/sshd_config` 中强制添加 `PermitRootLogin yes`。
   - 强制添加 `PasswordAuthentication yes`。
3. **系统清理 (Cleanup)**：
   - 清除机器 ID (`/etc/machine-id`) 以避免网络冲突。
   - 移除残留的默认用户（如 `ubuntu`、`debian` 等）。
   - 清理 SSH 主机密钥，确保克隆出的 VM 重新生成唯一的密钥。
   - 排空系统日志和 Bash 历史记录。
4. **硬件层配置**：
   - 默认开启 **QEMU Guest Agent**。
   - 启用 **Serial Console** (串口控制台)，支持在 Web 界面使用 `xterm.js`。
   - 默认分配 **2 核 / 2G 内存 / 40G 磁盘**（可在脚本顶部配置区修改）。

------

## ⚠️ 注意事项

- **Cloud-Init 设置**：模版创建完成后，在 PVE 界面克隆（Clone）出新 VM 时，请务必在 **Cloud-Init** 选项卡中设置 **User** (如 root) 和 **Password**，然后点击 **Regenerate Image** (重生成) 后再启动。
- **磁盘缩减**：脚本可以将磁盘扩容（如 40G），但无法将官方镜像的原有大小进行缩减。
- **存储路径**：脚本使用 `import-from` 语法

------

## 📂 支持的镜像列表

- Debian 12 / 13 (Trixie)
- Ubuntu 22.04 / 24.04
- Rocky Linux 9
- AlmaLinux 9

------

**Tip**: 建议将此脚本放在 `/root` 目录下运行，它会在同级目录下下载并缓存 `.qcow2` 镜像文件。
