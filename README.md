
# ProxmoxVE 模板生成工具使用说明

## 简介
这是一个用于在 ProxmoxVE 环境中自动创建云镜像模板的工具。支持多种Linux发行版，包括Ubuntu、Debian、AlmaLinux和RockyLinux。

## 系统要求
- ProxmoxVE 7.0或更高版本
- bash shell环境
- 互联网连接
- 足够的存储空间
- wget工具

## 支持的操作系统
- Ubuntu 22.04 (Jammy)
- Debian 12 (Bookworm)
- Debian 11 (Bullseye)
- AlmaLinux 8/9
- RockyLinux 8/9

## 常见 Linux 发行版 Cloud Images 

Ubuntu: https://cloud-images.ubuntu.com/releases/  
Debian: https://cloud.debian.org/images/cloud/  
Almalinux: https://repo.almalinux.org/almalinux/  
Rockylinux：https://dl.rockylinux.org/pub/rocky/

## 安装
1. 下载脚本：
```bash
wget https://raw.githubusercontent.com/muzihuaner/ProxmoxVE-template-maker/main/create_template.sh
```

2. 添加执行权限：
```bash
chmod +x create_template.sh
```

## 使用方法

### 基本语法
```bash
./create_template.sh <存储名称> <网络桥接> [初始用户名] [初始密码] [镜像名称或VMID]
```

### 参数说明
- `存储名称`：必需，ProxmoxVE存储位置（如：local-lvm）
- `网络桥接`：必需，网络桥接接口（如：vmbr0）
- `初始用户名`：可选，默认为"root"
- `初始密码`：可选，默认为"password"
- `镜像名称或VMID`：可选，指定要创建的系统模板，默认创建全部

### VMID对照表
- 2000: Ubuntu 22.04 (Jammy)
- 2001: Debian 12 (Bookworm)
- 2002: Debian 11 (Bullseye)
- 2003: AlmaLinux 8
- 2004: AlmaLinux 9
- 2005: RockyLinux 9
- 2006: RockyLinux 8

### 示例用法

1. 创建所有系统模板：
```bash
./create_template.sh local-lvm vmbr0
```

2. 创建指定系统模板（使用VMID）：
```bash
./create_template.sh local-lvm vmbr0 root password 2000
```

3. 创建指定系统模板（使用系统名称）：
```bash
./create_template.sh local-lvm vmbr0 root password ubuntu2204-jammy
```

4. 使用自定义用户名和密码：
```bash
./create_template.sh local-lvm vmbr0 myuser mypassword
```

## 注意事项
1. 确保有足够的存储空间用于下载和创建模板
2. 执行脚本需要root权限
3. 模板创建过程中会临时占用额外存储空间
4. VMID如果已存在会自动跳过
5. 请确保网络连接稳定，避免下载中断

## 故障排除
1. 如果出现"存储不存在"错误，请检查存储名称是否正确
2. 如果出现"网桥不存在"错误，请检查网络配置
3. 下载失败时，检查网络连接和镜像URL是否可访问
4. 如果创建失败，检查存储空间是否充足

## 默认配置
- 内存：2048MB
- CPU核心数：2
- 磁盘格式：qcow2
- 额外磁盘空间：+10G
- 网卡类型：virtio
- SCSI控制器：virtio-scsi-pci