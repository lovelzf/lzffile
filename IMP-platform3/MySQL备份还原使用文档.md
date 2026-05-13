# MySQL 数据库备份还原操作文档

## 文件说明

| 文件名 | 说明 |
|--------|------|
| backup.ps1 | 数据库备份脚本 |
| restore.ps1 | 数据库还原脚本 |
| backup.conf | 配置文件 |

## 配置说明

编辑 `backup.conf` 文件可修改以下配置：

```ini
# MySQL 安装根目录
mysqlBasedir=D:\IMP-platform\mysql

# 数据库连接配置
dbHost=10.128.128.16
dbPort=3306
dbName=imp_platform
dbUser=root
dbPassword=Leewell123!@#

# 备份文件存储位置
backupLocation=D:\PsaDeploy\backups

# 是否启用压缩 (true/false)
enableCompression=true

# 保留备份天数 (0 表示不删除旧备份)
keepDays=30
```

## 使用方法

### 1. 备份数据库

打开 PowerShell 执行以下命令：

```powershell
cd D:\PsaDeploy
.\backup.ps1
```

**执行过程：**
1. 自动读取配置文件
2. 创建备份目录（如果不存在）
3. 使用 mysqldump 备份数据库
4. 如果启用压缩且系统有 gzip，则自动压缩
5. 自动删除超过保留天数的旧备份
6. 显示备份文件大小

**输出示例：**
```
开始备份数据库: imp_platform
备份文件: D:\PsaDeploy\backups\imp_platform_backup_20260402_143025.sql
备份完成并压缩: D:\PsaDeploy\backups\imp_platform_backup_20260402_143025.sql.gz
备份大小: 125.45 MB
```

### 2. 还原数据库

打开 PowerShell 执行以下命令：

```powershell
cd D:\PsaDeploy
.\restore.ps1 -backupFile "备份文件完整路径"
```

**示例：**
```powershell
# 还原未压缩备份
.\restore.ps1 -backupFile "D:\PsaDeploy\backups\imp_platform_backup_20260402_143025.sql"

# 还原压缩备份
.\restore.ps1 -backupFile "D:\PsaDeploy\backups\imp_platform_backup_20260402_143025.sql.gz"
```

**注意事项：**
- 还原前会提示确认，输入 `y` 确认后才会执行
- **还原操作会覆盖目标数据库中的所有数据，请谨慎操作！**
- 支持 `.sql` 和 `.sql.gz` 两种格式

**输出示例：**
```
警告: 此操作将覆盖数据库 'imp_platform' 中的所有数据!
是否继续? (y/N): y
开始还原数据库: imp_platform
备份文件: D:\PsaDeploy\backups\imp_platform_backup_20260402_143025.sql.gz
解压缩备份文件...
还原完成!
```

## 设置定时自动备份

### 使用 Windows 任务计划程序

1. **打开任务计划程序**
   - Win+R 输入 `taskschd.msc` 回车

2. **创建基本任务**
   - 名称：`MySQL自动备份`
   - 点击「下一步」

3. **设置触发器**
   - 选择「每天」（或每周、每月）
   - 设置开始时间
   - 点击「下一步」

4. **设置操作**
   - 选择「启动程序」
   - 点击「下一步」

5. **配置启动程序**
   - 程序或脚本：`powershell.exe`
   - 添加参数：`-ExecutionPolicy Bypass -File "D:\PsaDeploy\backup.ps1"`
   - 点击「下一步」

6. **完成**
   - 勾选「当单击"完成"时，打开此任务属性的对话框」
   - 点击「完成」
   - 在属性中可勾选「不管用户是否登录都要运行」
   - 确定保存

### 常用定时配置建议

- **每日备份**：每天凌晨 2:00 执行
- **每周备份**：每周日凌晨 2:00 执行
- **保留 30 天**：配置 `keepDays=30`，自动删除 30 天前的备份

## 设置定时备份批处理（可选）

如果需要，可以创建一个批处理文件方便调用：

```batch
@echo off
echo 开始MySQL备份...
powershell -ExecutionPolicy Bypass -File "D:\PsaDeploy\backup.ps1"
echo 备份完成
pause
```

保存为 `backup.bat` 放到 `D:\PsaDeploy` 目录，双击即可执行备份。

## 故障排查

### 问题1：提示 "mysqldump.exe 不存在"
**解决：** 检查 `backup.conf` 中的 `mysqlBasedir` 配置是否正确，确认 `D:\IMP-platform\mysql\bin\mysqldump.exe` 文件存在。

### 问题2：提示 "Access denied" 访问拒绝
**解决：** 检查配置文件中的数据库地址、用户名、密码是否正确。

### 问题3：压缩失败，提示 "未找到gzip"
**解决：** 这不影响备份，只是不压缩而已。如果需要压缩功能，请安装 gzip 并添加到 PATH 环境变量。

### 问题4：PowerShell 执行策略限制
**解决：** 如果执行脚本时提示权限错误，使用以下方式执行：
```powershell
powershell -ExecutionPolicy Bypass -File "D:\PsaDeploy\backup.ps1"
```

### 问题5：备份文件中中文注释乱码
**解决：** 此问题已在 v2 版本脚本中修复。修复方案：
- 使用 `mysqldump --result-file` 直接输出到文件，避免 PowerShell 编码转换
- 如果使用旧版脚本出现乱码，请更新到最新脚本后重新备份

### 问题6：还原时出现语法错误
**解决：** 通常是由于备份文件编码问题导致。请使用修复后的脚本重新备份再还原：
```powershell
# 使用修复后的脚本重新备份
.\backup.ps1
# 再使用新备份文件还原
.\restore.ps1 -backupFile "新备份文件路径"

## 备份文件命名规则

备份文件命名格式：
```
imp_platform_backup_YYYYMMDD_HHMMSS.sql[.gz]
```

示例：
- `imp_platform_backup_20260402_143025.sql`
- `imp_platform_backup_20260402_143025.sql.gz`

## 注意事项

1. **权限**：运行脚本的用户需要有 MySQL 访问权限和备份目录的写入权限
2. **空间**：确保备份目录所在磁盘有足够空间存储备份
3. **测试**：首次使用前，请先手动执行一次备份，验证脚本正常工作
4. **还原测试**：定期测试还原，确保备份文件可用
5. **密码安全**：backup.conf 包含数据库密码，请确保文件权限正确，不要泄露给他人
