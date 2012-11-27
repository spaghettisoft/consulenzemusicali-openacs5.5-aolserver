ad_page_contract {
    Permissions for a folder

    @author Jeff Davis <davis@xarg.net>
    @creation-date 2005-03-05
    @cvs-id $Id: permissions.tcl,v 1.2 2005/05/26 08:28:46 maltes Exp $
} {
    {object_id:integer}
}

set package_key [ad_conn package_key]

set playlist_p [db_0or1row query "
  select 1 from cmit_playlists 
where playlist_id = :object_id"]

if {$playlist_p} {
    set locale [ad_conn locale]
    set playlist_name [category::get_name $object_id $locale]
    set page_title "Permessi sulla playlist '$playlist_name'"
    set context [list [list playlists/list {Elenco Playlist}] $page_title]
# If not a playlist, it must be a song
} {
    cmit::song::get -song_id $object_id -array song
    set title  $song(title)
    set author $song(author)
    set page_title "Permessi sul brano '$title' di '$author'"
    set context [list [list songs/list {Elenco Brani}] $page_title]
}