ad_page_contract {
    Make administrators.
} {
    {user_id:multiple ""}
}

# find the subsite root
array set arr [site_node::get_from_url -url /]

# get the root group for the subsite
set group_id [application_group::group_id_from_package_id -package_id $arr(package_id)]

db_transaction {
    foreach one_user_id $user_id {
        # membership state stuff should only check the membership_rel at this
        # point - remember this is going to be made consistent in 5.1
	relation_add -member_state "" admin_rel $group_id $one_user_id
    }
} on_error {
    ad_return_error "Error creating the relation" "We got the following error message while trying to create this relation: <pre>$errmsg</pre>"
    ad_script_abort
}

ad_returnredirect list
ad_script_abort
