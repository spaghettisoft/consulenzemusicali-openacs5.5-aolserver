ad_page_contract {

  @author Antonio Pisano

} {
    song_id:integer,optional
    
    {mode "edit"}
}


set new_record_p [expr {![info exists song_id]}]

if {$new_record_p} {
    set page_title "Inserisci brano"
    set buttons [list [list "Inserisci" new]]
} else {
    set page_title "Modifica brano"
    set buttons [list [list "Modifica" new]]
}

set context [list [list list {Elenco Brani}] $page_title]


set form {
    {title:text(textarea),nospell
	{label "Titolo"} {html {rows 1 cols 80}}
    }
    {author:text(textarea),optional,nospell
	{label "Autore"} {html {rows 1 cols 80}}
    }
}

if {$new_record_p} {
    append form {
	{file:file(file)
	    {label "File Audio"}
	}
    }
} else {
    append form {
	{filename:text(inform)
	    {label "File Audio"}
	}
    }
}

append form {
    {valid_from:date,optional
	{label {Valido da}}
    }
    {valid_to:date,optional
	{label {Valido a}}
    }
}

ad_form -html { enctype multipart/form-data } -name addedit \
    -mode $mode \
    -edit_buttons $buttons \
    -has_edit 1 \
    -export {song_id} \
    -form $form \
 -on_request {
    
    if {!$new_record_p} {
	cmit::song::get -song_id $song_id -array song
	
	set title    $song(title)
	set author   $song(author)
	set filename $song(filename)
	
	set valid_from_ansi $song(valid_from)
	set valid_from [join [split $valid_from_ansi -] " "]
	
	set valid_to_ansi $song(valid_to)
	set valid_to [join [split $valid_to_ansi -] " "]
    }

} -on_submit {
    
    set valid_from_ansi [join [lrange $valid_from 0 2] -]
    set valid_to_ansi   [join [lrange $valid_to   0 2] -]
    
    if {$new_record_p} {
	util_unlist $file filename file.tmpfile mime_type
	
	if {![regexp ^audio/.* $mime_type]} {
	    template::form::set_error addedit file "Il formato del file inviato non è supportato."
	}
    }
    
    if {![template::form::is_valid addedit]} {
	break
    }
    
    if {$new_record_p} {
	db_transaction {
	    set song_id [cmit::song::add \
		-title        $title \
		-author       $author \
		-filename     $filename \
		-tmp_filename ${file.tmpfile} \
		-valid_from   $valid_from_ansi \
		-valid_to     $valid_to_ansi]
	}
	ad_returnredirect [export_vars -base ../permissions {{object_id $song_id}}]
    } else {
	db_transaction {
	    cmit::song::edit -song_id $song_id \
		-title      $title \
		-author     $author \
		-valid_from $valid_from_ansi \
		-valid_to   $valid_to_ansi
	}
	ad_returnredirect [export_vars -base list {song_id}]
    }

} -after_submit {
    ad_script_abort
}
