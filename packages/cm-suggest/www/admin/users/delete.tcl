ad_page_contract {

    @author Antonio Pisano

} {
    user_id:integer
}

db_transaction {
    cmit::user::delete -user_id $user_id
}

ad_returnredirect -message "L'utente indicato e' stato cancellato." "list"
ad_script_abort
