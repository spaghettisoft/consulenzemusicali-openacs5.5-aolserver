ad_page_contract {

    Changes the member state of a user

} {
    user_id:integer
    {member_state ""}
}


db_transaction {
    
    cmit::user::change_state -user_id $user_id -member_state $member_state
    
}

ad_returnredirect list
ad_script_abort