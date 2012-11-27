ad_page_contract {

    @author Antonio Pisano

} {
    playlist_id:integer
}

set locale [ad_conn locale]

set playlist_name [category::get_name $playlist_id $locale]

set page_title "Aggiungi un brano alla playlist $playlist_name"
set context [list [list playlists/list {Elenco Playlist}] [list songs-list?playlist_id=$playlist_id "Elenco Brani Playlist '$playlist_name'"] $page_title]

set bulk_actions {
    "Aggiungi brani" song-add-2 "Aggiungi i brani selezionati alla playlist"
}

# prepare actions buttons
template::list::create \
    -name songs \
    -multirow songs \
    -key song_id \
    -bulk_action_export_vars {playlist_id} \
    -bulk_actions $bulk_actions \
    -elements {
	sel {
	    display_template {@songs.sel;noquote@}
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
    }

db_multirow -extend {sel} songs query "
    select s.song_id,
           r.title,
           r.description as author,
           r.mime_type,
           s.valid_from,
           s.valid_to
    from cmit_songs s,
         cr_revisions r
    where s.song_id = r.revision_id
      and not exists (select 1 from cmit_playlist_songs where song_id = s.song_id and playlist_id = :playlist_id)
  " {
	set sel_url [export_vars -base "song-add-2" {playlist_id song_id}]
	set sel "<a href='$sel_url' title='Aggiungi brano alla playlist'>Aggiungi</a>"
	
	set valid_from [lc_time_fmt $valid_from %x]
	set valid_to   [lc_time_fmt $valid_to   %x]
    }
