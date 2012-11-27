ad_page_contract {
    List and manage subsite members.
   
    @author Lars Pind (lars@collaboraid.biz), Antonio Pisano
} {
    {member_state "approved"}
    {orderby "name,asc"}
    
    {search_name    ""}
    {search_email   ""}
    {search_party   ""}
    
    page:optional
} -validate {
    member_state_valid -requires { member_state } {
        if { [lsearch [group::possible_member_states] $member_state] == -1 } {
            ad_complain "Invalid member_state"
        }
    }
}

set page_title [_ acs-subsite.Members]
set context [list $page_title]


set user_id [ad_conn user_id]


# find the subsite root
array set arr [site_node::get_from_url -url /]

# get the root group for the subsite
set group_id [application_group::group_id_from_package_id -package_id $arr(package_id)]


ad_form \
    -name filter \
    -edit_buttons [list [list "Go" go]] \
    -form {
	{search_name:text,optional
	    {label {Nome}}
	    {value $search_name}
	}
	{search_email:text,optional
	    {label {Email}}
	    {value $search_email}
	}
    } -on_request {

    } -on_submit {

	set errnum 0

	if {$errnum > 0} {
	    break
	} else {
	    # per evitare errori nell'esecuzione della query la eseguirò solo se 'errnum' non esiste
	    unset errnum
	}
    }


set actions [_ acs-subsite.Invite]
lappend actions { invite }

set bulk_actions {}


set member_state_options [list]

db_foreach select_member_states "
    select mr.member_state as state, 
               count(mr.rel_id) as num_members
        from   membership_rels mr, acs_rels r
        where  r.rel_id = mr.rel_id
          and  r.object_id_one = :group_id
          and  r.rel_type = 'membership_rel'
	  and  r.object_id_two <> [ad_conn user_id]
        group  by mr.member_state" {

    lappend member_state_options \
        [list \
             [group::get_member_state_pretty -member_state $state] \
             $state \
             [lc_numeric $num_members]]
}

set member_state_clause "mr.member_state = :member_state"


db_1row pretty_roles "
  select admin_role.pretty_name as admin_role_pretty,
         member_role.pretty_name as member_role_pretty
     from acs_rel_roles admin_role, acs_rel_roles member_role
   where admin_role.role = 'admin'
         and member_role.role = 'member'"

template::list::create \
    -name "members" \
    -multirow "members" \
    -row_pretty_plural "members" \
    -page_size 50 \
    -page_flush_p t \
    -page_query {
	select r.rel_id, 
               u.first_names || ' ' || u.last_name as name
	from   acs_rels r,
	      membership_rels mr,
	      cc_users u
	where  r.object_id_one = :group_id
	and    r.rel_type = 'membership_rel'
	and    mr.rel_id = r.rel_id
	and    u.user_id = r.object_id_two
	[template::list::filter_where_clauses -and -name "members"]
	[template::list::orderby_clause -orderby -name "members"]
    } \
    -actions $actions \
    -bulk_actions $bulk_actions \
    -elements {
        name {
            label "[_ acs-subsite.Name]"
            link_url_eval {[acs_community_member_url -user_id $user_id]}
        }
        email {
           label "[_ acs-subsite.Email]"
	    display_template {
		@members.user_email;noquote@
	    }
        }
        rel_role {
            label "[_ acs-subsite.Role]"
            display_template {
                @members.rel_role_pretty@
            }
        }
        member_state_pretty {
            label "[_ acs-subsite.Member_State]"
        }
        member_state_change {
            label {Action}
            display_template {
                <if @members.approve_url@ not nil>
                  <a href="@members.approve_url@">#acs-subsite.Approve#</a>
                </if>
                <if @members.reject_url@ not nil>
                  <a href="@members.reject_url@">#acs-subsite.Reject#</a>
                </if>
                <if @members.ban_url@ not nil>
                  <a href="@members.ban_url@">#acs-subsite.Ban#</a>
                </if>
                <if @members.delete_url@ not nil>
                  <a href="@members.delete_url@">#acs-subsite.Delete#</a>
                </if>
                <if @members.make_admin_url@ not nil>
                  <a href="@members.make_admin_url@">#acs-subsite.Make_administrator#</a>
                </if>
                <if @members.make_member_url@ not nil>
                  <a href="@members.make_member_url@">#acs-subsite.Make_member#</a>
                </if>
            }
        }
    } -filters {
        member_state {
            label "[_ acs-subsite.Member_State]"
            values $member_state_options
            where_clause {$member_state_clause}
            has_default_p 1
        }
        search_name {
            hide_p 1
            where_clause {(:search_name is null or upper(u.first_names || ' ' || u.last_name) like upper('%' || :search_name || '%'))}
        }
        search_email {
            hide_p 1
            where_clause {(:search_email is null or upper(u.username) like upper('%' || :search_email || '%'))}
        }
    } -orderby {
        name {
            label "[_ acs-subsite.Name]"
            orderby "lower(u.first_names || ' ' || u.last_name)"
        }
        email {
            label "[_ acs-subsite.Email]"
            orderby "u.email"
        }
    }


