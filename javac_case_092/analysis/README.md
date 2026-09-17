可以。第 92 条的制作过程，实际上已经形成了一套比较完整的“跨语言 Bug → SWE-bench 风格数据”的框架。

**一、案例信息确认**

第 92 条对应：

```
项目：ninia/jep
Issue：#77
语言：Java-C
instance_id：ninia__jep-77
Base commit：d14567567ac1281e978790b9170c981113de282f
Fix commit：bd14a110911af80e7299767f43c570e2fca4d459
JEP 版本：3.6.3
```

Bug 位于：

```
src/jep/pyembed.c
函数：pyembed_run_pyc
```

根因是 Python 3.3 以后 `.pyc` 文件头多了一个 source-size 字段，JEP 没有读取该字段，导致后续 marshal 数据偏移错误，最终出现：

```
Bad code object in .pyc file
```

修复方式是在 Python 3 环境下额外调用一次：

```
PyMarshal_ReadLongFromFile(fp);
```

**二、测试补丁确认**

我们首先检查了原项目 Base 版本是否已经包含回归测试。

结果是：

- Base commit 中没有这组回归测试；
- Fix commit 中新增了官方测试；
- 因此从 Fix commit 中提取出官方 `test_patch.diff`；
- 没有重新编写 synthetic 测试。

官方测试文件是：

```
src/jep/test/TestCompiledScript.java
tests/test_run_script.py
```

核心测试：

```
test_run_script.TestRunScript.test_compiledScript
```

这也确定了我们的测试构造原则：

```
优先使用原项目官方测试；
只有没有官方测试时，才编写 synthetic 测试。
```

**三、Base/Fix 真实验证**

我们分别验证了 Base 和 Fix：

Base：

```
151 tests
121 passed
29 skipped
1 failure
```

失败测试：

```
test_run_script.TestRunScript.test_compiledScript
```

Fix：

```
151 tests
122 passed
29 skipped
0 failures
```

因此得到：

```
FAIL_TO_PASS：
test_run_script.TestRunScript.test_compiledScript
```

通过比较 Base/Fix 两次测试结果，得到 121 条：

```
PASS_TO_PASS
```

也就是说，`PASS_TO_PASS` 不是手工猜测，而是通过 Base 和 Fix 的真实测试结果交集得到的。

**四、Docker 环境复现**

为了让别人能够复现，我们制作了 Linux Docker 环境：

```
镜像：javac-case-092-jep:py353-jdk8
基础镜像：eclipse-temurin:8-jdk-jammy
Python：3.5.3
Java：OpenJDK/Temurin 8
```

Docker 中重新编译了 JEP，并验证：

```
Base：复现 Bad code object in .pyc file
Fix：151 tests 通过
```

Linux 容器结果：

```
Ran 151 tests
OK (skipped=20)
```

Windows 原生环境是 `skipped=29`，Linux 容器是 `skipped=20`。这是平台差异，不影响核心结论：

```
Base fails
Fix passes
```

这里我们也修复了几个 Docker 问题：

- Ubuntu 16.04 old-releases 源返回 404；
- 改用 Temurin JDK 8 Jammy；
- Python 3.5.3 从源码编译；
- 放宽 Docker 测试脚本对 skipped 数量的限制；
- 解决 Windows CRLF 源码与 Linux LF 补丁不兼容的问题。

**五、官方字段兼容版**

我们整理了官方风格的标准记录：

```
instance_092.json
instance_092.jsonl
```

核心字段包括：

```
instance_id
repo
base_commit
patch
test_patch
problem_statement
hints_text
created_at
version
FAIL_TO_PASS
PASS_TO_PASS
```

其中：

- `patch` 是完整 gold patch 内容；
- `test_patch` 是完整测试补丁内容；
- `FAIL_TO_PASS` 有 1 条；
- `PASS_TO_PASS` 有 121 条；
- JSON 和 JSONL 内容保持一致。

同时保留了扩展分析数据：

```
single_javac_case_092.json
single_javac_case_092.jsonl
single_javac_case_092.xlsx
environment_spec.json
README.md
gold_patch.diff
test_patch.diff
```

