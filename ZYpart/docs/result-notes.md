# 结果记录

## 当前被测版本

- 项目：libexpat
- 源码目录：`third_party/libexpat`
- commit：d3892901

## 动态测试结果

- fuzzer：AFL++ + `fuzz/expat_file_harness.c`
- 运行时长：已短跑 10 秒验证；正式实验填写 12 小时结果
- sanitizer：ASAN + UBSAN
- crash：短跑 0 个
- hang：短跑 0 个
- 日志：`results/fuzzing/`
- 截图：`results/screenshots/`

## 静态分析结果

- Cppcheck 输出：`results/static-analysis/cppcheck.txt`
- Clang Static Analyzer 输出：`results/static-analysis/scan-build/`
- 高可信告警：待人工复核；当前 Clang Static Analyzer 报告 3 个 `core.NullPointerArithm` 相关告警，位置集中在 `xmlparse.c` 的 string pool 处理逻辑
- 误报说明：待结合源码路径和 fuzzing 复现判断

## 报告素材

需要截图：

- `fuzz/expat_stream_fuzzer.c` 手写 driver
- `./scripts/run_libfuzzer.sh 43200` 运行界面
- AFL++ 结束统计
- `./scripts/run_static_analysis.sh` 运行界面
- 静态分析输出目录或 HTML 页面

## 结论草稿

待 12 小时 fuzzing 和静态分析完成后填写。
