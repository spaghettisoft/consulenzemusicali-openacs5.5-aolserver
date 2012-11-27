ad_page_contract {

  @author Antonio Pisano

} {
    playlist_id:integer
    song_id:integer
}

db_transaction {

    cmit::playlist::delete_song -playlist_id $playlist_id -song_id $song_id

}

ad_returnredirect -message "Il brano indicato e' stato rimosso dalla playlist." [export_vars -base songs-list {playlist_id}]
ad_script_abort



