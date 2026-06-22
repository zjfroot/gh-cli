---
name: bazel
description: Use when asking questions about Bazel builds, troubleshooting Bazel errors, adding BUILD files, understanding MODULE.bazel, running tests with Bazel, or any Bazel-related task in this project
---

# Bazel Quick Reference

Read `docs/bazel.md` for full documentation. Below is a quick reference.

## Commands

| Task | Command |
|------|---------|
| Build everything | `bazel build //...` |
| Build gh binary | `bazel build //cmd/gh` |
| Run all tests | `bazel test //...` |
| Run one test | `bazel test //git:git_test` |
| Regenerate BUILD files | `bazel run //:gazelle` |
| Update deps | `bazel run //:gazelle -- update-repos -from_file=go.mod` |
| Clean | `bazel clean` |
| Debug build | `bazel build //... --verbose_failures` |

## Common Fixes

- **"missing strict dependencies"** → `bazel run //:gazelle`
- **"no such package"** → add repo to `use_repo(go_deps, ...)` in MODULE.bazel
- **"flag provided but not defined"** → wrong Gazelle directive, check MODULE.bazel
- **Test file not found** → sandbox issue; copy fixtures to `t.TempDir()` at runtime

## Project Quirks

- `certificate-transparency-go` needs `gazelle:proto disable`
- Git tests use `cpFixture()` to work around sandbox restrictions
- Cross-compilation and install not yet configured; use `make` for those

## Labels

```
//cmd/gh          # the gh binary
//git:git_test    # test target
//...             # all targets
```
