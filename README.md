# dev-tools

A small collection of internal utilities used to reduce friction in day-to-day engineering work.

These tools are intentionally simple, auditable, and safe-by-default.

---

## thesis-sync.sh

A WSL-based file routing utility for moving work artifacts from a Windows environment into the correct server-side Git repositories.

### Why it exists
- Reduce context switching between Windows, WSL, and remote servers
- Avoid manual SCP commands
- Enforce intentional placement of files via declarative headers
- Keep repositories clean (no routing metadata lands in Git)

---

## How it works (high level)

1. You place a file in `C:\Users\<user>\Downloads`
2. The file includes a first-line `TARGET` header declaring its destination
3. Running `thesis-sync.sh`:
   - parses the header
   - strips the header from the payload
   - uploads the file to the correct repo/path on the server
   - moves the local file to `_processed/`

No file is moved unless it explicitly opts in via a header.

---

## TARGET header formats

Supported first-line formats:

```text
// TARGET: backend path/to/file
# TARGET: frontend path/to/file
<!-- TARGET: portfolio path/to/file -->
```
### Header handling

The TARGET header is removed before the file lands in the repository.
This allows routing of formats that do not support comments (for example, JSON) without polluting repository contents.

---

### Safety characteristics

* No destructive defaults
* Explicit opt-in via a first-line TARGET header
* Binary and media files are ignored
* Conflict behavior is configurable (overwrite or skip)
* Processed files are retained locally by default for auditability

---

### Intended scope

This is **not** a general-purpose file manager.

It is a narrow, opinionated utility designed to support a specific workflow involving:

* WSL
* SSH
* Git-based repositories
* IP-sensitive and pre-product engineering work

The tool optimizes for correctness, intent, and low cognitive overhead rather than flexibility.

---

### License

Internal tooling.
Public for reference, review, and discussion.
