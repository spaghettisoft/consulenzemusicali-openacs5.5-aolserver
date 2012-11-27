ad_page_contract {

    @author Antonio Pisano

} {
}

set locale [ad_conn locale]


set page_title "Elenco Playlist"
set context [list "$page_title"]

# prepare actions buttons
set actions [list \
    "Aggiungi playlist" add-edit "Aggiungi una playlist" \
]

set line_actions [list \
    <a href='songs-list?playlist_id=@playlists.playlist_id@' title='Brani nella playlist'>Brani</a> \
    <a href='../permissions?object_id=@playlists.playlist_id@' title='Gestisci permessi'>Permessi</a> \
]

template::list::create \
    -name playlists \
    -multirow playlists \
    -actions $actions \
    -elements {
	edit {
	    link_url_col edit_url
	    display_template {<img src="/resources/acs-subsite/Edit16.gif" width="16" height="16" border="0">}
	    link_html {title "Modifica Playlist"}
	    sub_class narrow
	}
	thumbnail {
	    label "Copertina"
	    display_template {
	      <if @playlists.thumbnail@ ne "">
		<img src="@playlists.thumbnail@" width="70" border="0">
	      </if>
	    }
	}
	name {
	    label "Nome"
	}
	description {
	    label "Descrizione"
	}
	valid_from {
	    label "Valido dal"
	}
	valid_to {
	    label "Valido al"
	}
	line_actions {
	    label "Azioni"
	    display_template $line_actions
	}
	delete {
	    link_url_col delete_url 
	    display_template {<img src="/resources/acs-subsite/Delete16.gif" width="16" height="16" border="0">}
	    link_html {title "Rimuovi questa playlist" onClick "return(confirm('Confermi la rimozione?'));"}
	    sub_class narrow
	}
    }

db_multirow -extend {
    edit_url 
    name 
    upper_name
    description
    thumbnail
    upper_description
    valid_from
    valid_to
    songs_url
    delete_url
} playlists query "
    select p.playlist_id
    from cmit_playlists p
    where 1 = 1
  " {
	set edit_url   [export_vars -base "add-edit" {playlist_id}]
	set songs_url  [export_vars -base "songs-list" {playlist_id}]
	set delete_url [export_vars -base "delete" {playlist_id}]
	
	cmit::playlist::get -playlist_id $playlist_id -locale $locale -array playlist
	foreach var [array names playlist] {
	    set $var $playlist($var)
	}
	
	if {[info exists thumbnail_url]} {
	    set thumbnail $thumbnail_url
	}
	
	set valid_from [lc_time_fmt $valid_from %x]
	set valid_to   [lc_time_fmt $valid_to   %x]
	
	set upper_name [string toupper $name]
	set upper_description [string toupper $description]
    }

template::multirow sort playlists upper_name upper_description