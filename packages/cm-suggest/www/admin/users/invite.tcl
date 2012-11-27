ad_page_contract {
    Invite new member.
    
    @author Lars Pind (lars@collaboraid.biz)
    @creation-date 2003-06-02
    @cvs-id $Id: member-invite.tcl,v 1.9 2007/01/10 21:22:09 gustafn Exp $
}

# find the subsite root
array set arr [site_node::get_from_url -url /]

# get the root group for the subsite
set group_id [application_group::group_id_from_package_id -package_id $arr(package_id)]


set page_title "Invite Member to [ad_conn instance_name]"
set context [list [list list "Members"] "Invite"]

group::get \
    -group_id $group_id \
    -array group_info

ad_form -name user_search -cancel_url list -form {
    {user_id:search
        {result_datatype integer}
        {label {Search for user}}
        {help_text {Type part of the name or email of the user you would like to add}}
        {search_query {[db_map user_search]}}
    }
}

ad_form -extend -name user_search -on_submit {
    set create_p [group::permission_p -privilege create $group_id]
    
    if { $group_info(join_policy) eq "closed" && !$create_p} {
        ad_return_forbidden "Cannot invite members" "I'm sorry, but you're not allowed to invite members to this group"
        ad_script_abort
    }

    if { ![group::member_p -user_id $user_id -group_id $group_id] } {
        with_catch errmsg {
            group::add_member \
                -group_id $group_id \
                -user_id $user_id \
                -rel_type $rel_type
        } {
            form set_error user_search user_id "Error adding user to community: $errmsg"
            global errorInfo
            ns_log Error "Error adding user $user_id to community group $group_id: $errmsg\n$errorInfo"
            break
        }
    }
} -after_submit {
    ad_returnredirect list
    ad_script_abort
}


ad_form -action user-new -name user_create -form {
    {email:text
        {label "Email"}
        {help_text "Type the email of the person you would like to add"}
        {html {size 50}}
    }
}
