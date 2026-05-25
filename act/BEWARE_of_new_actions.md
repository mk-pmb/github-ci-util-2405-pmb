
Beware: Having `purge-old-workflow-runs` seemed to be a good idea,
but I ended up having to hard-copy the install steps into it because
GitHub doesn't seem to offer an easy way to refer to a composite
action in the same action repo.

* &rArr; If your action needs `ghciu` installed, consider making it
  an optional side effect of the install action instead.



