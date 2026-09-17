# GDEX Data Download via Globus Transfer

Batch download reanalysis data from the NSF NCAR Geoscience Data Exchange (GDEX) using [Globus Transfer Service](https://www.globus.org/data-transfer) (GridFTP), for WRF/WPS preprocessing (observations, CDAS and FNL reanalysis fields, etc.).

> 中文版: [README.zh-CN.md](README.zh-CN.md)

## Why Globus Transfer Instead of HTTP?

**Use Globus, not HTTP, when you have data to download in bulk.** For the datasets handled by this repo, Globus transfers average roughly **15 MB/s** on our setup (measured), and — more importantly — they hold that speed over long runs and finish unattended. Downloading the same data over HTTPS is typically slower, much more variable, and far more likely to stall partway through a large batch.

| | Globus Transfer | HTTPS / HTTP download |
| --- | --- | --- |
| Throughput | GridFTP-style transfer over **multiple parallel data streams**, with performance parameters (concurrency, parallelism, TCP buffer sizes) **tuned automatically by Globus**; ~15 MB/s measured average here | One TCP connection per file; throughput collapses with latency and packet loss, and there is nothing to tune |
| Reliability | Progress is monitored, correctness is validated, and a transfer **automatically resumes after a network or system outage** | A dropped connection or one failed request aborts that file; recovering means re-running the client by hand |
| Large batches | An entire date range is submitted as **one task** of thousands of files, queued and staged server-side | One request per file, driven by a shell loop; a single hang can stall the whole batch, and nothing survives a disconnect |
| Progress | `globus task show` / `globus task wait`, the [activity page](https://app.globus.org/activity), and email notification on completion | Whatever the client prints; no global view, no resumption |

As Globus puts it, it is "a fast, secure, and reliable way to move MB's, TB's and even PB's of data": the service "tunes performance parameters, maintains security, monitors progress, and validates correctness" during a transfer, and "if a network or system involved in the transfer goes down, Globus automatically resumes the transfer when the component comes back online" ([Why Globus / Data Transfer](https://www.globus.org/data-transfer)). File data moves directly between the two endpoints — it never flows through Globus itself ([Globus FAQ](https://docs.globus.org/faq/globus-connect-endpoints/)).

GDEX serves the same datasets over both HTTPS and Globus; this repository deliberately uses Globus, because the gap widens sharply as the number and total size of files grow.

> Measured throughput depends on your network path, endpoint and file sizes. The ~15 MB/s figure is an average from our own runs of `download.sh`, and is reported here only as an order-of-magnitude reference.

## Table of Contents

- [Why Globus Transfer Instead of HTTP?](#why-globus-transfer-instead-of-http)
- [1. Dependencies](#1-dependencies)
- [2. Installing Dependencies](#2-installing-dependencies)
  - [2.1 Install Globus Connect Personal](#21-install-globus-connect-personal)
  - [2.2 Configure Directory Permissions](#22-configure-directory-permissions)
  - [2.3 Install the Globus CLI](#23-install-the-globus-cli)
  - [2.4 Test a Transfer](#24-test-a-transfer)
- [3. Configuring the config File](#3-configuring-the-config-file)
- [4. Using download.sh](#4-using-downloadsh)
  - [Supported Datasets](#supported-datasets)
  - [Workflow](#workflow)
  - [Notes](#notes)
- [5. Diagnostics](#5-diagnostics)
- [6. License](#6-license)

## 1. Dependencies

| Dependency | Purpose |
| --- | --- |
| `globusconnectpersonal` | Connects this machine to the Globus Transfer Service as a Personal Endpoint (the transfer destination) |
| `globus` (globus-cli) | Performs Globus Transfer Service operations: submitting transfer tasks, waiting for / querying task status, etc. |

## 2. Installing Dependencies

### 2.1 Install Globus Connect Personal

Official documentation: <https://docs.globus.org/globus-connect-personal/install/linux/>

```bash
wget https://downloads.globus.org/globus-connect-personal/linux/stable/globusconnectpersonal-latest.tgz
tar xzf globusconnectpersonal-latest.tgz
cd globusconnectpersonal-x.y.z    # replace x.y.z with the version number you see
./globusconnectpersonal -setup
```

1. Copy the URL printed in the terminal and open it in a browser, then follow the instructions;
2. It is recommended to name the `label` and `Endpoint Name` as `user_name@host`;
3. Save the generated ID (i.e. the **Globus Collection Personal ID**, referred to as `DST_ID` below). This ID is unique.

### 2.2 Configure Directory Permissions

Create `~/.globusonline/lta/config-paths` to define which directories Globus Connect Personal may access and with what permissions. This file is a headerless CSV where each line has the following format:

```
<path>,<sharing flag>,<R/W flag>
<path>,<sharing flag>,<R/W flag>
...
```

| Field | Description |
| --- | --- |
| `<path>` | An absolute path to be permitted. Only paths present in this file can be accessed. `~` can be used to represent the home directory of the user running Globus Connect Personal |
| `<sharing flag>` | Enable or disable sharing: `1` allows sharing, `0` disallows it. Note: Sharing is a premium feature and requires a subscription |
| `<R/W flag>` | Enable or disable write access: `1` allows read/write, `0` allows read-only. These permissions apply in addition to any other permissions and restrictions (e.g. file system permissions) |

In general, set `<sharing flag>` to `0` and `<R/W flag>` to `1`. Example:

```
/work/share/ac4sj3muo0/data/wrfinput/,0,1
```

### 2.3 Install the Globus CLI

Official tutorial: <https://docs.globus.org/cli/quickstart/>

```bash
python -m pip install globus-cli
globus login
```

If you forgot to save the Globus Collection Personal ID earlier, run `globus endpoint local-id` to look it up.

### 2.4 Test a Transfer

Variable reference:

| Variable | Meaning |
| --- | --- |
| `SRC_ID` | ID of the NSF NCAR GDEX Dataset Archive (fixed) |
| `DST_ID` | Globus Collection Personal ID |
| `<globus_path>` | Path to the globus executable |
| `<globusconnectpersonal_path>` | Path to the globusconnectpersonal executable |
| `<OUTPUT_HOME>` | A path configured in `~/.globusonline/lta/config-paths` |
| `<TASK_ID>` | Task ID found in the last line of the `globus transfer` output |

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

> Be sure to run `globusconnectpersonal -stop` to disconnect after the download completes!

## 3. Configuring the config File

The script reads its settings from the `config` file in the same directory (the `CONFIG_FILE` variable):

| Key | Meaning |
| --- | --- |
| `outputHome` | Output root directory, i.e. a path configured in `~/.globusonline/lta/config-paths` |
| `destinationID` | Globus Collection Personal ID |
| `globusPath` | Path to the globus executable |
| `globusConnectPersonalPath` | Path to the globusconnectpersonal executable |
| `maximumDownloadDay` | Maximum days per download run (default 36) |

Example:

```
outputHome=/work/share/ac4sj3muo0/data/wrfinput
destinationID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
globusPath=/work/home/tsinghuazhangh/zhangh/software/install/apps/anaconda3/2023.07-2/bin/globus
globusConnectPersonalPath=/work/home/tsinghuazhangh/zhangh/software/install/apps/gcp/globusconnectpersonal-3.3.0/globusconnectpersonal
maximumDownloadDay=36
```

## 4. Using download.sh

### Usage

```bash
./download.sh <dataset_type> <start_year> <start_month> <start_day> <end_year> <end_month> <end_day>
```

Example:

```bash
# Download ds461.0 data from 2026-08-01 00:00 to 2026-09-01 00:00 (6-hourly)
./download.sh ds461.0 2026 08 01 2026 09 01
```

### Supported Datasets

| dataset_type | Time Resolution | Source Path Template (on `SRC_ID`) | Destination Path Template (under `${OUTPUT_HOME}`) |
| --- | --- | --- | --- |
| `ds461.0` | 6 h | `/d461000/little_r/YYYY/SURFACE_OBS:YYYYMMDDHH` | `${OUTPUT_HOME}/ds461.0/YYYY/MM/SURFACE_OBS:YYYYMMDDHH` |
| `ds094.0` | 24 h | `/d094000/YYYY/cdas1.YYYYMMDD.pgrbh.tar` | `${OUTPUT_HOME}/ds094.0/YYYY/MM/cdas1.YYYYMMDD.pgrbh.tar` |
| `ds083.2` | 6 h | `/d083002/grib2/YYYY/YYYY.MM/fnl_YYYYMMDD_HH_00.grib2` | `${OUTPUT_HOME}/ds083.2/YYYY/MM/fnl_YYYYMMDD_HH_00.grib2` |

Where `YYYY` is the year, `MM` the month, `DD` the day, and `HH` the hour.

### Workflow

1. Parse and validate the date range (at most `maximumDownloadDay` days per run, set in the config file);
2. Generate the `filelist.txt` batch list at the given time step;
3. Start `globusconnectpersonal` and wait for the connection to come online;
4. Submit the batch transfer and wait for it to finish;
5. Stop `globusconnectpersonal` and report the result.

### Notes

- The source `SRC_ID` is the fixed ID of the NSF NCAR GDEX Dataset Archive;
- Prefer Globus over HTTPS whenever you are pulling more than a handful of files — see [Why Globus Transfer Instead of HTTP?](#why-globus-transfer-instead-of-http);
- Destination directories must be listed in `~/.globusonline/lta/config-paths` first;
- Each run downloads at most `maximumDownloadDay` days of data (set in the config file) to prevent accidental huge downloads;
- The script requires bash and GNU coreutils `date` (with `-d`/`-u` support).

## 5. Diagnostics

```bash
# Check the status of the background Globus Connect Personal
globusconnectpersonal -status

# Show the status of a transfer task
globus task show <TASK_ID>
```

You can also monitor task activity at <https://app.globus.org/activity>.

## 6. License

Released under the [MIT License](LICENSE): free to use, modify and redistribute, including commercially, as long as the copyright notice and license text are kept.

Copyright (c) 2026 ZHANG Hua