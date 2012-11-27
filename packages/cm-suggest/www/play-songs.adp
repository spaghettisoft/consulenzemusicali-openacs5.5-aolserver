<master src="/www/blank-master">
<if @doc@ defined><property name="&doc">doc</property></if>

<p><a href='index' title='Torna alle playlist'>Lista Playlist</a></p>
<center>
  <table border='1'>
    <multiple name="songs">
      <tr>
	<td align='center'>
	  <a href='@songs.song_url@' title='Ascolta il brano'>
	    <p>Titolo: @songs.title@</p>
	    <p>Autore: @songs.author@</p>
	  </a>
	</td>
      </tr>
    </multiple>
  </table>
</center>
