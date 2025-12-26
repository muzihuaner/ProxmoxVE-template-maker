# Proxmox VE Cloud-Init 模板自动化工具使用指南

本脚本用于在 **Proxmox VE (PVE)** 环境下，通过官方 Cloud 镜像一键创建经过优化的 **Debian/Ubuntu/Rocky** 虚拟机模板。

## 1. 核心功能

- **智能下载**：自动检测本地镜像，支持断点续传，避免重复下载。
- **离线预配置**：利用 `virt-customize` 直接注入 `qemu-guest-agent`、设置时区、安装基础工具（htop, curl 等）。
- **自动扩容**：将官方默认的小容量镜像自动扩展至 **30GB**。
- **存储兼容**：完美支持 `local` (Directory) 和 `local-lvm` (LVM-Thin) 存储。
- **交互式操作**：支持自定义 VM ID 和 模板名称。

------

## 2. 前置环境准备

在运行脚本前，请确保 PVE 宿主机已安装必要工具：

Bash

```
apt update && apt install -y libguestfs-tools wget
```

------

## 3. 快速开始

### 第一步：获取脚本

将脚本内容保存为 `make_template.sh`。

### 第二步：配置环境参数（可选）

如果你的存储名称不是默认的 `local`，请编辑脚本前几行：

- `STORAGE="local"`：修改为你的存储 ID（可通过 `pvesm status` 查看）。
- `DISK_SIZE="30G"`：修改你希望的默认硬盘大小。

### 第三步：赋予权限并运行

Bash

```
chmod +x make_template.sh
./make_template.sh
```

------

## 4. 脚本执行流程

1. **选择系统**：从菜单中选择想要创建的操作系统。
2. **设置 ID/名称**：输入 VM ID（默认 1000）和 模板名。
3. **下载与注入**：脚本自动处理镜像并注入驱动。
4. **创建与转换**：自动创建 VM，挂载磁盘，并将其转换为 **Template（模板）**。

------

## 5. 模板使用后续操作（重要）

模板创建成功后，无法直接启动，你需要通过 **“克隆 (Clone)”** 的方式使用它：

### 1. 克隆虚拟机

- 在 PVE 网页界面，右键点击该模板 -> 选择 **Clone**。
- 模式建议选择 **Full Clone**（独立性强）或 **Linked Clone**（节省空间）。

### 2. 配置 Cloud-Init (必须)

在启动克隆出的虚拟机之前，点击该 VM 的 **Cloud-Init** 选项卡：

- **User / Password**：设置你的登录用户名和密码。
- **SSH Public Key**：建议填入你的公钥，实现免密登录。
- **IP Config**：默认是 DHCP，如需静态 IP 请在此修改。
- **重生成镜像**：修改完上述项后，点击顶部的 **Regenerate Image**。

### 3. 启动

点击 **Start**，系统会自动完成初始化，你可以直接通过 SSH 或 Console 登录。
