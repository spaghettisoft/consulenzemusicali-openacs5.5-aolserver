ad_page_contract {

    @author Claudio Pasolini

} {
    {search_valid_from      ""}
    {search_valid_from_ansi ""}    
    {search_valid_to        ""}
    {search_valid_to_ansi   ""}
}

set page_title "Gruppi"
set context [list $page_title]


ad_form -name filter \
    -mode edit \
    -edit_buttons [list [list Ok new]] \
    -has_edit 1 \
    -form {
	{search_valid_from:date,optional
	    {label {Valido da}}
	}
	{search_valid_to:date,optional
	    {label {Valido al}}
	}
} -on_request {
        
} -on_submit {
    
    if {$search_valid_from ne ""} {
	set search_valid_from_ansi [join [lrange $search_valid_from 0 2] -]
    }
    if {$search_valid_to ne ""} {
	set search_valid_to_ansi [join [lrange $search_valid_to 0 2] -]
    }

    set errors_p [expr {![template::form::is_valid filter]}]
    
    if {$errors_p} {
	break
    }
    
}


# prepare actions buttons
set actions {
  "Aggiungi Gruppo" add-edit "Aggiungi un nuovo gruppo"
}

template::list::create \
    -name groups \
    -multirow groups \
    -actions $actions \
    -elements {
	edit {
	    link_url_col edit_url
	    display_template {<img src="/resources/acs-subsite/Edit16.gif" width="16" height="16" border="0">}
	    link_html {title "Modifica Gruppo"}
	    sub_class narrow
	}
	group_name {
	    label "Nome Gruppo"
	}
	members {
	    link_url_col members_url 
            link_html {title "Visualizza i membri di questo gruppo"}
	    display_template {Membri}
	}
	valid_from {
	    label "Valido dal"
	}
	valid_to {
	    label "Valido al"
	}
	delete {
	    link_url_col delete_url 
	    display_template {<img src="/resources/acs-subsite/Delete16.gif" width="16" height="16" border="0">}
	    link_html {title "Rimuovi questo gruppo" onClick "return(confirm('Confermi la rimozione?'));"}
	    sub_class narrow
	}
    }

db_multirow -extend {edit_url members_url delete_url} groups query "
    select g.group_id, 
           o.title as group_name,
	   cg.valid_from,
	   cg.valid_to
    from groups g, cmit_groups cg, acs_objects o
    where cg.group_id = g.group_id and
	  o.object_id = g.group_id and
	  (:search_valid_from_ansi is null or cg.valid_from <= :search_valid_from_ansi) and
	  (:search_valid_to_ansi   is null or cg.valid_to   >= :search_valid_to_ansi)
    order by group_name
    " {
	set edit_url      [export_vars -base "add-edit" {group_id}]
	set members_url   [export_vars -base "../memberships/list" {group_id}]
	set delete_url    [export_vars -base "delete" {group_id}]
	
	# Obtains localized version of the group name
	set group_name [_ [string trim $group_name #]]
	
	set valid_from [lc_time_fmt $valid_from %x]
	set valid_to   [lc_time_fmt $valid_to   %x]
    }
