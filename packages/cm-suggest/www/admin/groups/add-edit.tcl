ad_page_contract {

  @author Antonio Pisano

} {
    {group_id ""}
}


set new_record_p [expr {$group_id eq ""}]

if {!$new_record_p} {
    set page_title "Modifica Gruppo"
} else {
    set page_title "Crea Gruppo"
}

set context [list [list list {Elenco gruppi}] $page_title]


ad_form -name addedit \
    -edit_buttons [list [list "$page_title" new]] \
    -export group_id \
    -has_edit 1 \
    -form {

	{group_name:text
	    {label {Nome Gruppo}}
	}
	{valid_from:date,optional
	    {label {Valido da}}
	}
	{valid_to:date,optional
	    {label {Valido a}}
	}

} -on_request {

    if {!$new_record_p} {
        cmit::group::get -group_id $group_id -array group
	
	set group_name $group(group_name)
	set valid_from $group(valid_from)
	if {$valid_from ne ""} {
	    util_unlist [split $valid_from -] year month day
	    set valid_from "$year $month $day"
	}
	set valid_to $group(valid_to)
	if {$valid_to ne ""} {
	    util_unlist [split $valid_to -] year month day
	    set valid_to "$year $month $day"
	}
    }

} -on_submit {
    
    set group_name [string trim $group_name]
    if {$group_name eq ""} {
	template::form::set_error addedit group_name "E' necessario fornire un nome per il gruppo."
    }
    
    if {$valid_from ne ""} {
	set valid_from_ansi [join [lrange $valid_from 0 2] -]
    } else {
	set valid_from_ansi ""
    }
    if {$valid_to ne ""} {
	set valid_to_ansi [join [lrange $valid_to 0 2] -]
    } else {
	set valid_to_ansi ""
    }
    
    if {![template::form::is_valid addedit]} {
	break
    }
    

    if {$new_record_p} {

	db_transaction {
	    
	    cmit::group::add \
		-group_name $group_name \
		-valid_from $valid_from_ansi \
		-valid_to   $valid_to_ansi

	}

    } else {

	db_transaction {

	    cmit::group::edit -group_id $group_id \
		-group_name $group_name \
		-valid_from $valid_from_ansi \
		-valid_to   $valid_to_ansi

	}

    }

} -after_submit {
    ad_returnredirect "list"
    ad_script_abort
}




