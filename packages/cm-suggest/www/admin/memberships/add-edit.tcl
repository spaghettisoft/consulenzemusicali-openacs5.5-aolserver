ad_page_contract {

  @author Claudio Pasolini

} {
    group_id:integer
    
    rel_id:optional
    
    {mode "edit"}
}

set group_name [_ [string trim [group::title -group_id $group_id] #]]


set new_record_p [expr {![info exists rel_id]}]

if {$new_record_p} {
    set page_title "Aggiungi membro di $group_name"
    set buttons [list [list "Inserisci" new]]
} else {
    set page_title "Modifica membro di $group_name"
    set buttons [list [list "Modifica" new]]
}

set context [list [list ../groups/list {Elenco Gruppi}] [list list?group_id=$group_id {Membri}] $page_title]


ad_form -name addedit \
    -mode $mode \
    -edit_buttons $buttons \
    -has_edit 1 \
    -export {group_id rel_id} \
    -form {

	{member_id:integer(select)
	    {options { {"Scegli ..." ""} [db_list_of_lists query "
            select first_names || ' ' || last_name || ' - ' || username, person_id
            from persons p, cmit_users cu, users u
	    where person_id > 0 
	      and person_id = cu.user_id
	      and u.user_id = cu.user_id
            order by last_name, first_names
            "] }}
	    {label {Scegli utente}}
	}
	{valid_from:date,optional
	    {label {Valido da}}
	}
	{valid_to:date,optional
	    {label {Valido a}}
	}
	
} -on_request {
    
    if {!$new_record_p} {
	cmit::membership::get -membership_id $rel_id -array membership
	
	set member_id $membership(member_id)
	
	set valid_from_ansi $membership(valid_from)
	set valid_from [join [split $valid_from_ansi -] " "]
	
	set valid_to_ansi $membership(valid_to)
	set valid_to [join [split $valid_to_ansi -] " "]
    }

} -on_submit {
    
    set valid_from_ansi [join [lrange $valid_from 0 2] -]
    set valid_to_ansi   [join [lrange $valid_to   0 2] -]

    if {$new_record_p} {
	db_transaction {
	    cmit::membership::add \
		-group_id   $group_id \
		-member_id  $member_id \
		-valid_from $valid_from_ansi \
		-valid_to   $valid_to_ansi
	}
    } else {
	db_transaction {
	    cmit::membership::edit -membership_id $rel_id \
		-member_id  $member_id \
		-valid_from $valid_from_ansi \
		-valid_to   $valid_to_ansi
	}
    }

} -after_submit {
    ad_returnredirect [export_vars -base list {group_id}]
    ad_script_abort
}
