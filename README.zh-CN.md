# GDEX 数据批量下载（Globus Transfer）

使用 [Globus Transfer Service](https://www.globus.org/data-transfer)（GridFTP）从 NSF NCAR Geoscience Data Exchange（GDEX）批量下载再分析数据，用于 WRF/WPS 前处理（观测资料、CDAS 与 FNL 再分析场等）。

> English version: [README.md](README.md)

## 为什么用 Globus 而不是 HTTP 下载？

**批量下载数据时请用 Globus，不要用 HTTP。** 以本仓库涉及的数据集为例，实测 Globus 传输**平均可达约 15 MB/s**；更重要的是，它能长时间稳定维持这个速度并自动跑完，而用 HTTPS 下载同样的数据通常更慢、速度波动更大，批量下载时更容易中途卡死。

| | Globus Transfer | HTTPS / HTTP 下载 |
| --- | --- | --- |
| 传输速度 | 基于 GridFTP 式传输，使用**多条并行数据流**，并由 Globus **自动调优**并发度、并行度、TCP 缓冲区等性能参数；本机实测平均约 15 MB/s | 每个文件一条 TCP 连接，遇到高延迟与丢包时吞吐急剧下降，且无可调优手段 |
| 稳定性 | 传输过程受监控、正确性有校验，网络或系统中断后**自动断点续传** | 连接中断或单个请求失败即导致该文件失败，只能手工重跑客户端 |
| 批量下载 | 整个时间范围作为**一个任务**提交，成百上千个文件在服务端排队、分阶段传输 | 一个文件一个请求，靠 shell 循环驱动；一次卡住就可能拖垮整批，断线后无法恢复 |
| 进度查看 | `globus task show` / `globus task wait`、[活动页面](https://app.globus.org/activity)，完成后邮件通知 | 只能看客户端输出，没有全局视图，也没有续传 |

Globus 官方将其描述为"快速、安全、可靠地传输 MB、TB 乃至 PB 级数据"的服务：传输过程中由 Globus "调优性能参数、保障安全、监控进度并校验正确性"，并且"若传输涉及的某个网络或系统宕机，Globus 会在其恢复后自动继续传输"（[Why Globus / Data Transfer](https://www.globus.org/data-transfer)）。文件数据在两个端点之间直连传输，不经过 Globus 中转（[Globus FAQ](https://docs.globus.org/faq/globus-connect-endpoints/)）。

GDEX 对同一批数据同时提供 HTTPS 与 Globus 两种方式，本仓库刻意选择 Globus——文件数量越多、总体积越大，两者的差距越明显。

> 实测速度取决于网络链路、端点与文件大小。约 15 MB/s 为本仓库 `download.sh` 实际运行的平均值，仅作数量级参考。

## 目录

- [GDEX 数据批量下载（Globus Transfer）](#gdex-数据批量下载globus-transfer)
  - [为什么用 Globus 而不是 HTTP 下载？](#为什么用-globus-而不是-http-下载)
  - [目录](#目录)
  - [1. 依赖](#1-依赖)
  - [2. 安装依赖](#2-安装依赖)
    - [2.1 安装 Globus Connect Personal](#21-安装-globus-connect-personal)
    - [2.2 配置目录访问权限](#22-配置目录访问权限)
    - [2.3 安装 Globus CLI](#23-安装-globus-cli)
    - [2.4 测试传输](#24-测试传输)
  - [3. 配置 config 文件](#3-配置-config-文件)
  - [4. 使用 download.sh](#4-使用-downloadsh)
    - [用法](#用法)
    - [支持的数据集](#支持的数据集)
    - [运行流程](#运行流程)
    - [注意事项](#注意事项)
  - [5. 诊断命令](#5-诊断命令)
  - [6. 许可](#6-许可)

## 1. 依赖

| 依赖 | 作用 |
| --- | --- |
| `globusconnectpersonal` | 将本机作为 Personal Endpoint 接入 Globus Transfer Service，即传输的目的端 |
| `globus`（globus-cli） | 执行 Globus Transfer Service 的各种操作：提交传输任务、等待/查询任务状态等 |

## 2. 安装依赖

### 2.1 安装 Globus Connect Personal

官方文档：<https://docs.globus.org/globus-connect-personal/install/linux/>

```bash
wget https://downloads.globus.org/globus-connect-personal/linux/stable/globusconnectpersonal-latest.tgz
tar xzf globusconnectpersonal-latest.tgz
cd globusconnectpersonal-x.y.z    # 将 x.y.z 替换为实际版本号
./globusconnectpersonal -setup
```

1. 复制终端输出的链接并在浏览器中打开，按照提示完成设置；
2. `label` 和 `Endpoint Name` 推荐按 `user_name@host` 格式命名；
3. 保存生成的 ID（即 **Globus Collection Personal ID**，即下文 `DST_ID`）。该 ID 是独一无二的。

### 2.2 配置目录访问权限

创建 `~/.globusonline/lta/config-paths` 文件，规定 Globus Connect Personal 可访问的目录及权限。该文件是无表头的 CSV，每行格式如下：

```
<path>,<sharing flag>,<R/W flag>
<path>,<sharing flag>,<R/W flag>
...
```

| 字段 | 说明 |
| --- | --- |
| `<path>` | 允许访问的绝对路径；只有出现在该文件中的路径才可被访问。可用 `~` 表示运行 Globus Connect Personal 的用户主目录 |
| `<sharing flag>` | 是否允许共享，取值 `1`（允许）或 `0`（禁止）。注意：Sharing 为付费功能，Endpoint 需有订阅 |
| `<R/W flag>` | 是否允许写入，取值 `1`（读/写）或 `0`（只读）。该权限与文件系统权限等其他限制叠加生效 |

一般 `<sharing flag>` 设为 `0`，`<R/W flag>` 设为 `1`。示例：

```
/work/share/ac4sj3muo0/data/wrfinput/,0,1
```

### 2.3 安装 Globus CLI

官方教程：<https://docs.globus.org/cli/quickstart/>

```bash
python -m pip install globus-cli
globus login
```

若之前忘记保存 Globus Collection Personal ID，可运行 `globus endpoint local-id` 查看。

### 2.4 测试传输

变量说明：

| 变量 | 含义 |
| --- | --- |
| `SRC_ID` | NSF NCAR GDEX Dataset Archive 的 ID（固定不变） |
| `DST_ID` | Globus Collection Personal ID |
| `<globus_path>` | globus 可执行文件的路径 |
| `<globusconnectpersonal_path>` | globusconnectpersonal 可执行文件的路径 |
| `<OUTPUT_HOME>` | `~/.globusonline/lta/config-paths` 文件中设置的路径 |
| `<TASK_ID>` | `globus transfer` 命令输出最后一行中的任务 ID |

```bash
export SRC_ID=c4e40965-a024-43d7-bef4-6010f3731b61
export DST_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
alias globus=<globus_path>
alias globusconnectpersonal=<globusconnectpersonal_path>

globusconnectpersonal -start &
globus transfer $SRC_ID:/d461000/little_r/2026/SURFACE_OBS:2026080100 $DST_ID:<OUTPUT_HOME>/ds461.0/2026/08/SURFACE_OBS:2026080100 --notify off
globus task wait <TASK_ID>
globusconnectpersonal -stop
```

> 下载完成后务必执行 `globusconnectpersonal -stop` 断开连接！

## 3. 配置 config 文件

脚本从同目录下的 `config` 文件读取配置（即脚本中的 `CONFIG_FILE` 变量）：

| 配置项 | 含义 |
| --- | --- |
| `outputHome` | 输出根目录，即 `~/.globusonline/lta/config-paths` 中设置的路径 |
| `destinationID` | Globus Collection Personal ID |
| `globusPath` | globus 可执行文件的路径 |
| `globusConnectPersonalPath` | globusconnectpersonal 可执行文件的路径 |
| `maximumDownloadDay` | 单次运行最多下载的天数（默认 36） |

示例：

```
outputHome=/work/share/ac4sj3muo0/data/wrfinput
destinationID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
globusPath=/work/home/tsinghuazhangh/zhangh/software/install/apps/anaconda3/2023.07-2/bin/globus
globusConnectPersonalPath=/work/home/tsinghuazhangh/zhangh/software/install/apps/gcp/globusconnectpersonal-3.3.0/globusconnectpersonal
maximumDownloadDay=36
```

## 4. 使用 download.sh

### 用法

```bash
./download.sh <dataset_type> <start_year> <start_month> <start_day> <end_year> <end_month> <end_day>
```

示例：

```bash
# 下载 ds461.0 从 2026-08-01 00 时至 2026-09-01 00 时的数据（6 小时间隔）
./download.sh ds461.0 2026 08 01 2026 09 01
```

### 支持的数据集

| dataset_type | 时间分辨率 | 源路径模板（`SRC_ID` 内） | 输出路径模板（`${OUTPUT_HOME}` 内） |
| --- | --- | --- | --- |
| `ds461.0` | 6 小时 | `/d461000/little_r/YYYY/SURFACE_OBS:YYYYMMDDHH` | `${OUTPUT_HOME}/ds461.0/YYYY/MM/SURFACE_OBS:YYYYMMDDHH` |
| `ds094.0` | 24 小时 | `/d094000/YYYY/cdas1.YYYYMMDD.pgrbh.tar` | `${OUTPUT_HOME}/ds094.0/YYYY/MM/cdas1.YYYYMMDD.pgrbh.tar` |
| `ds083.2` | 6 小时 | `/d083002/grib2/YYYY/YYYY.MM/fnl_YYYYMMDD_HH_00.grib2` | `${OUTPUT_HOME}/ds083.2/YYYY/MM/fnl_YYYYMMDD_HH_00.grib2` |

其中 `YYYY` 为年、`MM` 为月、`DD` 为日、`HH` 为时。

### 运行流程

1. 解析并校验日期范围（单次最多 `maximumDownloadDay` 天，在 config 文件中设置）；
2. 按时间步长生成 `filelist.txt` 批处理清单；
3. 启动 `globusconnectpersonal` 并等待连接就绪；
4. 提交批量传输任务并等待完成；
5. 停止 `globusconnectpersonal` 并输出结果。

### 注意事项

- 数据源 `SRC_ID` 为 NSF NCAR GDEX Dataset Archive 的 ID，固定不变；
- 只要需要下载的文件不止几个，就优先用 Globus 而不是 HTTPS，原因见[为什么用 Globus 而不是 HTTP 下载？](#为什么用-globus-而不是-http-下载)；
- 目标端目录必须先写入 `~/.globusonline/lta/config-paths`；
- 每次运行最多下载 `maximumDownloadDay` 天（在 config 文件中设置），防止误操作导致超大下载；
- 脚本依赖 bash 与 GNU coreutils 的 `date`（支持 `-d`/`-u` 选项）。

## 5. 诊断命令

```bash
# 查看后台运行的 Globus Connect Personal 状态
globusconnectpersonal -status

# 查看传输任务状态
globus task show <TASK_ID>
```

也可以登录 <https://app.globus.org/activity> 查看任务活动。

## 6. 许可

本项目基于 [MIT 许可证](LICENSE) 开源：可自由使用、修改和再分发（含商业用途），只需保留版权声明与许可证原文。

Copyright (c) 2026 ZHANG Hua