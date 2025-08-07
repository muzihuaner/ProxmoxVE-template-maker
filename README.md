# ProxmoxVE云镜像模板生成脚本

### 功能说明

1. **自动下载官方云镜像**：
   - 支持Ubuntu/Debian/CentOS/Rocky Linux/AlmaLinux/Fedora
   - 自动缓存已下载镜像到`/tmp`
2. **自动配置Cloud-Init**：
   - 设置默认用户（各发行版不同）
   - 启用NoCloud数据源
   - 可选SSH密钥注入
   - DHCP网络配置
3. **虚拟机模板转换**：
   - 自动分配唯一VMID（9000-9005）
   - 创建后自动转换为模板
   - 添加模板描述信息
4. **QEMU Guest Agent支持**：
   - 自动安装并启用服务
   - 在Proxmox中启用代理
5. **磁盘扩展**：
   - 默认扩展+10G空间
   - 使用`qm resize`动态调整
6. **批量处理**：
   - 自动处理所有预定义镜像
   - 跳过已存在的模板

### 使用说明

1. **保存脚本**为`create-cloud-template.sh`

2. **修改配置参数**：

   - `STORAGE`：你的Proxmox存储名称
   - `BRIDGE`：网络桥接接口
   - `SSH_KEY`：如果需要注入SSH公钥

3. **运行脚本**：

   bash

   ```
   chmod +x create-cloud-template.sh
   ./create-cloud-template.sh
   ```

### 注意事项

1. 需要**root权限**运行

2. 首次运行会下载镜像（约2-5GB，取决于网络）

3. 需要安装`libguestfs-tools`：

   bash

   ```
   apt install libguestfs-tools
   ```

4. 生成的模板可在Proxmox GUI的**虚拟机模板**中找到

### 自定义扩展

- **添加新镜像**：在`CLOUD_IMAGES`数组中添加新条目

  bash

  ```
  ["镜像名称"]="下载URL 默认用户名"
  ```

- **调整资源**：修改`MEMORY`/`CORES`/`DISK_SIZE`变量

- **自定义Cloud-Init**：修改`configure_cloudinit()`函数