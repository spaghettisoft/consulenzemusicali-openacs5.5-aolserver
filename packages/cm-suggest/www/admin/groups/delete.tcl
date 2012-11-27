ad_page_contract {

    @author Antonio Pisano

} {
    group_id:integer,notnull
}

db_transaction {
    cmit::group::delete -group_id $group_id
}

ad_returnredirect -message "Il gruppo indicato è stato cancellato" "list"
ad_script_abort
