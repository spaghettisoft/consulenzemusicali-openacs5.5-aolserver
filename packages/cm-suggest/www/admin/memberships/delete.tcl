ad_page_contract {

  @author Antonio Pisano

} {
    group_id:integer
    user_id:integer
}

db_transaction {

    cmit::membership::delete -group_id $group_id -member_id $user_id

}

ad_returnredirect [export_vars -base list {group_id}]
ad_script_abort



