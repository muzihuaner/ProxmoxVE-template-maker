# ProxmoxVE-template-maker
ProxmoxVE Cloud init 系统模板制作脚本
## 功能概述

提示：建议在操作前备份重要数据，首次使用可在测试环境验证功能

本脚本用于自动完成以下操作：

1. 从官方源下载云镜像（支持 Ubuntu/Debian/AlmaLinux/RockyLinux 等）
2. 创建 Proxmox 虚拟机模板
3. 自动配置 cloud-init 初始化参数
4. 支持批量创建和单镜像创建模式

------

## 支持的镜像列表

| VMID | 系统名称          | 备注             |
| :--- | :---------------- | :--------------- |
| 2000 | ubuntu2204-jammy  | Ubuntu 22.04 LTS |
| 2001 | debian12-bookworm | Debian 12        |
| 2002 | debian11-bullseye | Debian 11        |
| 2003 | almalinux8        | AlmaLinux 8      |
| 2004 | almalinux9        | AlmaLinux 9      |
| 2005 | rockylinux9       | RockyLinux 9     |
| 2006 | rockylinux8       | RockyLinux 8     |

------

## 安装步骤

1. 下载脚本

```
wget https://cdn.jsdelivr.net/gh/muzihuaner/ProxmoxVE-template-maker@main/template-maker.sh
```

1. 赋予执行权限

```
chmod +x template-maker.sh
```

------

## 使用方法

### 1. 创建全部模板

```
sudo ./template-maker.sh <存储名称> <网络桥接>
```

示例：

```
sudo ./template-maker.sh local-lvm vmbr0
```

### 2. 创建单个模板

```
sudo ./template-maker.sh <存储名称> <网络桥接> [用户名] [密码] [镜像名称或VMID]
```

示例：

```
# 通过名称指定
sudo ./template-maker.sh local-lvm vmbr0 root password ubuntu2204-jammy

# 通过VMID指定
sudo ./template-maker.sh nfs-storage vmbr1 admin@123 2003
```

------

## 参数说明

| 参数位置 | 必选 | 说明                     | 默认值   |
| :------- | :--- | :----------------------- | :------- |
| 1        | 是   | 存储名称（如 local-lvm） | 无       |
| 2        | 是   | 网络桥接（如 vmbr0）     | 无       |
| 3        | 否   | 初始用户名               | root     |
| 4        | 否   | 初始密码                 | password |
| 5        | 否   | 镜像名称或VMID           | 全部镜像 |

------

## 注意事项

1. 存储要求：
   - 至少需要 10GB 可用空间
   - 支持所有 Proxmox 可用存储类型（local/lvm/ceph/nfs 等）
2. 网络配置：
   - 确保指定的网络桥接（vmbrX）已正确配置
   - 虚拟机默认使用 DHCP 获取IP
3. 权限要求：
   - 需要使用 root 权限运行
   - 需要具有对应存储的写入权限
4. 模板管理：
   - 创建的模板默认使用 VMID 2000-2006
   - 会先清理同名模板和磁盘文件

------

## 常见问题解答

### Q1: 出现 "镜像下载失败" 错误

- 检查网络连接是否正常
- 尝试手动访问镜像 URL 验证可用性
- 查看 `/tmp/images_cache` 目录的写入权限

### Q2: 报错 "存储不存在"

- 使用 `pvesm list` 查看有效存储名称
- 确认存储名称拼写正确（区分大小写）

### Q3: 虚拟机无法启动

- 检查是否启用嵌套虚拟化：

  ```
  grep -E '(vmx|svm)' /proc/cpuinfo
  ```

- 验证 cloud-init 配置：

  ```
  qm cloudinit dump <VMID> user
  ```

### Q4: 权限不足错误

- 使用 `sudo` 运行脚本
- 检查 `/etc/pve/user.conf` 权限设置
