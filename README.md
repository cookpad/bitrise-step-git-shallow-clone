# Git Shallow Clone

Only fetch 1 or 2 commits, even for pull requests.

**WARNING:** Made for internal Cookpad use. Do not use it directly from your Bitrise workflow, it could break at anytime. We do not accept issues or pull requests from outside contributors. But feel free to have a look or fork.

**注意：** クックパッド社内用です。自分のBitrise workflowで参照しないでください。外部の方からのissueやpull requestを受け付けませんが、コードはご自由に読んでも良いですし、フォークしても構いません。

### Limitations

- Not as full featured as the official Bitrise Git Clone step.
- Only tested with GitHub/GitHub Enterprise.
- Fetches as little as possible. That means that if a script tries to look at the Git history, tags or other branches, it will probably fail. Possible solutions:
  - Use the GitHub API to fetch the information you need.
  - Use the official Bitrise Git Clone step. If your repository is small a full clone should be fast enough.
  - You could be adventurous and try to fetch the whole history with any blobs or trees (more information [here](https://github.blog/2020-12-21-get-up-to-speed-with-partial-clone-and-shallow-clone/)) with for example `git fetch --filter=blob:none --unshallow origin` (or if you don't even need the trees `--filter=tree:0` instead of `--filter=blob:none`). Be careful, as that will turn on fetch on demand. Fetch on demand fetches one item at a time, making it very slow and heavy for the server, so should only be used if you have to fetch very little information.
