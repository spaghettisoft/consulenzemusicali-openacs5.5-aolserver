ad_page_contract {

    @author Antonio Pisano

} {
    playlist_id:integer
}

set locale [ad_conn locale]

set playlist_name [category::get_name $playlist_id $locale]

set page_title "Elenco Brani della playlist '$playlist_name'"
set context [list [list list {Elenco Playlist}] $page_title]

# prepare actions buttons
set actions [list \
    "Aggiungi brano" [export_vars -base song-add {playlist_id}] "Aggiungi un brano alla playlist" \
]

template::list::create \
    -name songs \
    -multirow songs \
    -actions $actions \
    -elements {
	edit {
	    link_url_col edit_url
	    display_template {<img src="/resources/acs-subsite/Edit16.gif" width="16" height="16" border="0">}
	    link_html {title "Modifica Playlist"}
	    sub_class narrow
	}
	order_no {
	    label "N°"
	}
	title {
	    label "Titolo"
	}
	author {
	    label "Autore"
	}
	mime_type {
	    label "Tipo file"
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
	    link_html {title "Rimuovi questo brano" onClick "return(confirm('Confermi la rimozione?'));"}
	    sub_class narrow
	}
    }

db_multirow -extend {edit_url delete_url} songs query "
    select s.song_id,
           r.title,
           r.description as author,
           r.mime_type,
           ps.order_no,
           ps.valid_from,
           ps.valid_to
    from cmit_songs s,
         cr_revisions r,
         cmit_playlist_songs ps
    where s.song_id = r.revision_id
      and s.song_id = ps.song_id
      and ps.playlist_id = :playlist_id
  order by ps.order_no, r.description, r.title
  " {
	set edit_url   [export_vars -base "song-edit"   {playlist_id song_id}]
	set delete_url [export_vars -base "song-delete" {playlist_id song_id}]
	
	set valid_from [lc_time_fmt $valid_from %x]
	set valid_to   [lc_time_fmt $valid_to   %x]
    }
