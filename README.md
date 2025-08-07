## 📝 云镜像自动模板生成脚本（适用于 Proxmox VE）

此脚本自动化在 Proxmox VE 上下载常见 Linux 云镜像，并将其配置为可用于克隆的 **VM 模板**。支持的系统包括：

- Ubuntu 24.04
- Debian 12
- CentOS Stream 9
- Rocky Linux 9
- AlmaLinux 9
- Fedora 42

------

### ✅ 功能特点

- 自动下载云镜像并导入为磁盘
- 创建 Proxmox VM 并连接 Cloud-Init
- 配置 SSH 公钥、默认用户、密码等信息
- 自动扩容磁盘
- 一键转换为模板（可供后续快速克隆）

------

### 📦 依赖要求

确保在执行前满足以下条件：

1. **已安装 Proxmox VE 环境**
2. **Proxmox CLI 工具可用**（如 `qm`, `wget` 等）
3. **~/.ssh/id_rsa.pub** 存在（用于注入 SSH 公钥）

若未生成 SSH 密钥对，可使用以下命令创建：

```bash
ssh-keygen -t rsa -b 4096
```

------

### 🔧 可配置参数

在脚本开头可以修改以下默认值：

```bash
STORAGE="local"        # 存储池名称
VMID_START=9000        # 初始 VM ID（每个模板递增）
DISK_SIZE="30G"        # 云镜像扩容后的磁盘大小
BRIDGE="vmbr0"         # 网络桥接接口
CPU_CORES=2            # 默认 CPU 核心数
MEMORY_SIZE=2048       # 默认内存大小（单位：MB）
```

------

### ▶️ 使用方法

1. 将脚本保存为 `create-cloud-templates.sh`
2. 给脚本执行权限：

```
chmod +x create-cloud-templates.sh
```

1. 运行脚本：

```
./create-cloud-templates.sh
```

------

### 📁 执行后内容说明

- 云镜像将下载到本地 `cloud-images/` 目录（如已存在则跳过下载）
- 每个镜像会创建一个 VM（ID 从 `VMID_START` 开始）
- 设置完成后，自动转为 **VM 模板**
- 模板可在 Proxmox UI 中用于创建新 VM

------

### 🔐 默认账户信息（可在脚本中修改）

- Cloud-Init 用户名：每个镜像配置指定（如 `ubuntu`, `debian`, `centos` 等）
- 默认密码：`changeme`
- SSH 公钥：使用当前用户 `~/.ssh/id_rsa.pub`

------

### 🧹 清理建议（可选）

执行完后你可以清理 `cloud-images/` 目录，或保留以便后续使用。