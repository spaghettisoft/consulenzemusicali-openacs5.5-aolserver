ad_page_contract {

    @author Antonio Pisano

} {
}

set user_id [ad_conn user_id]

set page_title "Lista Playlist"
set doc(title) $page_title

# All playlists this user has access to
db_multirow -extend {
    name
    description
    thumbnail
    n_songs
    songs_url
} playlists query "
  select playlist_id
  from cmit_playlists
  where (valid_from is null or 
         current_date >= valid_from)
    and (valid_to is null or 
         current_date <= valid_to)
    and acs_permission__permission_p(playlist_id,:user_id,'read')" {
    
    cmit::playlist::get -playlist_id $playlist_id -array playlist
    set name        $playlist(name)
    set description $playlist(description)
    
    set thumbnail_id $playlist(thumbnail_id)
    if {$thumbnail_id ne ""} {
	set thumbnail $playlist(thumbnail_url)
    }
    
    set n_songs [db_string query "
      select count(*) from cmit_playlist_songs
    where playlist_id = :playlist_id"]
    
    set songs_url [export_vars -base "play-songs" {playlist_id}]
}

set n_playlists [template::multirow size playlists]