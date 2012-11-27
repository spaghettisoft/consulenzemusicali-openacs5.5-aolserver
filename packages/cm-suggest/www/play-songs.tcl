ad_page_contract {

    @author Antonio Pisano

} {
    playlist_id:integer
}

set user_id [ad_conn user_id]
set locale [ad_conn locale]

set playlist_name [category::get_name $playlist_id $locale]

set page_title "Lista Brani della Playlist '$playlist_name'"
set doc(title) $page_title


# All songs in this playlist this user has access to
db_multirow -extend {
    title
    author
    song_url
} songs query "
  select ps.song_id
  from cmit_playlist_songs ps,
       cmit_songs s
  where ps.playlist_id = :playlist_id
    and ps.song_id     = s.song_id
    and (s.valid_from is null or 
         current_date >= s.valid_from)
    and (s.valid_to is null or 
         current_date <= s.valid_to)
    and (ps.valid_from is null or 
         current_date >= ps.valid_from)
    and (ps.valid_to is null or 
         current_date <= ps.valid_to)
    and acs_permission__permission_p(s.song_id,:user_id,'read')
  order by ps.order_no asc" {
    
    cmit::song::get -song_id $song_id -array song
    set title    $song(title)
    set author   $song(author)
    set song_url $song(url)
}