**六、公开任务与私有评测材料分离**

这是后面非常重要的一步。

公开给模型的文件是：

```
public_task_092.json
```

它只包含：

```
instance_id
repo
base_commit
problem_statement
hints_text
created_at
version
issue_id
issue_url
project_version
```

它不包含：

```
gold patch
test patch
FAIL_TO_PASS
PASS_TO_PASS
```

私有评测端保留：

```
instance_092.json
test_patch.diff
gold_patch.diff
FAIL_TO_PASS
PASS_TO_PASS
```

这样模型不会直接看到答案，也不会直接看到评测 oracle。

**七、模型补丁自动评测器**

我们又制作了专用的模型评测镜像：

```
javac-case-092-jep:model-evaluator
```

这个镜像只包含：

- Base 源码；
- 官方测试补丁；
- Python 3.5.3；
- JDK 8；
- GCC；
- 评测脚本。

它不包含：

- Fix 源码；
- `gold_patch.diff`。

模型补丁评测流程是：

```
1. 解压 Base 源码
2. 统一 CRLF/LF 换行格式
3. 应用 test_patch
4. 应用 model_patch
5. 编译 JEP
6. 执行 python setup.py test
7. 检查 151 个测试
8. 输出 resolved 或 failed
```

最终示例补丁已经真实验证成功：

```
{
  "instance_id": "ninia__jep-77",
  "status": "resolved",
  "reason": "all_tests_passed",
  "test_exit_code": 0,
  "pass_to_pass_count": 121
}
```

结果文件位于：

```
E:\Swe-bench\javac_case_092\official_swebench\evaluator\model_patch_summary.json
```

**八、最终目录结构**

第 92 条目前的主要目录是：

```
E:\Swe-bench\javac_case_092
```

核心结构可以理解为：

```
javac_case_092/
├── single_javac_case_092.xlsx
├── single_javac_case_092.json
├── single_javac_case_092.jsonl
├── environment_spec.json
├── README.md
├── gold_patch.diff
├── test_patch.diff
├── docker/
│   ├── Dockerfile
│   ├── Dockerfile.model_evaluator
│   ├── run_case.sh
│   ├── run_model_patch.sh
│   ├── jep_base_d145675.tar.gz
│   └── jep_fix_bd14a110.tar.gz
└── official_swebench/
    ├── instance_092.json
    ├── instance_092.jsonl
    ├── public_task_092.json
    ├── metadata.json
    └── evaluator/
        ├── evaluate_model_patch.ps1
        ├── build_model_evaluator.ps1
        ├── model_patch.example.diff
        └── model_patch_summary.json
```

**九、我们最终形成的通用框架**

以后每一条数据都可以按照这个顺序制作：

```
1. 从 Excel 确定案例、项目、Issue 和修复提交
2. 确定 Base commit 和 Fix commit
3. 检查 Base 是否已有官方测试
4. 优先提取原项目官方测试
5. 必要时编写 synthetic test
6. 真实运行 Base 和 Fix
7. 提取 FAIL_TO_PASS
8. 提取 PASS_TO_PASS
9. 提取 gold patch
10. 制作 Docker 环境
11. 验证 Base fail、Fix pass
12. 制作官方字段 JSON/JSONL
13. 分离公开任务文件和私有评测数据
14. 制作模型补丁评测器
15. 用 gold patch 做一次 evaluator 自测
16. 保存 Docker、Excel、JSON、补丁和日志
```

所以第 92 条不只是“整理了一行 JSON”，而是完整走通了：

```
原始跨语言 Bug
→ 官方测试确认
→ Base/Fix 真实验证
→ FAIL_TO_PASS/PASS_TO_PASS
→ Docker 环境
→ 官方字段兼容
→ 公开任务与私有 oracle 分离
→ 模型补丁自动评测
```

后面处理第 93 条时，真正需要重复的主要是前半部分案例分析和测试验证；Docker、公开任务、私有评测器以及目录组织方式都可以直接复用第 92 条的模板。
