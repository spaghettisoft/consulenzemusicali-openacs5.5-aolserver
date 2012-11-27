ad_page_contract {

  @author Antonio Pisano

} {
    playlist_id:integer
    song_id:integer
    
    {mode "edit"}
}

set locale [ad_conn locale]

set playlist_name [category::get_name $playlist_id $locale]

set page_title "Modifica brano nella playlist $playlist_name"
set buttons [list [list "Modifica" new]]

set context [list [list playlists/list {Elenco Playlist}] [list songs-list?playlist_id=$playlist_id "Elenco Brani Playlist '$playlist_name'"] $page_title]


set form {
    {order_no:integer,optional
	{label "N° ordine"}
	{html {size 3}}
	{help_text "Non cambia se non digitato."}
    }
    {title:text(inform)
	{label "Titolo"}
    }
    {author:text(inform)
	{label "Autore"}
    }
    {valid_from:date,optional
	{label {Valido da}}
    }
    {valid_to:date,optional
	{label {Valido a}}
    }
}

ad_form -name addedit \
    -mode $mode \
    -edit_buttons $buttons \
    -has_edit 1 \
    -export {playlist_id song_id} \
    -form $form \
 -on_request {
    
    cmit::song::get -song_id $song_id -array song
    
    set title  $song(title)
    set author $song(author)
    
    db_1row query "
      select valid_from as valid_from_ansi,
             valid_to   as valid_to_ansi
	  from cmit_playlist_songs
	where playlist_id = :playlist_id
	  and song_id     = :song_id"
    
    set valid_from [join [split $valid_from_ansi -] " "]
    
    set valid_to [join [split $valid_to_ansi -] " "]

} -on_submit {
    
    set valid_from_ansi [join [lrange $valid_from 0 2] -]
    set valid_to_ansi   [join [lrange $valid_to   0 2] -]
    
    if {![template::form::is_valid addedit]} {
	break
    }
    
    db_transaction {
	cmit::playlist::edit_song \
	    -playlist_id $playlist_id \
	    -song_id     $song_id \
	    -valid_from  $valid_from_ansi \
	    -valid_to    $valid_to_ansi \
	    -order_no    $order_no
    }

} -after_submit {
    ad_returnredirect [export_vars -base songs-list {playlist_id}]
    ad_script_abort
}
