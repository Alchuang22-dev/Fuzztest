# 动态测试计划

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

## 记录模板

- 日期：
- 机器环境：
- libexpat commit：
- fuzzer：
- sanitizer：
- 运行时长：
- total execs：
- corpus 数量：
- coverage 变化：
- crash 数量：
- hang 数量：
- 截图路径：
- 日志路径：
- 结论：

## Crash 处理流程

1. 将 crash 输入复制到 `results/crashes/`。
2. 用同一个 fuzzer 二进制复现。
3. 保存 ASAN/UBSAN 输出。
4. 用 `llvm-symbolizer` 或 `atos` 确认堆栈符号。
5. 判断是 fuzzer 问题、环境问题还是项目 bug。
6. 如为项目 bug，准备最小化输入和 issue 描述。
