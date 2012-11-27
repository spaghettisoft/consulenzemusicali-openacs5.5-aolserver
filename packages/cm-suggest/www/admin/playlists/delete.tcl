ad_page_contract {

  @author Antonio Pisano

} {
    playlist_id:integer
}

db_transaction {

    cmit::playlist::delete -playlist_id $playlist_id

}

ad_returnredirect -message "La playlist indicata e' stata cancellata." list
ad_script_abort



