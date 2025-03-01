# ProxmoxVE 云镜像模板生成工具
## 一、工具简介

本脚本用于自动化创建基于 Cloud-Init 的 ProxmoxVE 虚拟机模板，支持主流 Linux 发行版的云镜像转换，适用于快速部署标准化云主机环境。

## 二、核心功能

- ✅ 自动下载官方云镜像
- ✅ 自动配置 Cloud-Init 参数
- ✅ 自动转换虚拟机模板
- ✅ 支持多镜像批量处理
- ✅ 默认启用 QEMU Guest Agent
- ✅ 自动扩展磁盘空间(+10G)
- ✅ 预置主流 Linux 发行版镜像

## 三、参数说明

| 参数位置 | 必选 | 说明                    | 默认值   |
| :------- | :--- | :---------------------- | :------- |
| 1        | 是   | 存储名称 (如 local-lvm) | 无       |
| 2        | 是   | 网络桥接 (如 vmbr0)     | 无       |
| 3        | 否   | 初始用户名              | root     |
| 4        | 否   | 初始密码                | password |
| 5        | 否   | 镜像名称/VMID/全部镜像  | 全部镜像 |

## 四、使用示例
```
wget https://cdn.jsdelivr.net/gh/muzihuaner/ProxmoxVE-template-maker@main/create_template.sh
chmod +x template-maker.sh
```
### 1. 创建所有预置模板

```
./create_template.sh local-lvm vmbr0
```

### 2. 创建指定系统模板（按名称）

```
./create_template.sh local-lvm vmbr0 myuser MyP@ssw0rd ubuntu2204-jammy
```

### 3. 创建指定系统模板（按VMID）

```
./create_template.sh local-lvm vmbr0 admin Admin1234 2001
```

### 4. 自定义认证信息

```
./create_template.sh local-lvm vmbr0 clouduser Cloud@123
```

## 五、预置镜像列表

| VMID | 系统名称          | 下载源地址                      |
| :--- | :---------------- | :------------------------------ |
| 2000 | ubuntu2204-jammy  | 清华大学镜像站 Ubuntu 22.04 LTS |
| 2001 | debian12-bookworm | Debian 官方云镜像               |
| 2003 | almalinux8        | AlmaLinux 8 官方镜像            |
| 2005 | rockylinux9       | RockyLinux 9 官方镜像           |

（完整列表请查看脚本内 os_images 数组）

## 六、注意事项

1. **环境要求**
   - 需在 ProxmoxVE 6.0+ 环境运行
   - 确保存储空间 ≥20GB
   - 节点需配置好网络桥接
2. **权限要求**
   - 使用 root 用户执行
   - 确保有存储目录写入权限
3. **网络要求**
   - 节点需能访问互联网下载镜像
   - 建议配置国内镜像源加速下载
4. **模板特性**
   - 默认配置：2核CPU/2GB内存
   - 使用 virtio-scsi 磁盘控制器
   - 启用 DHCP 自动获取IP

## 七、维护建议

1. **镜像更新**
   - 定期检查脚本内镜像URL有效性
   - 通过修改 os_images 数组添加新系统
2. **配置调整**
   - 内存/CPU参数：修改 `qm create` 命令参数
   - 磁盘大小：调整 `qm resize` 命令数值
   - 添加SSH密钥：增加 `--sshkey` 参数
3. **日志查看**

```
# 查看虚拟机创建日志
tail -f /var/log/pve/tasks/active

# 查看 Cloud-Init 初始化日志
qm cloudinit dump <vmid> user
```

## 八、常见问题

**Q1: 镜像下载失败怎么办？**

- 检查网络连接状态
- 尝试手动访问镜像URL
- 更换镜像源地址

**Q2: 出现 "qm command not found" 错误**

- 确认在 ProxmoxVE 节点执行
- 检查是否使用 root 用户

**Q3: 虚拟机无法获取IP地址**

- 检查网络桥接配置
- 验证 Cloud-Init 配置：`qm cloudinit dump <vmid> network`

**Q4: 如何删除已创建的模板？**

```
qm destroy <vmid> --purge
rm /var/lib/vz/images/<vmid>/*
```

**Q5: 自定义镜像支持哪些格式？**

- 支持 .img / .qcow2 格式
- 需包含 cloud-init 组件
