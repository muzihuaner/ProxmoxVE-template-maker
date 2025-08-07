# 云镜像批量创建脚本 使用说明

## 脚本功能

- 批量下载多种常用 Linux 云镜像（Ubuntu、Debian、CentOS、Rocky、AlmaLinux、Fedora）
- 在 Proxmox VE 中创建对应 VM 模板
- 配置 Cloud-Init，设置用户密码登录（不使用 SSH 密钥）
- 自动调整虚拟机硬件配置（CPU、内存、磁盘大小、网络）
- 将虚拟机转换为模板，方便后续克隆部署

------

## 使用前准备

1. **运行环境**
    需在 Proxmox VE 节点上以 root 用户运行该脚本，确保 `qm` 命令可用。
2. **网络连接**
    脚本会从互联网下载云镜像，请确保节点可以访问相应镜像地址。
3. **存储配置**
    修改脚本开头的 `STORAGE` 变量，确保其值与你的 Proxmox 存储名称一致（默认 `"local"`）。
4. **网络桥接**
    修改 `BRIDGE` 变量为你的 Proxmox 网络桥接名（默认 `"vmbr0"`）。

------

## 变量配置

| 变量名             | 说明                          | 默认值       |
| ------------------ | ----------------------------- | ------------ |
| `STORAGE`          | Proxmox 存储名称              | `"local"`    |
| `VMID_START`       | 创建 VM 的起始 VMID           | `9000`       |
| `DISK_SIZE`        | VM 磁盘大小                   | `"30G"`      |
| `BRIDGE`           | VM 网络桥接名称               | `"vmbr0"`    |
| `CPU_CORES`        | 虚拟机 CPU 核心数             | `2`          |
| `MEMORY_SIZE`      | 虚拟机内存大小（MB）          | `2048`       |
| `DEFAULT_PASSWORD` | Cloud-Init 设置的默认登录密码 | `"changeme"` |



> 可以根据需要修改以上变量以匹配你的环境和需求。

------

## 运行脚本

```
chmod +x create-cloud-templates.sh
./create-cloud-templates.sh
```

------

## 登录虚拟机

- 云镜像模板创建完成后，可以通过 Proxmox 克隆该模板生成新 VM。
- 使用 Cloud-Init 设置的用户名和密码登录虚拟机（密码默认为脚本中的 `DEFAULT_PASSWORD`，例如 `changeme`）。
- 默认不注入 SSH 公钥，只有密码登录可用。

------

## 注意事项

- **密码登录限制**
   某些云镜像默认禁用密码登录（例如 Ubuntu），你可能需要在模板内手动开启 SSH 密码登录支持（编辑 `/etc/cloud/cloud.cfg`，设置 `ssh_pwauth: true`）。
- **安全性**
   密码登录安全性较低，建议生产环境使用 SSH 密钥登录并设置强密码。
- **磁盘格式**
   确保你所使用的存储支持 qcow2 格式，或根据实际存储调整 `qm importdisk` 参数。

------

## 常见问题

- **下载失败**
   请检查网络是否正常，镜像 URL 是否可访问。
- **VMID 冲突**
   确认 `VMID_START` 不与已有 VM 冲突，否则调整起始 ID。
- **网络连接失败**
   确保 `BRIDGE` 配置正确且网络通畅。
