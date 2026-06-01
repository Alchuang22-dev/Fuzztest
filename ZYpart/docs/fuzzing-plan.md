# 动态测试计划

> 数据汇总表格见 [report.md §2](report.md#2-动态-fuzzing-结果)，运行细节见 [result-notes.md](result-notes.md)。

## 工具选择

- 主工具：AFL++
- 辅助检测：AddressSanitizer、UndefinedBehaviorSanitizer
- 对照目标：libFuzzer driver
- 个人目标：`fuzz/expat_file_harness.c`、`fuzz/expat_stream_fuzzer.c`

## 初始语料

初始 XML seed 存放在：

```text
fuzz/seeds/
```

语料覆盖：

- 空文档和最小 XML
- 属性
- namespace
- comment
- CDATA
- processing instruction
- DTD 和 entity
- 畸形 XML

字典：

```text
fuzz/dict/xml.dict
```

## 试跑命令

```bash
./scripts/build_fuzzers.sh
./scripts/run_afl.sh 60
```

## 12 小时运行命令

```bash
./scripts/run_afl.sh 43200
```

macOS 运行说明：

- 脚本默认设置 `AFL_MAP_SIZE=1000000`，避免 macOS 默认 SysV shared memory 限制导致 `shmget()` 失败。
- 脚本默认设置 `AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1`，避免 macOS crash reporter 检查中止短跑实验。
- 在 Codex 沙箱内 AFL++ 可能因 `shmat()` 权限失败，正式运行需要在正常终端或已授权环境中执行。

---

## 实验记录

### AFL++ 12 小时运行（正式实验）

| 项目 | 值 |
|---|---|
| 日期 | 2026-05-25 ~ 2026-05-26 |
| 机器环境 | Linux 5.15.0-25-generic (aarch64)，192 CPU cores |
| libexpat commit | `ff7cedb7` (2.6.4 开发版) |
| fuzzer | AFL++ v4.41a + `fuzz/expat_file_harness.c` |
| sanitizer | ASAN（通过 `AFL_USE_ASAN=1` 启用） |
| 运行时长 | 43200 秒（12 小时） |
| total execs | **60,959,040** |
| execs/sec | ~1,411 |
| corpus 数量 | **8,795**（其中 73 初始 seed，8,722 fuzzer 发现） |
| coverage (bitmap) | **50.56%**（edges: 4,048 / 8,006） |
| cycles done | 26 |
| crash 数量 | **0** |
| hang 数量 | **0** |
| timeout 数量 | 441 |
| stability | 100.00% |
| 日志路径 | `results/fuzzing/afl-expat-20260525-170848.log` |
| fuzzer_stats | `results/fuzzing/afl-expat/default/fuzzer_stats` |

**结论：** AFL++ 在 12 小时内执行了约 6100 万次，发现了 8,722 个新 corpus 条目，覆盖率达到 50.56%。未发现任何 crash 或 hang。libexpat 经过长期 OSS-Fuzz 测试，代码成熟度高，当前版本未暴露出可触发的内存安全缺陷。

---

### libFuzzer 12 小时运行（对照实验）

| 项目 | 值 |
|---|---|
| 日期 | 2026-05-25 ~ 2026-05-26 |
| 机器环境 | 同上（Linux aarch64） |
| fuzzer | libFuzzer + `fuzz/expat_stream_fuzzer.c` |
| sanitizer | ASAN + UBSAN |
| 运行时长 | 43201 秒（12 小时） |
| total execs | **979,431,350** |
| execs/sec | ~22,671 |
| corpus 数量 | **37**（初始 73 seed，优化后保留 37） |
| coverage (edges) | **19** edges, 111 features |
| crash 数量 | **0** |
| peak RSS | 412 MB |
| 日志路径 | `results/fuzzing/libfuzzer-expat-stream-20260525-170921.log` |

**说明：** libFuzzer 每秒执行约 2.27 万次，远快于 AFL++（1,411 exec/s），但覆盖的边数仅为 19，远低于 AFL++ 的 4,048。原因是 libFuzzer driver 的 SanCov 插桩仅统计了 harness 自身代码的覆盖，而非 libexpat 库（编译 libFuzzer 版本时未通过 `-fsanitize-coverage=...` 为库代码添加覆盖率追踪）。AFL++ 的 `afl-clang-fast` 会对所有链接代码统一插桩，因此覆盖率数据更完整。

---

### 调试记录（macOS 试跑阶段）

在 macOS 上尝试运行 AFL++ 时遇到了以下问题，最终迁移到 Linux 完成正式实验：

1. **`shmat()` 权限失败**（`afl-expat-20260524-191529.log`）：Codex 沙箱环境限制了 SysV 共享内存，AFL++ fork server 无法初始化。
2. **Crash reporter 中止**（`afl-expat-20260524-191737.log`）：macOS 默认的 `com.apple.ReportCrash` 服务会导致 crash 通知延迟，AFL++ 将其误判为 timeout。通过设置 `AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1` 绕过。
3. **`shmget()` 失败**（`afl-expat-20260524-191749.log`）：macOS SysV shared memory 大小上限默认为 4MB，而 AFL++ 需要更大的共享内存段。通过 `AFL_MAP_SIZE=1000000` 调整。
4. **Linux 依赖缺失**（`afl-expat-20260525-170821.log`）：Linux 环境缺少 `libpython3.14.so.1.0`，修复 Python 环境后正常。
5. **10 秒短跑验证**（`afl-expat-20260524-191928.log`、`192025.log`）：在 macOS 上成功运行 10 秒，分别获得 28/27 个新 corpus 条目，覆盖率约 8.7%，确认 harness 功能正常。

---

## Crash 处理流程

1. 将 crash 输入复制到 `results/crashes/`。
2. 用同一个 fuzzer 二进制复现。
3. 保存 ASAN/UBSAN 输出。
4. 用 `llvm-symbolizer` 或 `atos` 确认堆栈符号。
5. 判断是 fuzzer 问题、环境问题还是项目 bug。
6. 如为项目 bug，准备最小化输入和 issue 描述。

---

## 下一步工作计划

- [ ] 将 AFL++ 12 小时 corpus 导入 libFuzzer 继续运行，利用两个工具互补
- [ ] 用 AFL++ 对 `expat_stream_fuzzer.c`（含 `XML_GetBuffer` + `XML_ParseBuffer` 路径和 `XML_ExternalEntityParserCreate` 路径）单独 fuzz
- [ ] 运行 libexpat 官方 fuzzer（`run_official_fuzzer.sh`）作为对照
- [ ] 在报告中补充截图素材
- [ ] 完成静态分析结果汇总（结合 Cppcheck 和 Clang Static Analyzer 输出）
- [ ] 撰写最终实验报告
