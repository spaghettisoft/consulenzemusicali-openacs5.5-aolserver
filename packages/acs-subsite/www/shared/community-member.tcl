ad_page_contract {
    shows User A what User B has contributed to the community
    
    @param user_id defaults to currently logged in user if there is one
    @cvs-id $Id: community-member.tcl,v 1.15 2009/01/06 02:25:34 gustafn Exp $
} {
    {user_id:integer ""}
} -properties {
    context:onevalue
    member_state:onevalue
    first_names:onevalue
    last_name:onevalue
    email:onevalue
    inline_portrait_state:onevalue
    portrait_export_vars:onevalue
    width:onevalue
    height:onevalue
    system_name:onevalue
    pretty_creation_date:onevalue
    show_email_p:onevalue
    url:onevalue
    bio:onevalue
    verified_user_id:onevalue
    subsite_url:onevalue
}


set subsite_url [subsite::get_element -element url]

#See if this page has been overrided by a parameter in kernel 
set community_member_url [parameter::get -package_id [ad_acs_kernel_id] -parameter CommunityMemberURL -default "/shared/community-member"]
if { $community_member_url ne "/shared/community-member" } {
    ad_returnredirect "$community_member_url?user_id=$user_id"
    ad_script_abort
}

set site_wide_admin_p [acs_user::site_wide_admin_p]
set admin_user_url [acs_community_member_admin_url -user_id $user_id]

set verified_user_id [ad_conn user_id]
set untrusted_user_id [ad_conn untrusted_user_id]

if { $user_id eq "" } {
    if { $verified_user_id == 0 } {
	# Don't know what to do! 
	ad_return_error "Missing user_id" "We need a user_id to display the community page"
	return
    }
    set user_id $verified_user_id
}

set bind_vars [ad_tcl_vars_to_ns_set user_id]

    
if { ![db_0or1row user_information "select first_names, last_name, email, priv_email, url, creation_date, member_state from cc_users where user_id = :user_id" -bind $bind_vars]} {
    
    ad_return_error "No user found" "There is no community member with the user_id of $user_id"
    ns_log Notice "Could not find user_id $user_id in community-member.tcl from [ad_conn peeraddr]"
    return
}

# Here the email_image is created according to the priv_email
# field in the users table

set email_image "<p><b>\#acs-subsite.E_mail\#:</b>&nbsp;[email_image::get_user_email -user_id $user_id]</p>"


if { $url ne "" && ![string match -nocase "http://*" $url] } {
    set url "http://$url"
}

set bio [ad_text_to_html -- [person::get_bio -person_id $user_id]]

# Do we show the portrait?
set inline_portrait_state "none"
set portrait_export_vars [export_url_vars user_id]

if {[db_0or1row portrait_info "
select i.width, i.height, cr.title, cr.description, cr.publish_date
from acs_rels a, cr_items c, cr_revisions cr, images i
where a.object_id_two = c.item_id
and c.live_revision = cr.revision_id
and cr.revision_id = i.image_id
and a.object_id_one = :user_id
and a.rel_type = 'user_portrait_rel'"]} {
    # We have a portrait. Let's see if we can show it inline


    if { $width ne "" && $width < 300 } {
	# let's show it inline
	set inline_portrait_state "inline"
    } else {
	set inline_portrait_state "link"
    }
}


if { $priv_email <= [ad_privacy_threshold] } {
    set show_email_p 1
} else {
    set show_email_p 0
    # guy doesn't want his email address shown, but we can still put out 
    # the home page
}

set page_title "$first_names $last_name"
set context [list "Community Member"]
set system_name [ad_system_name]
set pretty_creation_date [lc_time_fmt $creation_date "%q"]
set login_export_vars "return_url=[ns_urlencode [acs_community_member_url -user_id $user_id]]"

set login_url [export_vars -base "/register/." { { return_url [ad_return_url]} }]

ad_return_template
