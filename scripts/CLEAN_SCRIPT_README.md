From d:\Algorithms, run it in Git Bash (which is the shell you have — the same one these commands use):

cd /d/Algorithms
./scripts/clean-builds.sh --dry-run   # preview — deletes nothing
./scripts/clean-builds.sh             # actually delete build output
A few practical notes:

Always run --dry-run first — it lists exactly what would be deleted so you can eyeball it before committing to the delete.
It works from anywhere — the script cds to the repo root itself, so ./scripts/clean-builds.sh from d:\Algorithms, or d:/Algorithms/scripts/clean-builds.sh from any directory, both clean the whole tree.
If you're not in Git Bash
From VS Code: open a terminal and pick the Git Bash profile (Terminal → split dropdown → Git Bash), then the commands above.
From PowerShell or CMD, call bash explicitly:

bash d:/Algorithms/scripts/clean-builds.sh --dry-run
Double-clicking won't work well (.sh isn't a native Windows executable) — use a bash shell.
If you get permission denied, run it as bash scripts/clean-builds.sh (that bypasses the executable bit).