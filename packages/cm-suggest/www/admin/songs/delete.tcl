ad_page_contract {

  @author Antonio Pisano

} {
    song_id:integer
}

db_transaction {

    cmit::song::delete -song_id $song_id

}

ad_returnredirect -message "Il brano indicato e' stato cancellato." list
ad_script_abort



