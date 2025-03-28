function fish_jj_prompt
  if ! jj status >/dev/null 2>&1
    return 1
  end

  jj log --color=always -r "@" -T " ' (' ++ change_id.shortest() ++ if(bookmarks, '|' ++ bookmarks.join(' ')) ++ ')'" --no-graph
end
