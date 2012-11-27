ad_page_contract {

    @author Claudio Pasolini

} {
    group_id:integer
}


set group_name [_ [string trim [group::title -group_id $group_id] #]]
set page_title "Membri di $group_name"
set context [list [list ../groups/list {Elenco Gruppi}]  "$page_title"]

# prepare actions buttons
set actions [list \
    "Aggiungi membro" [export_vars -base add-edit {group_id}] "Aggiungi un membro a questo gruppo" \
]

template::list::create \
    -name members \
    -multirow members \
    -actions $actions \
    -elements {
	edit {
	    link_url_col edit_url
	    display_template {<img src="/resources/acs-subsite/Edit16.gif" width="16" height="16" border="0">}
	    link_html {title "Modifica Appartenenza"}
	    sub_class narrow
	}
	first_names {
	    label "Nome"
	}
	last_name {
	    label "Cognome"
	}
	email {
	    label "Email"
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
	    link_html {title "Rimuovi questo membro" onClick "return(confirm('Confermi la rimozione?'));"}
	    sub_class narrow
	}
    }

db_multirow -extend {edit_url delete_url} members query "
    select r.rel_id, 
           first_names, 
	   last_name, 
	   u.username as email, 
	   user_id, 
	   valid_from, 
	   valid_to
    from acs_rels r, persons pe, users u, cmit_memberships
    where rel_type      = 'membership_rel' and 
          object_id_one = :group_id and 
          object_id_two = person_id and
          user_id       = person_id
	  
    " {
	set edit_url   [export_vars -base "add-edit" {group_id rel_id}]
	set delete_url [export_vars -base "delete" {group_id user_id}]
	
	set valid_from [lc_time_fmt $valid_from %x]
	set valid_to   [lc_time_fmt $valid_to   %x]
    }
