# 结果记录

> **PPT 数据汇总请直接看 [report.md](report.md)**，本文档记录原始运行细节和素材清单。

---

## 被测版本

| 项目 | 内容 |
|---|---|
| 项目 | libexpat |
| 源码目录 | `third_party/libexpat` |
| Commit | `ff7cedb7`（2.6.4 开发版，含 #1240 和 #1242 merge） |
| 版本特点 | 修复了 include expat-config.h 顺序问题，移除了 legacy comment |

---

## 动态测试运行记录

### AFL++ 12 小时正式运行

| 项目 | 内容 |
|---|---|
| 日期 | 2026-05-25 17:08 ~ 2026-05-26 05:08 |
| 机器 | Linux 5.15.0-25-generic (aarch64)，192 CPU cores |
| fuzzer | AFL++ v4.41a + `fuzz/expat_file_harness.c` |
| sanitizer | ASAN（`AFL_USE_ASAN=1`） |
| 运行时长 | 43,200 秒（12 小时） |
| total execs | 60,959,040（~1,411 exec/s） |
| corpus | 8,795 条（初始 73 seed + 8,722 新发现） |
| coverage | 50.56%（4,048 / 8,006 edges） |
| crash | **0** |
| hang | **0** |
| timeout | 441 |
| stability | 100.00% |
| 日志 | [`results/fuzzing/afl-expat-20260525-170848.log`](../results/fuzzing/afl-expat-20260525-170848.log) |
| fuzzer_stats | [`results/fuzzing/afl-expat/default/fuzzer_stats`](../results/fuzzing/afl-expat/default/fuzzer_stats) |

### libFuzzer 12 小时对照运行

| 项目 | 内容 |
|---|---|
| 日期 | 2026-05-25 17:09 ~ 2026-05-26 05:09 |
| 机器 | 同上 |
| fuzzer | libFuzzer + `fuzz/expat_stream_fuzzer.c` |
| sanitizer | ASAN + UBSAN |
| 运行时长 | 43,201 秒 |
| total execs | 979,431,350（~22,671 exec/s） |
| corpus | 37 条（初始 73 seed → 优化后 37） |
| coverage | 19 edges, 111 features |
| crash | **0** |
| peak RSS | 412 MB |
| 日志 | [`results/fuzzing/libfuzzer-expat-stream-20260525-170921.log`](../results/fuzzing/libfuzzer-expat-stream-20260525-170921.log) |

### AFL++ macOS 10 秒短跑

| 项目 | 内容 |
|---|---|
| 日期 | 2026-05-24 |
| 机器 | macOS (aarch64, 8 cores) |
| 运行时长 | 10 秒 × 2 次 |
| 结果 | 28 / 27 new corpus items，~8.7% coverage，0 crash |
| 日志 | [`results/fuzzing/afl-expat-20260524-191928.log`](../results/fuzzing/afl-expat-20260524-191928.log)、[`192025.log`](../results/fuzzing/afl-expat-20260524-192025.log) |

---

## 静态分析结果

> 完整告警表格见 [report.md §3](report.md#3-静态分析结果)。

### Cppcheck

| 项目 | 内容 |
|---|---|
| 输出 | [`results/static-analysis/cppcheck.txt`](../results/static-analysis/cppcheck.txt) / `cppcheck.xml` |
| 扫描范围 | `expat/lib/` 目录 11 个文件 |
| 告警总数 | ~19 个（style / warning 级别） |
| 高危 | **0** |
| 中风险 | 2（signed shift UB + 格式字符串不匹配） |

### Clang Static Analyzer (scan-build)

| 项目 | 内容 |
|---|---|
| 输出 | [`results/static-analysis/scan-build.txt`](../results/static-analysis/scan-build.txt) |
| 工具版本 | clang-17 |
| 分析范围 | libexpat 7 个 C 源文件 |
| 结果 | **No bugs found** |

---

## 截图素材清单

| 素材 | 路径 | 状态 |
|---|---|---|
| 手写 AFL++ harness 源码 | [`fuzz/expat_file_harness.c`](../fuzz/expat_file_harness.c) | ✅ |
| 手写 libFuzzer driver 源码 | [`fuzz/expat_stream_fuzzer.c`](../fuzz/expat_stream_fuzzer.c) | ✅ |
| AFL++ 运行界面 | `results/screenshots/` | ⏳ 待补充 |
| AFL++ 结束统计 | `results/screenshots/` | ⏳ 待补充 |
| libFuzzer 运行界面 | `results/screenshots/` | ⏳ 待补充 |
| 静态分析运行界面 | `results/screenshots/` | ⏳ 待补充 |
| 静态分析输出 | `results/screenshots/` | ⏳ 待补充 |

---

## 结论

1. **AFL++ 动态 fuzzing：** 12 小时内执行了 6100 万次，覆盖 50.56% 的 edge，未发现任何 crash 或 hang。说明当前版本的 libexpat 在 `XML_Parse` + namespace parser 路径上具有较高的健壮性。
2. **libFuzzer 对照：** 执行了 9.79 亿次，速度远快于 AFL++，但因 libFuzzer 仅统计 harness 代码覆盖率（库代码未加 SanCov 插桩），edge 覆盖数偏低。两项工具互为补充。
3. **静态分析：** Cppcheck 发现 1 个潜在未定义行为（signed shift）和 1 个格式字符串不匹配，但均受编译时常量条件守护或影响有限。Clang Static Analyzer 未发现任何 bug。
4. **综合判断：** libexpat 作为成熟的开源 XML 解析库，长期接受 OSS-Fuzz 测试，代码质量较高。本次实验未发现新的安全漏洞，但成功搭建了完整的 fuzzing + 静态分析环境，验证了手写 driver 的有效性。
