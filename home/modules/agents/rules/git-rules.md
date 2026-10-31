# Rules

## Git

Only read-only git commands are allowed, with one exception: creating
isolated worktrees for review (see below). Do not execute any git command
that modifies commits, branches, tags, remote state, the index, or the
stash.

Allowed (read-only / non-destructive):

- `git status`
- `git log`
- `git diff`
- `git show`
- `git branch` (listing only)
- `git remote -v`
- `git stash list`
- `git fetch` - updates remote-tracking refs only; never modifies local
  branches, the working tree, the index, or any remote

Allowed (isolated, non-destructive):

- `git worktree add .worktrees/<name> <ref>` - creates a new checkout in a
  separate directory; does not touch the main working tree, index, or remote.
- `git worktree list`

Forbidden (state-changing):

- `git checkout` / `git switch` # in the main working tree
- `git commit`, `git push`, `git pull`, `git merge`,
  `git rebase`, `git reset`, `git clean`
- `git stash` (push/pop/drop)
- `git branch -d` / `git branch -D`, `git tag` (creating/deleting)
- `git worktree remove` / `git worktree prune` # cleanup is yours to run
- Any other command that creates, deletes, or modifies commits, branches,
  tags, remote state, the index, or the stash
