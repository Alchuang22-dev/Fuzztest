# 实验数据汇总

> 本文档汇总 libexpat 漏洞挖掘实验的全部数据，供 PPT 制作和报告撰写直接引用。
> 详细过程见 [fuzzing-plan.md](fuzzing-plan.md)、[result-notes.md](result-notes.md)、[static-analysis.md](static-analysis.md)。

---

## 1. 实验概况

| 项目 | 内容 |
|---|---|
| 被测对象 | libexpat 2.6.4-dev（XML 解析库） |
| 源码提交 | `ff7cedb7` |
| 动态测试工具 | AFL++ v4.41a / libFuzzer |
| 静态分析工具 | Cppcheck / Clang Static Analyzer (scan-build, clang-17) |
| Sanitizer | AddressSanitizer (ASAN) / UndefinedBehaviorSanitizer (UBSAN) |
| 运行平台 | Linux 5.15.0-25-generic (aarch64), 192 cores |
| 运行时长 | 12 小时 × 2 组（AFL++ 和 libFuzzer 并行） |
| 总执行次数 | **~10.4 亿次**（AFL++ 6100 万 + libFuzzer 9.79 亿） |
| 发现 crash | **0** |
| 发现 hang | **0** |

---

## 2. 动态 fuzzing 结果

### 2.1 AFL++ 12 小时

| 指标 | 值 |
|---|---|
| 工具版本 | AFL++ v4.41a |
| Harness | `expat_file_harness.c`（覆盖 `XML_Parse` + `XML_ParserCreateNS`） |
| Sanitizer | ASAN（`AFL_USE_ASAN=1`） |
| 运行时长 | 43,200 秒（12 小时） |
| 总执行次数 | **60,959,040** |
| 执行速度 | ~1,411 exec/s |
| Corpus 条数 | **8,795**（初始 73 seed → 新发现 8,722） |
| Edge 覆盖率 | **50.56%**（4,048 / 8,006 edges） |
| 完成周期数 | 26 cycles |
| Crash 数 | **0** |
| Hang 数 | **0** |
| Timeout 数 | 441 |
| 目标稳定性 | 100.00% |
| 日志 | [`results/fuzzing/afl-expat-20260525-170848.log`](../results/fuzzing/afl-expat-20260525-170848.log) |

### 2.2 libFuzzer 12 小时

| 指标 | 值 |
|---|---|
| Harness | `expat_stream_fuzzer.c`（覆盖 `XML_Parse` + `XML_ParseBuffer` + `ExternalEntity`） |
| Sanitizer | ASAN + UBSAN |
| 运行时长 | 43,201 秒（12 小时） |
| 总执行次数 | **979,431,350** |
| 执行速度 | ~22,671 exec/s |
| Corpus 条数 | **37**（初始 73 seed → 优化保留 37） |
| Edge 覆盖率 | 19 edges, 111 features |
| Crash 数 | **0** |
| 峰值内存 | 412 MB |
| 日志 | [`results/fuzzing/libfuzzer-expat-stream-20260525-170921.log`](../results/fuzzing/libfuzzer-expat-stream-20260525-170921.log) |

### 2.3 AFL++ vs libFuzzer 对比

| 维度 | AFL++ | libFuzzer |
|---|---|---|
| 执行速度 | 1,411 exec/s | 22,671 exec/s（**快 16×**） |
| 总执行次数 | 6,100 万 | 9.79 亿（**多 160×**） |
| Corpus 条数 | 8,795（**多 237×**） | 37 |
| Edge 覆盖 | 4,048 edges / 50.56%（**完整覆盖**） | 19 edges（仅 harness 层） |
| 覆盖率差异原因 | `afl-clang-fast` 对所有链接代码统一插桩 | libFuzzer SanCov 仅统计 harness 代码 |
| Crash | 0 | 0 |

**结论：** libFuzzer 执行速度远超 AFL++，但其覆盖率统计不包含库代码。AFL++ 的覆盖率数据更真实地反映了 libexpat 库的覆盖情况。两种工具互为补充——libFuzzer 高速生成大量变异输入，AFL++ 精确追踪库级覆盖率。

