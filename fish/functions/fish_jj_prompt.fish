function fish_jj_prompt
  # make sure jj is installed
  if ! command -sq jj
    return 1
  end
  # check if we're in a jj repo
  if ! jj root --quiet &>/dev/null
    return 1
  end

  if test -n "$__fish_jj_prompt_bookmark_revset"
    set prompt_bookmark_revset "$__fish_jj_prompt_bookmark_revset"
  else
    set prompt_bookmark_revset "@ | @-"
  end

  set current_head (jj log --color=always --no-graph \
    -r "@" -T "change_id.shortest()")
  set current_branch (jj log --color=always --no-graph \
    -r "latest(($prompt_bookmark_revset) & bookmarks())" \
    -T "local_bookmarks.join(' ')")
  if test -n "$current_branch"
    echo " ($current_head|$current_branch)"
  else
    echo " ($current_head)"
  end
end
