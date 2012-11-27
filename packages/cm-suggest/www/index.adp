<master src="/www/blank-master">
<if @doc@ defined><property name="&doc">doc</property></if>

<center>
  <table border='1'>
    <if @n_playlists@ gt 0>
      <multiple name="playlists">
	<tr>
	  <td align='center'>
	    <img src='@playlists.thumbnail@' width='70' border='0'/>
	  </td>
	  <td align='center'>
	    <a href='@playlists.songs_url@' title='Ascolta la playlist'>
	      <p>@playlists.name@</p>
	      <p>@playlists.description@</p>
	      <if @playlists.n_songs@ ne 0>
		<p>@playlists.n_songs@ <if @playlists.n_songs@ gt 1>brani</if><else>brano</else></p>
	      </if>
	      <else>
		<p>Playlist vuota</p>
	      </else>
	    </a>
	  </td>
	</tr>
      </multiple>
    </if>
    <else>
      <tr><td><p>Nessuna playlist</p></td></tr>
    </else>
  </table>
</center>