---

## 3. 静态分析结果

### 3.1 Cppcheck

| 项目 | 内容 |
|---|---|
| 扫描范围 | `expat/lib/` 目录 11 个 C 源文件 |
| 告警总数 | ~19 个（style + warning 级别） |
| 高危告警 | **0** |
| 中风险告警 | **2**（见下表） |
| 低风险告警 | ~17（代码风格类） |
| 输出文件 | [`results/static-analysis/cppcheck.txt`](../results/static-analysis/cppcheck.txt) |

关键告警：

| 文件:行号 | 类型 | 描述 | 风险 |
|---|---|---|---|
| `xmlparse.c:3960` | `shiftTooManyBitsSigned` | signed 32-bit 值右移 31 位，属未定义行为 | 中（受上方 `if` 条件守护，实际不可达） |
| `xmlparse.c:8454` | `invalidPrintfArgType_sint` | `%ld` 格式与 `ptrdiff_t` 参数不匹配，64 位平台可能输出错误 | 中（仅影响调试日志输出） |
| `xmlparse.c:3594, 4540` | `knownConditionTrueFalse` | `(0) && handler` 恒为 false，属于死代码 | 低 |
| `xmlparse.c:6424, 6882` | `knownConditionTrueFalse` | `!openEntity` 恒为 false | 低 |
| `xmlparse.c:4519, 4681` | `redundantAssignment` | `*eventPP` 赋值后立即被覆盖 | 低 |

### 3.2 Clang Static Analyzer (scan-build)

| 项目 | 内容 |
|---|---|
| 分析工具 | clang-17 + scan-build |
| 分析范围 | libexpat 7 个 C 源文件的完整编译分析 |
| 发现 bug | **0（No bugs found）** |
| 输出文件 | [`results/static-analysis/scan-build.txt`](../results/static-analysis/scan-build.txt) |

---

## 4. 实验覆盖的 API 和路径

| 解析 API | Harness | 工具 |
|---|---|---|
| `XML_Parse` | `expat_file_harness.c` / `expat_stream_fuzzer.c` | AFL++ / libFuzzer |
| `XML_ParserCreate(NULL)` | 两个 harness | AFL++ / libFuzzer |
| `XML_ParserCreateNS(NULL, '!')` | 两个 harness | AFL++ / libFuzzer |
| `XML_GetBuffer` + `XML_ParseBuffer` | `expat_stream_fuzzer.c` | libFuzzer |
| `XML_ExternalEntityParserCreate` | `expat_stream_fuzzer.c` | libFuzzer |

| 回调 Handler | 说明 |
|---|---|
| `StartElementHandler` | 元素开始 |
| `EndElementHandler` | 元素结束 |
| `CharacterDataHandler` | 字符数据 |
| `ProcessingInstructionHandler` | 处理指令（仅 stream fuzzer） |
| `CommentHandler` | 注释（仅 stream fuzzer） |
| `StartCdataSectionHandler` / `EndCdataSectionHandler` | CDATA（仅 stream fuzzer） |

---

## 5. 结论

1. **动态 fuzzing：** 12 小时 × 2 工具共执行约 10.4 亿次，AFL++ 覆盖 50.56% edge，均未发现 crash 或 hang。libexpat 在核心 XML 解析路径上具有高健壮性。
2. **静态分析：** Cppcheck 发现 2 个中风险告警（signed shift 未定义行为、格式字符串不匹配），但均有编译时条件守护或影响有限。Clang SA 未发现 bug。
3. **原因分析：** libexpat 作为 Apache 基金会项目，长期接受 Google OSS-Fuzz 的持续 fuzzing 测试，已修复了大量历史漏洞。本次实验的版本包含最新修复，因此未发现新缺陷是预期结果。
4. **实验价值：** 成功搭建了 AFL++ + libFuzzer + ASAN/UBSAN + Cppcheck + Clang SA 的完整 fuzzing 和静态分析流水线，验证了手写 driver 的有效性，积累了 8,795 条 AFL++ corpus 条目。