# Pull out all the relations of the specified type

db_multirow -extend { 
    email_url
    member_state_pretty
    remove_url
    approve_url
    reject_url
    ban_url
    delete_url
    make_admin_url
    make_member_url
    rel_role_pretty
    user_email
} -unclobber members members_select "
    select u.user_id,
           u.first_names || ' ' || u.last_name as name,
           u.email,
           mr.member_state
    from   acs_rels r,
           membership_rels mr,
           cc_users u
    where  r.object_id_one = :group_id
    and    mr.rel_id = r.rel_id
    and    r.rel_id = mr.rel_id
    and    u.user_id = r.object_id_two
    and    r.object_id_two <> [ad_conn user_id]
    [template::list::filter_where_clauses -and -name members]
    [template::list::page_where_clause -and -name members -key r.rel_id]
    [template::list::orderby_clause -orderby -name members]
" {
    set site_wide_admin_p [acs_user::site_wide_admin_p -user_id $user_id]
    
    set member_admin_p [expr {
      $site_wide_admin_p || [db_0or1row query "
      select 1 from rel_segment_party_map
    where rel_type = 'admin_rel'
      and group_id = :group_id
      and party_id = :user_id limit 1"]}]
    
    if {!$member_admin_p} {
	set other_role_pretty [db_string query "
	  select distinct r.pretty_name 
            from acs_rel_roles r, rel_segment_party_map m, acs_rel_types t
            where m.group_id = :group_id
            and t.rel_type = m.rel_type
            and m.rel_type <> 'admin_rel'
            and m.rel_type <> 'membership_rel'
            and r.role = t.role_two
            and m.party_id = :user_id
	" -default ""]
    }
    
    if {$member_admin_p} {
        set rel_role_pretty [lang::util::localize $admin_role_pretty]
    } else {
        if {$other_role_pretty ne ""} {
            set rel_role_pretty [lang::util::localize $other_role_pretty]
        } else {
            set rel_role_pretty [lang::util::localize $member_role_pretty]
        }
    }
    
    set member_state_pretty [group::get_member_state_pretty -member_state $member_state]
    set user_email [email_image::get_user_email -user_id $user_id]
    
    switch $member_state {
	"approved" {
	    if { !$member_admin_p } {
		set make_admin_url [export_vars -base make-admin { user_id }]
	    } elseif { !$site_wide_admin_p } {
		set make_member_url [export_vars -base make-member { user_id }]
	    }
	    set ban_url [export_vars -base change-state { user_id {member_state banned} }]
	}
	"needs approval" {
	    set approve_url [export_vars -base change-state { user_id { member_state approved } }]
	    set reject_url [export_vars -base change-state { user_id {member_state rejected} }]
	}
	"rejected" - "deleted" - "banned" {
	    set approve_url [export_vars -base change-state { user_id { member_state approved } }]
	    set delete_url [export_vars -base delete {user_id}]
	}
    }

    set email_url "mailto:$email"
}

