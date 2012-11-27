ad_page_contract {

    @author Antonio Pisano

} {
}

set locale [ad_conn locale]


set page_title "Elenco Brani"
set context [list "$page_title"]

# prepare actions buttons
set actions [list \
    "Aggiungi brano" add-edit "Aggiungi un brano" \
]

set line_actions [list \
    <a href='../permissions?object_id=@songs.song_id@' title='Gestisci permessi'>Permessi</a> \
]

template::list::create \
    -name songs \
    -multirow songs \
    -actions $actions \
    -elements {
	edit {
	    link_url_col edit_url
	    display_template {<img src="/resources/acs-subsite/Edit16.gif" width="16" height="16" border="0">}
	    link_html {title "Modifica Brano"}
	    sub_class narrow
	}
	author {
	    label "Autore"
	}
	title {
	    label "Titolo"
	}
	mime_type {
	    label "Tipo file"
	}
	playlists {
	    label "Playlist"
	    display_template {@songs.playlists;noquote@}
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
	    link_html {title "Rimuovi questo brano" onClick "return(confirm('Confermi la rimozione?'));"}
	    sub_class narrow
	}
    }

db_multirow -extend {edit_url playlists delete_url} songs query "
    select s.song_id,
           r.title,
           r.description as author,
           r.mime_type,
           s.valid_from,
           s.valid_to
    from cmit_songs s,
         cr_revisions r
    where s.song_id = r.revision_id
  order by author asc, title asc
  " {
	set edit_url   [export_vars -base "add-edit" {song_id}]
	set delete_url [export_vars -base "delete" {song_id}]
	
	set playlists ""
	foreach playlist_id [cmit::song::get_playlists -song_id $song_id] {
	    set playlist_url [export_vars -base ../playlists/add-edit {playlist_id}]
	    set playlist_name [category::get_name $playlist_id $locale]
	    append playlists " <a href='$playlist_url' title='Visualizza playlist'>$playlist_name</a>"
	}
	
	set valid_from [lc_time_fmt $valid_from %x]
	set valid_to   [lc_time_fmt $valid_to   %x]
    }
