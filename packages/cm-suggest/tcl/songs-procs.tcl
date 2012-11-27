ad_library {
    Song and playlist manipulation procedures
    @author Antonio Pisano
}

namespace eval cmit {}



#
### Songs procs
#

namespace eval cmit::song {}

ad_proc -public cmit::song::get {
    -song_id:required
    -array:required
} {
    Gets song datas
} {
    upvar $array row
    db_1row query "
      select *
	  from cmit_songs s
	where song_id = :song_id
    " -column_array row
    # Get datas from the file linked to this song
    util::fs::get_file -revision_id $song_id -array file
    set row(title)     $file(title)
    set row(author)    $file(description)
    set row(filename)  $file(name)
    set row(size)      $file(content_size)
    set row(mime_type) $file(mime_type)
    set row(url)       $file(url)
}

ad_proc -public cmit::song::add {
    -author:required
    -title:required
    -filename:required
    -tmp_filename:required
    {-valid_from ""}
    {-valid_to   ""}
} {
    Adds a song to the system
} {
    set song_id [util::fs::add_file \
	-name         $filename \
	-title        $title \
	-description  $author \
	-tmp_filename $tmp_filename]
    
    # Prevent this object from inheriting permissions
    permission::set_not_inherit -object_id $song_id
    
    db_dml query "
      insert into cmit_songs (
	     song_id
	    ,valid_from
	    ,valid_to
	    ) values (
	     :song_id
	    ,:valid_from
	    ,:valid_to
	    )"
    
    return $song_id
}

ad_proc -public cmit::song::edit {
    -song_id:required
    -title
    -author
    -valid_from
    -valid_to
} {
    Edits a song in the system
} {
    cmit::song::get -song_id $song_id -array song
    
    if {![info exists title]} {
	set title $song(title)
    }
    if {![info exists description]} {
	set author $song(author)
    }
    if {![info exists valid_from]} {
	set valid_from $song(valid_from)
    }
    if {![info exists valid_to]} {
	set valid_to $song(valid_to)
    }
    
    db_dml query "
      update cr_revisions set
	   title       = :title
	  ,description = :author
	where revision_id = :song_id"
    
    db_dml query "
      update cmit_songs set
	 valid_from = :valid_from,
	 valid_to   = :valid_to
	where song_id = :song_id"
}

