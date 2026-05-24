# ZYpart - libexpat 漏洞挖掘与软件度量实验

本目录是软件度量期末大作业中个人负责的项目部分。被测对象选择 `libexpat`，目标是对 XML 解析库进行动态模糊测试和静态分析，并保留可复现实验过程、截图、结果和报告素材。

## 项目选择

- 被测项目：libexpat
- 项目地址：https://github.com/libexpat/libexpat
- 当前源码位置：`third_party/libexpat`
- 当前源码提交：见 `third_party/libexpat` 内 `git rev-parse --short HEAD`
- 选择原因：
  - XML 输入格式明确，适合构造 seed corpus 和字典；
  - C 语言解析库，适合 ASAN/UBSAN、libFuzzer、AFL++、Cppcheck、Clang Static Analyzer；
  - 项目自带 fuzz target，同时可以手写 driver 体现个人工作量；
  - 项目复杂度高于 cJSON，但构建难度低于 curl/libvpx 这类大型项目。

## 目录结构

```text
ZYpart/
  README.md                         # 项目结构、运行入口和交付说明
  docs/
    development.md                  # 开发文档：方案、driver 设计、复现方法
    fuzzing-plan.md                 # 动态测试计划与 12 小时运行记录模板
    static-analysis.md              # 静态分析计划与结果记录模板
    result-notes.md                 # crash、告警、截图和报告素材记录
  fuzz/
    expat_stream_fuzzer.c           # 手写 libFuzzer driver
    seeds/                          # 初始 XML 语料
    dict/xml.dict                   # XML fuzzing 字典
  scripts/
    build_fuzzers.sh                # 构建 AFL++ harness、ASAN 复现 harness
    run_afl.sh                      # 运行 AFL++ fuzzing
    run_libfuzzer.sh                # 运行手写 libFuzzer，适用于可用 libFuzzer runtime 的环境
    run_official_fuzzer.sh          # 运行 libexpat 官方 fuzzer
    run_static_analysis.sh          # 运行 Cppcheck 和 Clang Static Analyzer
  third_party/
    libexpat/                       # 被测项目源码
  build/                            # 本地构建目录，不作为报告正文
  results/
    fuzzing/                        # fuzzing 日志、corpus、运行记录
    static-analysis/                # 静态分析输出
    crashes/                        # crash 输入和复现材料
    screenshots/                    # 作业要求的截图
```

## 环境要求

建议在 macOS 或 Linux 上安装：

- `git`
- `cmake`
- `ninja` 或 `make`
- `clang` / `clang++`
- `llvm-profdata`、`llvm-cov`（覆盖率可选）
- `cppcheck`
- `scan-build`（Clang Static Analyzer，可选）

macOS 可用 Homebrew 安装：

```bash
brew install cmake ninja llvm cppcheck
```

Linux 可用包管理器安装：

```bash
sudo apt update
sudo apt install -y git cmake ninja-build clang llvm cppcheck clang-tools
```

## 快速开始

在 `Fuzztest` 根目录执行：

```bash
cd ZYpart
./scripts/build_fuzzers.sh
./scripts/run_afl.sh 60
./scripts/run_static_analysis.sh
```

其中 `run_afl.sh 60` 表示先试跑 60 秒。正式实验时建议运行 12 小时：

```bash
./scripts/run_afl.sh 43200
```

## 作业证据清单

最终报告需要保留以下材料：

- 手写 driver/fuzzer 截图：`fuzz/expat_stream_fuzzer.c`
- 12 小时 fuzzing 运行截图：`results/screenshots/`
- fuzzing 日志和 crash：`results/fuzzing/`、`results/crashes/`
- 静态分析工具运行截图：`results/screenshots/`
- 静态分析原始输出：`results/static-analysis/`
- 若发现 bug：ASAN 堆栈、最小化输入、复现命令、issue 链接

## 当前策略

本实验优先使用 AFL++ 跑 `expat_file_harness.c`，并保留手写 `expat_stream_fuzzer.c` 作为 libFuzzer 版本的 driver 证据。两个 driver 都使用 `XML_Parse` 和 namespace parser 覆盖 libexpat 的核心解析路径。
