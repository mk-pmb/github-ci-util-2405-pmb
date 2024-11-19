
purge-old-workflow-runs
=======================

For parameter description, see [`action.yaml`](action.yaml).

For how to use it, see
[this workflow](../../.github/workflows/wipe_old_workflow_runs.yaml).



"Wipe" vs. "purge" confusion
----------------------------

The example workflow for this called "wipe…" instead of "purge…"
because I renamed it after the action was published already.
When I added it to a project that already had an action named "prepare",
it was annoying to have to type an extra letter for tab completion just
to evade the file name of an action that I probably won't need to edit
for a very long time. This annoyance was likely to occurr in other projects
as well, because there are a lot of generic action names that start with
"p" (e.g. "pack", "pre-" + anything, "publish"), so I considered it a good
idea to rename the file to start with a less popular first letter.





