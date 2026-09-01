# GDEX 数据批量下载（Globus Transfer）

使用 [Globus Transfer Service](https://www.globus.org/data-transfer)（GridFTP）从 NSF NCAR Geoscience Data Exchange（GDEX）批量下载再分析数据，用于 WRF/WPS 前处理（观测资料、CDAS 与 FNL 再分析场等）。

> English version: [README.md](README.md)

## 目录

- [GDEX 数据批量下载（Globus Transfer）](#gdex-数据批量下载globus-transfer)
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

示例：

```
outputHome=/work/share/ac4sj3muo0/data/wrfinput
destinationID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
globusPath=/work/home/tsinghuazhangh/zhangh/software/install/apps/anaconda3/2023.07-2/bin/globus
globusConnectPersonalPath=/work/home/tsinghuazhangh/zhangh/software/install/apps/gcp/globusconnectpersonal-3.3.0/globusconnectpersonal
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

1. 解析并校验日期范围（单次最多 `MAX_DAY` 天，默认 36，可在脚本中调整）；
2. 按时间步长生成 `filelist.txt` 批处理清单；
3. 启动 `globusconnectpersonal` 并等待连接就绪；
4. 提交批量传输任务并等待完成；
5. 停止 `globusconnectpersonal` 并输出结果。

### 注意事项

- 数据源 `SRC_ID` 为 NSF NCAR GDEX Dataset Archive 的 ID，固定不变；
- 目标端目录必须先写入 `~/.globusonline/lta/config-paths`；
- 每次运行最多下载 `MAX_DAY` 天，防止误操作导致超大下载；
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

Copyright (c) 2026 ZHANG Hua, All Rights Reserved.