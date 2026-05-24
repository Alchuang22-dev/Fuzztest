# libexpat 漏洞挖掘开发文档

## 1. 实验目标

本项目对 `libexpat` XML 解析库进行漏洞挖掘和软件度量，完成以下目标：

1. 搭建可复现的 fuzzing 和静态分析环境。
2. 编写手写 AFL++/libFuzzer driver，覆盖核心 XML 解析 API。
3. 使用 sanitizer 辅助发现内存错误和未定义行为。
4. 使用 Cppcheck 和 Clang Static Analyzer 做静态分析。
5. 保存运行过程、截图、日志、crash 和分析结论。

## 2. 被测对象

`libexpat` 是一个 C 语言实现的流式 XML parser。项目核心代码位于：

```text
third_party/libexpat/expat/lib/
```

重点关注文件：

- `xmlparse.c`：解析器主逻辑
- `xmltok.c`、`xmltok_impl.c`：XML tokenization
- `xmlrole.c`：DTD/role 相关状态机
- `expat.h`：公开 API

## 3. Driver 设计

手写 fuzzer 位于：

```text
fuzz/expat_stream_fuzzer.c
fuzz/expat_file_harness.c
```

设计思路：

- AFL++ 版本从命令行文件参数读取输入，配合 `afl-fuzz ... -- harness @@` 使用。
- libFuzzer 版本由 `LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)` 接收输入。
- 对过大的输入设置上限，避免单次执行时间过长。
- 同一份输入通过多种 parser 入口测试：
  - `XML_ParserCreate(NULL)`
  - `XML_ParserCreateNS(NULL, '!')`
  - `XML_ExternalEntityParserCreate(...)`
- 同时覆盖两类解析模式：
  - `XML_Parse`
  - `XML_GetBuffer` + `XML_ParseBuffer`
- 设置 element、character、processing instruction、comment、CDATA 等 handler，触发更多回调路径。
- 对解析失败不视为 bug，因为畸形 XML 是 fuzzing 的正常输入；只有 crash、ASAN/UBSAN 报错、hang 才进入漏洞分析。

## 4. 构建方式

构建脚本：

```bash
./scripts/build_fuzzers.sh
```

脚本做两件事：

1. 使用 CMake 构建 ASAN 版本静态 `libexpat.a` 和复现 harness。
2. 使用 `afl-clang-fast` 构建 AFL++ 插桩版静态库和 `expat_file_harness`。
3. 保留 `fuzz/expat_stream_fuzzer.c` 作为 libFuzzer driver，适用于 Linux/LLVM libFuzzer runtime 环境。

核心编译选项：

```text
-fsanitize=address,undefined
-fno-omit-frame-pointer
-g -O1
```

## 5. 动态测试流程

先短跑确认：

```bash
./scripts/run_libfuzzer.sh 60
```

正式 12 小时运行：

```bash
./scripts/run_afl.sh 43200
```

如果发现 crash，记录：

- crash 文件路径
- 复现命令
- ASAN/UBSAN stack trace
- 触发函数
- 可能的问题类型
- 是否为项目本身 bug

## 6. 静态分析流程

运行：

```bash
./scripts/run_static_analysis.sh
```

输出保存到：

```text
results/static-analysis/
```

重点筛选：

- 越界读写
- 空指针解引用
- use-after-free
- double free
- 整数溢出
- 未初始化值
- 资源泄漏

## 7. 报告写作口径

如果没有发现真实 bug，报告应说明：

- fuzzing 覆盖了哪些 API 和解析模式；
- 运行时间、执行次数、覆盖变化；
- sanitizer 和静态分析没有发现高可信缺陷；
- 可能的原因是 libexpat 已长期接受 OSS-Fuzz/回归测试；
- 后续改进可加入结构化 XML 生成、DTD/实体专项语料、差分测试和 LPM fuzzer。

如果发现 bug，报告应增加：

- 最小化输入；
- 复现命令；
- ASAN/UBSAN 或 gdb 堆栈；
- 根因分析；
- 影响评估；
- issue 链接。
