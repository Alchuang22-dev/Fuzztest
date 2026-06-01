# 静态分析

> 告警汇总表格见 [report.md §3](report.md#3-静态分析结果)，本文档记录方案和详细分析。

---

## 工具

本项目使用两类静态分析工具：

- **Cppcheck：** 轻量级 C/C++ 静态分析器，输出 text 和 XML 格式。
- **Clang Static Analyzer：** 通过 `scan-build` 包装 CMake 构建，进行路径敏感的数据流分析。

## 运行命令

```bash
./scripts/run_static_analysis.sh
```

## 输出位置

```text
results/static-analysis/
  cppcheck.txt          # Cppcheck 可读文本输出
  cppcheck.xml          # Cppcheck 机器可读 XML 输出
  scan-build.txt        # Clang SA 分析日志
```

## 关注告警类型

| 类型 | 说明 |
|---|---|
| `nullPointer` | 空指针解引用 |
| `uninitvar` | 使用未初始化变量 |
| `memleak` | 内存泄漏 |
| `doubleFree` | 重复释放 |
| `arrayIndexOutOfBounds` | 数组越界 |
| `integerOverflow` | 整数溢出 |
| `resourceLeak` | 资源泄漏 |

---

## 分析结果

### Cppcheck

| 项目 | 内容 |
|---|---|
| 扫描范围 | `expat/lib/` 目录 11 个 C 源文件 |
| 告警总数 | ~19 个（style + warning 级别） |
| 高危告警 | **0** |
| 中风险告警 | **2** |

关键告警详细分析：

| 位置 | 规则 | 描述 | 风险 | 判定 |
|---|---|---|---|---|
| `xmlparse.c:3960` | `shiftTooManyBitsSigned` | signed 32-bit 值右移 31 位，理论上属于未定义行为 | 中 | **误报**：上方 L3952 有 `if (m_nsAttsPower >= sizeof(unsigned int) * 8)` 守护，该分支不可达 |
| `xmlparse.c:8454` | `invalidPrintfArgType_sint` | `%ld` 格式与 `ptrdiff_t` 参数不匹配 | 中 | **真实**：64 位平台上可能输出错误值，但仅影响调试日志 |
| `xmlparse.c:3594, 4540` | `knownConditionTrueFalse` | `(0) && handler` 恒为 false | 低 | 死代码残留，不影响运行 |
| `xmlparse.c:6424, 6882` | `knownConditionTrueFalse` | `!openEntity` 恒为 false | 低 | 宏展开后死代码 |
| `xmlparse.c:4519, 4681` | `redundantAssignment` | `*eventPP` 赋值后立即被覆盖 | 低 | 冗余赋值，不影响正确性 |
| 其余 ~10 处 | `variableScope` / `constVariablePointer` / `unreadVariable` | 变量作用域/const 声明优化 | 低 | 纯代码风格 |

### Clang Static Analyzer (scan-build)

| 项目 | 内容 |
|---|---|
| 工具版本 | clang-17 |
| 分析方式 | 包装 CMake 编译，路径敏感分析 |
| 分析范围 | libexpat 核心库 7 个 C 文件（`xmlparse.c`, `xmlrole.c`, `xmltok.c`, `random_*.c`） |
| 发现 bug | **0（No bugs found）** |

> 注：macOS 上使用旧版 clang 扫描时曾报告 3 个 `core.NullPointerArithm` 告警。迁移到 Linux 使用 clang-17 后重新扫描，这些告警不再出现（可能为工具版本差异或随 commit 修复）。

---

## 误报判断标准

告警需要结合源码判断：

- 是否存在真实可达路径；
- 是否需要特殊编译选项；
- 是否已被上层长度检查保护；
- 是否只发生在测试代码或示例代码；
- 是否能被 fuzzing 输入触发。

**本次分析结论：** 未发现可通过 fuzzing 输入触发的内存安全缺陷。
