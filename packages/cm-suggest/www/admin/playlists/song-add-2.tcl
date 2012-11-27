ad_page_contract {

  @author Antonio Pisano

} {
    playlist_id:integer
    song_id:integer,multiple
}

db_transaction {
    
    set songs $song_id

    foreach song_id $songs {
	cmit::playlist::add_song -playlist_id $playlist_id -song_id $song_id
    }

}

ad_returnredirect -message "Il brani indicati sono stati aggiunti alla playlist." list
ad_script_abort



