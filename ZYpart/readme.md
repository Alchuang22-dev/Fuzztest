# ZYpart — libexpat 漏洞挖掘与软件度量实验

> 软件度量课程大作业 · 个人负责部分
>
> 对 [libexpat](https://github.com/libexpat/libexpat) XML 解析库进行 12 小时动态 fuzzing（AFL++ + libFuzzer）和静态分析（Cppcheck + Clang SA），验证手写 driver 的有效性并评估目标库的代码安全性。

---

## 核心结果速览

> 以下是 PPT 可直接引用的关键数据，完整表格见 [docs/report.md](docs/report.md)。

| 维度 | AFL++ | libFuzzer |
|---|---|---|
| 运行时长 | 12 小时 | 12 小时 |
| 总执行次数 | **6,100 万** | **9.79 亿** |
| 执行速度 | 1,411 exec/s | 22,671 exec/s |
| Corpus 条数 | **8,795** | 37 |
| Edge 覆盖率 | **50.56%** | 19 edges（仅 harness 层） |
| Crash | **0** | **0** |
| Hang | **0** | **0** |

| 静态分析工具 | 扫描文件数 | 高危告警 | 结论 |
|---|---|---|---|
| Cppcheck | 11 | 0 | 2 个中风险（signed shift / 格式字符串） |
| Clang SA (clang-17) | 7 | **0** | No bugs found |

**总执行次数：~10.4 亿次 | 发现 crash：0 | libexpat 版本：2.6.4-dev (`ff7cedb7`)**

---

## 文档索引

| 文档 | 内容 | PPT 用途 |
|---|---|---|
| [**docs/report.md**](docs/report.md) | **实验数据汇总**（所有表格、对比、结论） | **主要数据来源** |
| [docs/result-notes.md](docs/result-notes.md) | 运行记录、日志路径、素材清单 | 补充细节 |
| [docs/fuzzing-plan.md](docs/fuzzing-plan.md) | fuzzing 方案、12h 运行记录、调试过程 | 方法论说明 |
| [docs/static-analysis.md](docs/static-analysis.md) | 静态分析方案与结果 | 方法论说明 |
| [docs/development.md](docs/development.md) | Driver 设计思路、API 覆盖、构建方式 | 技术方案说明 |

---

## 项目结构

```
ZYpart/
├── readme.md                          ← 你在这里
├── docs/
│   ├── report.md                      ← 数据汇总（PPT 主要来源）
│   ├── result-notes.md                ← 运行记录与素材清单
│   ├── fuzzing-plan.md                ← fuzzing 方案与调试记录
│   ├── static-analysis.md             ← 静态分析方案与结果
│   └── development.md                 ← 技术方案与 driver 设计
├── fuzz/
│   ├── expat_file_harness.c           ← 手写 AFL++ harness（XML_Parse + NS）
│   ├── expat_stream_fuzzer.c          ← 手写 libFuzzer driver（Parse + Buffer + ExternalEntity）
│   ├── seeds/                         ← 73 个初始 XML 语料
│   └── dict/xml.dict                  ← XML fuzzing 字典
├── scripts/
│   ├── build_fuzzers.sh               ← 构建 AFL++ / libFuzzer / ASAN 二进制
│   ├── run_afl.sh                     ← 运行 AFL++ fuzzing
│   ├── run_libfuzzer.sh               ← 运行手写 libFuzzer
│   ├── run_official_fuzzer.sh         ← 运行 libexpat 官方 fuzzer
│   └── run_static_analysis.sh         ← 运行 Cppcheck + Clang SA
├── results/
│   ├── fuzzing/
│   │   ├── afl-expat/default/         ← AFL++ 输出（corpus/crashes/fuzzer_stats/plot_data）
│   │   ├── afl-expat-*.log            ← AFL++ 运行日志
│   │   ├── libfuzzer-expat-stream-*.log ← libFuzzer 运行日志
│   │   └── corpus-expat-stream/        ← libFuzzer corpus
│   ├── static-analysis/
│   │   ├── cppcheck.txt / .xml        ← Cppcheck 输出
│   │   └── scan-build.txt             ← Clang SA 输出
│   ├── crashes/                       ← crash 输入（本次为空）
│   └── screenshots/                   ← 截图（待补充）
├── third_party/
│   └── libexpat/                      ← 被测项目源码（ff7cedb7）
└── build/                             ← 本地构建目录（不纳入报告）
```

---

## 快速复现

```bash
cd ZYpart
./scripts/build_fuzzers.sh            # 构建 harness
./scripts/run_afl.sh 60                # 试跑 60 秒
./scripts/run_afl.sh 43200             # 正式 12 小时
./scripts/run_libfuzzer.sh 43200       # libFuzzer 对照
./scripts/run_static_analysis.sh       # 静态分析
```

**环境要求：** Linux（推荐）或 macOS · clang · cmake · AFL++ · cppcheck · clang-tools

---

## 作业素材清单

| 素材 | 路径 | 状态 |
|---|---|---|
| 手写 AFL++ harness 源码 | [`fuzz/expat_file_harness.c`](fuzz/expat_file_harness.c) | ✅ |
| 手写 libFuzzer driver 源码 | [`fuzz/expat_stream_fuzzer.c`](fuzz/expat_stream_fuzzer.c) | ✅ |
| AFL++ 12h 运行日志 | [`results/fuzzing/afl-expat-20260525-170848.log`](results/fuzzing/afl-expat-20260525-170848.log) | ✅ |
| AFL++ fuzzer_stats | [`results/fuzzing/afl-expat/default/fuzzer_stats`](results/fuzzing/afl-expat/default/fuzzer_stats) | ✅ |
| AFL++ coverage plot 数据 | [`results/fuzzing/afl-expat/default/plot_data`](results/fuzzing/afl-expat/default/plot_data) | ✅ |
| AFL++ corpus（8,795 条） | [`results/fuzzing/afl-expat/default/queue/`](results/fuzzing/afl-expat/default/queue/) | ✅ |
| libFuzzer 12h 运行日志 | [`results/fuzzing/libfuzzer-expat-stream-20260525-170921.log`](results/fuzzing/libfuzzer-expat-stream-20260525-170921.log) | ✅ |
| Cppcheck 输出 | [`results/static-analysis/cppcheck.txt`](results/static-analysis/cppcheck.txt) | ✅ |
| Clang SA 输出 | [`results/static-analysis/scan-build.txt`](results/static-analysis/scan-build.txt) | ✅ |
| AFL++ 运行界面截图 | `results/screenshots/` | ⏳ 待补充 |
| libFuzzer 运行界面截图 | `results/screenshots/` | ⏳ 待补充 |
| 静态分析运行界面截图 | `results/screenshots/` | ⏳ 待补充 |