ad_proc -public cmit::song::delete {
    -song_id:required
} {
    Deletes a song in the system
} {
    foreach playlist_id [db_list query "
      select playlist_id from cmit_playlist_songs
    where song_id = :song_id"] {
	cmit::playlist::delete_song -playlist_id $playlist_id -song_id $song_id
    }
    
    db_dml query "
      delete from cmit_songs
    where song_id = :song_id"
    
    set file_id [db_string query "
      select item_id from cr_revisions
    where revision_id = :song_id"]
    
    fs::delete_version -item_id $file_id -version_id $song_id
}

ad_proc -public cmit::song::get_playlists {
    -song_id:required
} {
    Gets playlists which contain this song
} {
    set playlists [category::get_mapped_categories $song_id]
    if {[llength $playlists] > 0} {
	set playlists [db_list query "
	  select playlist_id from cmit_playlists
	where playlist_id in ([join $playlists ,])"]
    }
    
    return $playlists
}



#
### Playlists procs
#

namespace eval cmit::playlist {}
 
ad_proc -public cmit::playlist::get {
    -playlist_id:required
    -array:required
    {-locale ""}
} {
    Returns playlist datas
} {
    if {$locale eq ""} {
	set locale [ad_conn locale]
    }
    
    upvar $array row
        
    db_1row query "
      select * from cmit_playlists
    where playlist_id = :playlist_id" -column_array row
    
    set row(name) [category::get_name $playlist_id $locale]
    
    set row(description) [db_string query "
      select description
	  from category_translations
	where category_id = :playlist_id
	  and locale      = :locale" \
    -default [db_string query "
      select description
	  from category_translations
	where category_id = :playlist_id
	  and locale      = 'en_US'"]]

    set thumbnail_id $row(thumbnail_id)
    
    if {$thumbnail_id ne ""} {
	# Get datas from the file linked to this song
	util::fs::get_file -revision_id $thumbnail_id -array file
	set row(thumbnail_filename)  $file(name)
	set row(thumbnail_size)      $file(content_size)
	set row(thumbnail_mime_type) $file(mime_type)
	set row(thumbnail_url)       $file(url)
    }
}

ad_proc -public cmit::playlist::add {
    -name:required
    {-description ""}
    {-thumbnail_filename ""}
    {-thumbnail_tmp_filename ""}
    {-valid_from  ""}
    {-valid_to    ""}
    {-locale      ""}
} {
    Adds a new playlist
} {
    if {$locale eq ""} {
	set locale [ad_conn locale]
    }
    
    # If a thumbnail had been specified...
    if {$thumbnail_filename ne ""} {
      # ...which file exists...
      if {[file exists $thumbnail_tmp_filename]} {
	# ...put thumbnail into file storage.
	set thumbnail_id [util::fs::add_file \
	    -name         $thumbnail_filename \
	    -title        "Playlist $name thumbnail" \
	    -description  "Playlist $name thumbnail: $description" \
	    -tmp_filename $thumbnail_tmp_filename]
      }
    # ...else we have no file.
    } else {
	set thumbnail_id ""
    }
    
    set package_id [apm_package_id_from_key "cm-suggest"]

    set tree_id [category_tree::get_id "cm-playlists-$package_id"]
    
    set playlist_id [category::add \
	-tree_id     $tree_id \
	-parent_id   "" \
	-name        $name \
	-description $description \
	-locale      $locale]
    
    permission::set_not_inherit -object_id $playlist_id
    
    db_dml query "
      insert into cmit_playlists (
	     playlist_id
	    ,thumbnail_id
	    ,valid_from
	    ,valid_to
	    ) values (
	     :playlist_id
	    ,:thumbnail_id
	    ,:valid_from
	    ,:valid_to
	    )"    
    
    
    return $playlist_id
}

ad_proc -public cmit::playlist::edit {
    -playlist_id:required
    -name
    -description
    -thumbnail_filename
    -thumbnail_tmp_filename
    -valid_from
    -valid_to
    {-locale ""}
} {
    Edits a playlist
} {
    if {$locale eq ""} {
	set locale [ad_conn locale]
    }
    
    cmit::playlist::get -playlist_id $playlist_id -array playlist

    if {![info exists name]} {
	set name $playlist(name)
    }
    if {![info exists description]} {
	set description $playlist(description)
    }    
    if {![info exists valid_from]} {
	set valid_from $playlist(valid_from)
    }
    if {![info exists valid_to]} {
	set valid_to $playlist(valid_to)
    }
    
    set thumbnail_id $playlist(thumbnail_id)
    
    # If a thumbnail had been specified...
    if {$thumbnail_filename ne ""} {
      # ...which file exists...
      if {[file exists $thumbnail_tmp_filename]} {
	# ...if we have one we delete it.
	cmit::playlist::thumbnail_delete -playlist_id $playlist_id
	
	# Then we add the thumbnail to the file storage.
	set thumbnail_id [util::fs::add_file \
	  -name         $thumbnail_filename \
	  -title        "Playlist $name thumbnail" \
	  -description  "Playlist $name thumbnail: $description" \
	  -tmp_filename $thumbnail_tmp_filename]
      }
    }
    
    category::update -category_id $playlist_id \
	-name        $name \
	-locale      $locale \
	-description $description
    
    db_dml query "
      update cmit_playlists set
	   thumbnail_id = :thumbnail_id
	  ,valid_from   = :valid_from
	  ,valid_to     = :valid_to
	where playlist_id = :playlist_id"
}

ad_proc -public cmit::playlist::thumbnail_delete {
    -playlist_id:required
} {
    Deletes a playlist's thumbnail
} { 
    # Delete thumbnail reference in playlist
    db_dml query "
      update cmit_playlists set
	  thumbnail_id = null
	where playlist_id = :playlist_id"
    
    # Delete thumbnail_id
    set thumbnail_id [db_string query "
      select thumbnail_id from cmit_playlists
    where playlist_id = :playlist_id"]
    
    if {$thumbnail_id ne ""} {
	set file_id [db_string query "
	  select item_id from cr_revisions
	where revision_id = :thumbnail_id"]
	
	fs::delete_version -item_id $file_id -version_id $thumbnail_id
    }
}

ad_proc -public cmit::playlist::delete {
    -playlist_id:required
} {
    Deletes a playlist
} { 
    foreach song_id [db_list query "
      select song_id from cmit_playlist_songs
    where playlist_id = :playlist_id"] {
	cmit::playlist::delete_song -playlist_id $playlist_id -song_id $song_id
    }

    db_dml query "
      delete from cmit_playlists
    where playlist_id = :playlist_id"
    
    cmit::playlist::thumbnail_delete -playlist_id $playlist_id
    
    set tree_id [category::get_tree $playlist_id]
    
    category::delete $playlist_id
    
    category_tree::flush_cache $tree_id
}

ad_proc -public cmit::playlist::get_songs_not_cached {
    -playlist_id:required
} {
    Gets songs into a playlist
} { 
    return [util_memoize [list cmit::playlist::get_songs_not_cached -playlist_id $playlist_id]]
}

ad_proc -public cmit::playlist::get_songs_not_cached {
    -playlist_id:required
} {
    Gets songs into a playlist
} { 
    set songs [category::get_objects -category_id $playlist_id]
    if {$songs != ""} {
	set songs [join $songs ,]
	set songs [db_list query "
	  select song_id from cmit_songs
	where song_id in ($songs)"]
    }
    
    return $songs
}

ad_proc -public cmit::playlist::add_song {
    -playlist_id:required
    -song_id:required
    {-valid_from ""}
    {-valid_to   ""}
} {
    Adds a song to a playlist
} { 
    category::map_object -object_id $song_id $playlist_id
    
    db_dml query "
	insert into cmit_playlist_songs (
	       playlist_id
	      ,song_id
	      ,valid_from
	      ,valid_to
	      ,order_no
	    ) values (
	       :playlist_id
	      ,:song_id
	      ,:valid_from
	      ,:valid_to
	      ,(select coalesce(max(order_no), 0) + 1
		  from cmit_playlist_songs
		where playlist_id = :playlist_id)
	    )
    "
}

ad_proc -public cmit::playlist::edit_song {
    -playlist_id:required
    -song_id:required
    {-order_no ""}
    -valid_from
    -valid_to
} {
    Edits a song into a playlist
} { 
    db_1row query "
      select * from cmit_playlist_songs
      where playlist_id = :playlist_id
	and song_id     = :song_id
      " -column_array row
    
    if {![info exists valid_from]} {
	set valid_from $row(valid_from)
    }
    if {![info exists valid_to]} {
	set valid_to $row(valid_to)
    }
    
    # If an order is given...
    if {$order_no ne ""} {
	# ...it is set to the next max order if greater than that...
	set max_order_no [db_string query "
	  select coalesce(max(order_no), 0)
	    from cmit_playlist_songs
	  where playlist_id = :playlist_id"]
	if {$order_no > $max_order_no} {
	    set order_no $max_order_no
	}
	
	# ...then we move all songs ordered >= than this downward
	db_dml query "
	  update cmit_playlist_songs set
	       order_no = order_no + 1
	    where playlist_id = :playlist_id
	      and order_no > :order_no;
	  
	  update cmit_playlist_songs set
	       order_no = order_no - 1
	    where playlist_id = :playlist_id
	      and order_no = :order_no"
    } else {
	# ...else it's just the old order.
	set order_no $row(order_no)
    }
    
    db_dml query "
      update cmit_playlist_songs set
	     valid_from = :valid_from
	    ,valid_to   = :valid_to
	    ,order_no   = :order_no
	where playlist_id = :playlist_id
	  and song_id     = :song_id"
}

ad_proc -public cmit::playlist::delete_song {
    -playlist_id:required
    -song_id:required
} {
    Removes a song from a playlist
} {
    # First I update the ordering, setting
    # that all rows down this, should move upward 1
    db_dml query "
      update cmit_playlist_songs set
	   order_no = order_no - 1
	where playlist_id = :playlist_id
	  and order_no > (
	    select order_no from cmit_playlist_songs
	      where playlist_id = :playlist_id
	        and song_id     = :song_id);
	    
      delete from cmit_playlist_songs
    where playlist_id = :playlist_id
      and song_id     = :song_id;
      
      delete from category_object_map
    where object_id   = :song_id
      and category_id = :playlist_id"
}