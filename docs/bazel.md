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

## Troubleshooting

### "missing strict dependencies" / "No dependencies were provided"

A Go file imports a package that isn't declared in `deps` in the BUILD.bazel.

**Fix:**
1. Run `bazel run //:gazelle` to regenerate BUILD files
2. If that doesn't help, check if the import path matches the `importpath` in the target's BUILD.bazel
3. For proto packages, you may need a `gazelle_override` in `MODULE.bazel` (see "Gazelle overrides" above)

### "flag provided but not defined"

A Gazelle directive name is wrong in `MODULE.bazel`.

**Fix:** Check the directive name against [Gazelle docs](https://github.com/bazelbuild/bazel-gazelle#directives). Common correct directives:
- `gazelle:proto disable`
- `gazelle:resolve go <importpath> <target>`
- `gazelle:exclude <pattern>`

### "no such package" / "repository could not be resolved"

A dependency isn't declared in `use_repo()` in `MODULE.bazel`.

**Fix:** Add the repo name to the `use_repo(go_deps, ...)` list. Repo names follow the pattern: `com_github_owner_repo` (underscores replace slashes/dots).

### Test fails with "not a git repository" or file not found

Bazel's sandbox isolates the test from the source tree. Relative paths like `./fixtures/simple.git` don't resolve.

**Fix:** Copy test fixtures to `t.TempDir()` at runtime. See `git/client_test.go` for the `cpFixture()` helper.

### Build is very slow on first run

Protobuf toolchains and Go SDK download/compile on first build. Subsequent builds use the cache.

**Fix:** Be patient. Use `--jobs=N` to limit parallelism if memory-constrained.

### "ERROR: interrupted" / timeout

Large builds may exceed default timeouts.

**Fix:** Add `--timeout=3600` (seconds) to the command.

### Debugging commands

```sh
bazel build //... --verbose_failures    # see failing commands
bazel build //... --sandbox_debug       # debug sandbox issues
bazel query 'deps(//cmd/gh)'           # check dependencies
bazel query 'kind(".*_test", //...)'   # list all test targets
```

## Adding a new Go package

1. Create your Go package normally
2. Run `bazel run //:gazelle` — it auto-generates the BUILD.bazel
3. Verify: `bazel build //your/package`

## Adding a new external dependency

1. `go get github.com/new/dep@version`
2. `go mod tidy`
3. `bazel run //:gazelle -- update-repos -from_file=go.mod`
4. If the new dep needs special handling, add a `go_deps.gazelle_override()` in `MODULE.bazel`

## Project-specific quirks

1. **Go SDK 1.24.4** — pinned in `MODULE.bazel` via `go_sdk.download(version = "1.24.4")`
2. **certificate-transparency-go** — needs `build_file_generation = "auto"` with `gazelle:proto disable` because its `configpb` package has pre-generated proto files
3. **git tests** — use `cpFixture()` to copy `git/fixtures/simple.git` to a temp dir (sandbox blocks subprocess access to data files)
4. **No cross-compilation yet** — Bazel config targets `k8-fastbuild` only
5. **No install/release** — `make install` and `goreleaser` still use the Makefile workflow

## Comparison with Make

| Task | Make | Bazel |
|---|---|---|
| Build binary | `make bin/gh` | `bazel build //cmd/gh` |
| Run tests | `make test` | `bazel test //...` |
| Cross-compile | `GOOS=linux GOARCH=arm make bin/gh` | not yet configured |
| Generate docs | `make manpages` | not yet configured |
| Install | `make install` | not yet configured |

Bazel does not yet replace the full Makefile workflow. It covers building and testing only.
