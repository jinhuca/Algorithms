# scripts — build cleanup

Scripts for removing all CMake / Qt / MSVC **build output** under `Algorithms`
(the whole monorepo: `graph_algo`, `search_algo`, `sort_algo`, `UI_repo`).

Two equivalent versions are provided — use whichever matches your shell:

| Script             | Use from                                   |
| ------------------ | ------------------------------------------ |
| `clean-builds.sh`  | Git Bash, VS Code bash terminal, WSL       |
| `clean-builds.cmd` | CMD, PowerShell, or double-click in Explorer |

Both do exactly the same thing, never touch source files, and support a
**dry-run** that previews what would be deleted without deleting anything.

---

## What gets deleted

- **Directories** named: `build`, `build-*`, `out`, `cmake-build-*`,
  `CMakeFiles`, `.vs`, `x64`, `Win32`, `Debug`, `Release`
- **Stray files**: `CMakeCache.txt`, `cmake_install.cmake`, `CTestTestfile.cmake`

Anything inside `.git` is skipped. Source files are never removed.

> **Tip:** always do a `--dry-run` first and read the list before deleting.

---

## Git Bash — `clean-builds.sh`

From anywhere (the script locates the repo root itself):

```bash
cd /d/Algorithms
./scripts/clean-builds.sh --dry-run   # preview only, deletes nothing
./scripts/clean-builds.sh             # actually delete build output
```

`-n` is accepted as a short form of `--dry-run`.

If you get `permission denied`, invoke it through bash explicitly (this
bypasses the executable bit):

```bash
bash scripts/clean-builds.sh --dry-run
```

**In VS Code:** open a terminal with the **Git Bash** profile
(Terminal → the `+` split dropdown → *Git Bash*), then run the commands above.

---

## CMD / PowerShell — `clean-builds.cmd`

From the repo root (or any directory — it `cd`s to the root itself):

```bat
cd /d d:\Algorithms
scripts\clean-builds.cmd --dry-run    :: preview only, deletes nothing
scripts\clean-builds.cmd              :: actually delete build output
```

`-n` and `/dry-run` are also accepted as the dry-run flag.

**PowerShell** — same commands, but if you launch it by full path prefix it
with `&`:

```powershell
cd d:\Algorithms
& scripts\clean-builds.cmd --dry-run
```

**Double-click** `clean-builds.cmd` in File Explorer to run a real clean
(no dry-run). The window may close immediately after it finishes.

---

## Notes

- Both scripts are safe to run when there is nothing to clean — they simply
  report `Nothing to clean`.
- Because the subprojects live in this monorepo, running either script cleans
  build output across all of them in one pass.
