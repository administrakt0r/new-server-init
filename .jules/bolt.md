## 2026-02-21 - [Spinner Efficiency]
**Learning:** Using `ps | awk | grep` in a tight loop to monitor a process in a shell script is extremely inefficient, spawning multiple processes every few milliseconds. This can consume significant CPU resources (up to 10% of a core on small VPS) just for the UI.
**Action:** Use `kill -0 $PID` to check for process existence instead, which is a much cheaper operation (often a shell builtin).

## 2026-02-21 - [Shallow Deployment]
**Learning:** Default `git clone` operations download the entire history of a repository, which is unnecessary for automated server deployments and increases bandwidth/time consumption.
**Action:** Always use `--depth 1` for deployment clones to minimize network and disk overhead.
