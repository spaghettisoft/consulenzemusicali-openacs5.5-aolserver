<if @show_p@ true>
  <div class="developer-support-footer">
    <if @errcount@ gt 0>
      <p style="color: red">errors: @errcount@ <a href="@ds_url@send?output=@request@:error">view</a></p>
    </if>
    <if @comments:rowcount@ gt 0>
      <multiple name="comments">
        <b>Comment:</b> <pre style="display: inline;">@comments.text@</pre><br>
      </multiple>
      <hr>
    </if>
    <if @user_switching_p@ true>
      <form action="@set_user_url@">
        @export_vars;noquote@
        Real user: @real_user_name@ (@real_user_email@) [user_id #@real_user_id@]<br>
        <if @real_user_id@ ne @fake_user_id@>      
          Faked user: @fake_user_name@ <if @fake_user_email@ not nil>(@fake_user_email@)</if> [user_id #@fake_user_id@] <a href="@unfake_url@">(Unfake)</a><br>
        </if>
        <else>
          Faked user: <i>Not faking.</i><br>
        </else>
        Change faked user: <if @search_p@ eq "0"><select name="user_id">
          <multiple name="users">
            <option value="@users.user_id@" <if @users.selected_p@>selected</if>>@users.name@ <if @users.email@ not nil>(@users.email@)</if></option>
          </multiple>
        </select></if><else><input type="text" name="keyword"><input type="hidden" name="target" value="@target@"></else>
        <input type="submit" value="Go">
      </form>
      <hr>
    </if>
    <if @profiling:rowcount@ gt 0>
      <h3>Profiling Information</h3>
      <listtemplate name="profiling"></listtemplate>
      <if @page_fragment_cache_p@ true>
        <p>
          <form name="searchfrags" action="@ds_url@search">
            <input type="hidden" name="request" value="@request@">
            <input type="text" name="expression" value="">
            <input type="submit" name="search" value="Search">
          </form>
        </p></if>

    </if>
  </div>
</if>
