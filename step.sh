#!/bin/bash
set -e

export_env() {
  key="$1"
  value="$2"
  envman add --key "$key" --value="$value"
  echo "exporting $key: \"$value\""
}

export_single_commit_info() {
  ref="$1"
  key="$2"
  format="$3"
  value=$(git log -1 --format="$format" "$ref")
  export_env "$key" "$value"
}

export_common_commit_details() {
  ref=$1
  export_single_commit_info "$ref" "GIT_CLONE_COMMIT_AUTHOR_NAME" "%an"
  export_single_commit_info "$ref" "GIT_CLONE_COMMIT_AUTHOR_EMAIL" "%ae"
  export_single_commit_info "$ref" "GIT_CLONE_COMMIT_HASH" "%H"
  export_single_commit_info "$ref" "GIT_CLONE_COMMIT_MESSAGE_SUBJECT" "%s"
  export_single_commit_info "$ref" "GIT_CLONE_COMMIT_MESSAGE_BODY" "%b"
}

export_non_pr_commit_details() {
  ref=$1
  export_single_commit_info "$ref" "GIT_CLONE_COMMIT_COMMITER_NAME" "%cn"
  export_single_commit_info "$ref" "GIT_CLONE_COMMIT_COMMITER_EMAIL" "%ce"
  # We are always using --depth=1 so the commit count will always be 1,
  # no need to run a command for that.
  export_env "GIT_CLONE_COMMIT_COUNT" "1"
}

in_parallel="--jobs=10"
remote_name="origin"

cd "$clone_into_dir"
git init --quiet
git remote add "$remote_name" "$repository_url"

if [ -z "$pull_request_id" ]; then
  # Not a pull request
  if [ -n "$commit" ]; then
    local_ref="$commit"
    remote_ref="$commit"
  elif [ -n "$tag" ]; then
    local_ref="$tag"
    remote_ref="$tag"
  elif [ -n "$branch" ]; then
    local_ref="$remote_name/$branch"
    remote_ref="$branch"
  else
    echo "Missing information about the commit" >&2
    exit
  fi

  git fetch $in_parallel --depth=1 --no-tags "$remote_name" "$remote_ref"

  export_common_commit_details "$local_ref"
  export_non_pr_commit_details "$local_ref"

  git checkout --detach "$local_ref"
else
  # Pull request
  if [ -z "$pull_request_head_branch" ] || [ -z "$branch_dest" ]; then
    echo "Missing information about the pull request" >&2
    exit
  fi

  # We need to fetch the PR destination branch to be able to make diffs.
  git fetch $in_parallel --depth=1 --no-tags "$remote_name" "$branch_dest"
  export_env "GIT_LOCAL_BASE_BRANCH" "$remote_name/$branch_dest"

  local_pr_head_branch="pull/$pull_request_id/head"
  git fetch $in_parallel --depth=1 --no-tags "$remote_name" "refs/$pull_request_head_branch:$local_pr_head_branch"
  pr_branch="$local_pr_head_branch"
  export_env "GIT_LOCAL_HEAD_BRANCH" "$local_pr_head_branch"

  # It seems the Bitrise Git Clone step exports commit details from the PR head branch, not the PR merge branch, so do the same.
  export_common_commit_details "$local_pr_head_branch"

  # Note that the PR head branch and merge branch should be very close,
  # so fetching both should not take much longer than fetching just one.

  if [ -n "$pull_request_merge_branch" ]; then
    # Even we were passed a merge branch name, it might not exist, so ignore errors.
    local_pr_merge_branch="pull/$pull_request_id/merge"
    if git fetch $in_parallel --depth=1 --no-tags "$remote_name" "refs/$pull_request_merge_branch:$local_pr_merge_branch"; then
      pr_head_commit=$(git rev-parse "$local_pr_head_branch")
      pr_merge_commit=$(git rev-parse "$local_pr_merge_branch")
      # Check if the tip of PR merge is a child of the tip of PR head.
      # If it is not, it might be not ready yet, or a merge conflict might have prevented the merge, so do not use it.
      if git cat-file -p "$pr_merge_commit" | grep "^parent ${pr_head_commit}$"; then
        pr_branch="$local_pr_merge_branch"
      else
        echo "It seems the pull request has merge conflicts - using $local_pr_head_branch"
      fi
    fi
  fi

  git checkout --detach "$pr_branch"
fi

if [ "$update_submodules" = "1" ] || [ "$update_submodules" = "true" ] || [ "$update_submodules" = "yes" ]; then
  git submodule update --init --recursive $in_parallel --depth=1
fi
