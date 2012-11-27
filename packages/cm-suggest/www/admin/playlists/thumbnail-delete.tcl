ad_page_contract {

  @author Antonio Pisano

} {
    playlist_id:integer
    return_url
}

db_transaction {
    cmit::playlist::thumbnail_delete -playlist_id $playlist_id
}

ad_returnredirect $return_url
ad_script_abort
