# Git-hosted dependency is not built in a new global virtual store slot

With `enableGlobalVirtualStore: true`, pnpm builds a git-hosted dependency only in the first slot it
creates for that dependency. When the same commit later needs a new slot (because one of its dependencies
resolves to another version), pnpm links the new slot without running the build.

## Environment

- pnpm 12.15.0
- Node.js 24.22.0 (host) and 24.22.1 (Docker container)
- Linux x86_64

## Files

```text
project-a/package.json          node-expat from github:xmppo/node-expat#78e559b (v2.4.1, a native addon)
project-a/pnpm-workspace.yaml   shared store ../store, global virtual store on, nan 2.27.0, build allowed
project-b/…                     the same, but nan 2.26.2
repro.sh                        clears the store, installs project-a, then project-b
```

The only difference between the projects is the `nan` override. It gives `node-expat` a different
dependency, so project-b needs a new slot for the same `node-expat` commit.

## Run

```sh
bash repro.sh
```

Needs `pnpm`, network access to GitHub and registry.npmjs.org, and a C++ toolchain for `node-gyp`. Each run
starts from an empty store.

## Output

```text
project-a: built
project-b: NOT BUILT
```

`built` means `node_modules/node-expat/build/Release/*.node` exists.

## Expected

```text
project-a: built
project-b: built
```

## Details

- pnpm exits 0 and prints no warning. The app fails later, at runtime, when it loads the addon.
- The two slots are `store/v11/links/@/node-expat/2.4.1/<hash-a>` and `…/<hash-b>`.
- The store index (`store/v11/index.db`, table `package_index`) has one row per git-hosted package, not one
  per slot: `https://codeload.github.com/xmppo/node-expat/tar.gz/78e559b…\tbuilt`. pnpm seems to read that
  row as "this package is already built" and skips the build for every later slot.
- `pnpm rebuild` in project-b exits 0 and does not build the slot. `sideEffectsCache: false` does not help.
- Deleting only project-b's slot folder and installing again does not help: the row is still there.
- Deleting the slot folder and the row makes the next install build the slot. pnpm then writes the row
  again, so the next new slot has the same problem.
- A `git+file://` dependency has the same problem (row key `git+file://…#<commit>\tbuilt`). A `file:`
  tarball with an install script is built in both slots, so this is specific to git-hosted dependencies.

## Workaround

After an install, find slots without the build output, delete them and the `\tbuilt` row, then install
again.
