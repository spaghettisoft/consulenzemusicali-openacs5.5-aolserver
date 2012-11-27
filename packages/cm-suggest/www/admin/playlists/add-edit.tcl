ad_page_contract {

  @author Antonio Pisano

} {
    playlist_id:integer,optional
    
    {mode "edit"}
}


set new_record_p [expr {![info exists playlist_id]}]

if {$new_record_p} {
    set page_title "Inserisci playlist"
    set buttons [list [list "Inserisci" new]]
} else {
    set page_title "Modifica playlist"
    set buttons [list [list "Modifica" new]]
}

set context [list [list list {Elenco Playlist}] $page_title]


set this_url [export_vars -base [ad_conn url] -entire_form -no_empty]


set form {
    {name:text(textarea),nospell
	{label "Nome"} {html {rows 1 cols 80}}
    }
    {description:text(textarea),optional,nospell
	{label "Descrizione"} {html {rows 5 cols 80}}
    }
}

if {!$new_record_p} {
    append form {
	{filename:text(inform)
	    {label "Thumbnail caricata"}
	}
    }
}

append form {
    {file:file(file),optional
	{label "Nuova thumbnail"}
    }
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
    -export {playlist_id} \
    -form $form \
 -on_request {
    
    if {!$new_record_p} {
	cmit::playlist::get -playlist_id $playlist_id -array playlist
	
	set name        $playlist(name)
	set description $playlist(description)
	
	set valid_from_ansi $playlist(valid_from)
	set valid_from [join [split $valid_from_ansi -] " "]
	
	set valid_to_ansi $playlist(valid_to)
	set valid_to [join [split $valid_to_ansi -] " "]
	
	set thumbnail_id $playlist(thumbnail_id)
	if {$thumbnail_id ne ""} {
	    set filename      $playlist(thumbnail_filename)
	    set thumbnail_url $playlist(thumbnail_url)
	    
	    set thumbnail_delete_url [export_vars -base "thumbnail-delete" {playlist_id {return_url $this_url}}]
	    template::element::set_properties addedit filename before_html "
		<img src='$thumbnail_url' height='50'/>
		<a href='$thumbnail_delete_url' title='Elimina questa thumbnail'>
		  <img src='/resources/acs-subsite/Delete16.gif' width='16' height='16' border='0'/>
		</a>"
	}
    }

} -on_submit {
    
    set valid_from_ansi [join [lrange $valid_from 0 2] -]
    set valid_to_ansi   [join [lrange $valid_to   0 2] -]
    
    if {$file ne ""} {
      util_unlist $file filename file.tmpfile mime_type
	  
      if {![regexp ^image/.* $mime_type]} {
	  template::form::set_error addedit file "Il formato del file inviato non è supportato."
      }
    } else {
	set filename ""
	set file.tmpfile ""
    }
    
    if {![template::form::is_valid addedit]} {
	break
    }
    
    if {$new_record_p} {
	db_transaction {
	    set playlist_id [cmit::playlist::add \
		-name                   $name \
		-description            $description \
		-thumbnail_filename     $filename \
		-thumbnail_tmp_filename ${file.tmpfile} \
		-valid_from             $valid_from_ansi \
		-valid_to               $valid_to_ansi]
	}
	ad_returnredirect [export_vars -base song-add {playlist_id}]
    } else {
	db_transaction {
	    cmit::playlist::edit -playlist_id $playlist_id \
		-name                   $name \
		-description            $description \
		-thumbnail_filename     $filename \
		-thumbnail_tmp_filename ${file.tmpfile} \
		-valid_from             $valid_from_ansi \
		-valid_to               $valid_to_ansi
	}
	ad_returnredirect [export_vars -base list {playlist_id}]
    }

} -after_submit {
    ad_script_abort
}
