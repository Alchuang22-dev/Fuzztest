# 静态分析计划

## 工具

本项目使用两类静态分析工具：

- Cppcheck：轻量、易保存 XML/文本结果。
- Clang Static Analyzer：通过 `scan-build` 分析 CMake 构建过程。

## 运行命令

```bash
./scripts/run_static_analysis.sh
```

## 输出位置

```text
results/static-analysis/
  cppcheck.txt
  cppcheck.xml
  scan-build/
```

## 关注告警

优先关注以下类型：

- `nullPointer`
- `uninitvar`
- `memleak`
- `doubleFree`
- `arrayIndexOutOfBounds`
- `integerOverflow`
- `resourceLeak`

当前试跑结果：

- Cppcheck：完成 `expat/lib` 目录 11 个文件扫描，输出见 `results/static-analysis/cppcheck.txt`。
- Clang Static Analyzer：生成 HTML 报告，当前有 3 个 `core.NullPointerArithm` 相关告警，输出见 `results/static-analysis/scan-build/`。

## 误报判断标准

告警需要结合源码判断：

- 是否存在真实可达路径；
- 是否需要特殊编译选项；
- 是否已被上层长度检查保护；
- 是否只发生在测试代码或示例代码；
- 是否能被 fuzzing 输入触发。

## 报告记录模板

- 工具：
- 版本：
- 命令：
- 分析范围：
- 告警总数：
- 高可信告警：
- 误报数量：
- 典型告警位置：
- 截图路径：
- 结论：
