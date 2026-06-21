# Building with Bazel

This project can be built using [Bazel](https://bazel.build/) as an alternative to the
Makefile/`go build` workflow. Bazel provides reproducible, hermetic builds with fine-grained
incremental caching.

## Prerequisites

- **Bazelisk** (recommended) or Bazel 9.x+. Bazelisk automatically downloads the correct
  Bazel version based on the `MODULE.bazel` file.

  ```sh
  # install bazelisk
  go install github.com/bazelbuild/bazelisk@latest
  ```

- **Go 1.24.4** — automatically downloaded by `rules_go`; no manual install required.

- **Linux x86_64** — the current Bazel configuration targets `k8-fastbuild`. Other platforms
  require additional configuration.

## Building

```sh
# build everything (binary, libraries, and test targets)
bazel build //...

# build just the gh binary
bazel build //cmd/gh
```

The resulting binary is at `bazel-bin/cmd/gh/gh_/gh`.

## Running tests

```sh
# run all tests
bazel test //...

# run tests for a specific package
bazel test //git:git_test
bazel test //pkg/cmd/pr/list:list_test
```

Test results and logs are under `bazel-testlogs/`.

## How it works

### MODULE.bazel

The project uses [Bzlmod](https://bazel.build/external/module) (the modern Bazel dependency
system) via `MODULE.bazel`. Key dependencies:

| Dependency | Version | Purpose |
|---|---|---|
| `rules_go` | 0.60.0 | Go compilation rules |
| `gazelle` | 0.45.0 | Automatic BUILD file generation from `go.mod` |
| `rules_proto` | 7.1.0 | Protocol Buffer compilation |
| `protobuf` | 33.4 | Protobuf runtime and compiler |

### Gazelle and BUILD.bazel files

[Gazelle](https://github.com/bazelbuild/bazel-gazelle) reads `go.mod` and generates
`BUILD.bazel` files for every Go package. When adding or removing Go source files, regenerate
BUILD files:

```sh
bazel run //:gazelle
```

When adding a new external dependency, update `go.mod` first, then run:

```sh
bazel run //:gazelle -- update-repos -from_file=go.mod -to_macro=deps.bzl%go_dependencies
```

### Gazelle overrides

Some third-party dependencies need special handling. Overrides are declared in `MODULE.bazel`
under `go_deps.gazelle_override()`. For example, `certificate-transparency-go` requires proto
mode to be disabled because its `configpb` sub-package contains pre-generated `.pb.go` files
that conflict with Gazelle's proto BUILD generation.

## Known issues

### git tests and Bazel sandbox

The `//git:git_test` target exercises real git operations against a fixture bare repository
(`git/fixtures/simple.git`). Bazel's linux sandbox prevents git subprocesses from accessing
data files through the runfiles directory. The test works around this by copying the fixture
to a temp directory at runtime.

If you add new tests to `git/` that use the fixture, use the `cpFixture` helper:

```go
func TestSomething(t *testing.T) {
    dir := t.TempDir()
    cpFixture(t, dir)
    client := Client{RepoDir: dir}
    // ...
}
```

### External dependency resolution

When `bazel build` or `bazel test` fails with missing dependency errors for an external Go
module, check the `go_deps.gazelle_override()` section in `MODULE.bazel`. The override may
need additional directives or a different `build_file_generation` mode.

## Comparison with Make

| Task | Make | Bazel |
|---|---|---|
| Build binary | `make bin/gh` | `bazel build //cmd/gh` |
| Run tests | `make test` | `bazel test //...` |
| Cross-compile | `GOOS=linux GOARCH=arm make bin/gh` | not yet configured |
| Generate docs | `make manpages` | not yet configured |
| Install | `make install` | not yet configured |

Bazel does not yet replace the full Makefile workflow. It covers building and testing only.
