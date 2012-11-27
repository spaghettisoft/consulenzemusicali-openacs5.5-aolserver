ad_library {
    User manipulation procedures
    @author Antonio Pisano
}

namespace eval cmit {}



#
### Users procs
#

namespace eval cmit::user {}

ad_proc -public cmit::user::change_state {
    -user_id:required
    -member_state:required
} {
    Change the state of a user
} {
    # find the subsite root
    array set arr [site_node::get_from_url -url /]
    
    # get the root group for the subsite
    set subsite_group_id [application_group::group_id_from_package_id -package_id $arr(package_id)]
    
    # get user membership to the main subsite
    set rel_id [db_string query "
      select rel_id from acs_rels
    where object_id_one = :subsite_group_id
      and object_id_two = :user_id"]
    
    membership_rel::change_state \
	-rel_id $rel_id \
	-state  $member_state
    
    # if approved, the user becomes also a cmit_user...
    if {$member_state eq "approved"} {
	db_dml query "insert into cmit_users values (:user_id)"
    # ...otherwise it is removed from them
    } else {
	db_dml query "delete from cmit_users where user_id = :user_id"
    }
}


ad_proc -public cmit::user::delete {
    -user_id:required
} {
    Deletes a user
} {
    # remove the user from the cmit_users
    db_dml query "delete from cmit_users where user_id = :user_id"
    
    # I try to erase permanently the user from the system...
    if {[catch {acs_user::delete -user_id $user_id -permanent}]} {
	# ...but it could fail. In that case we just disable it.
	acs_user::delete -user_id $user_id
    }
}



#
### Groups procs
#

namespace eval cmit::group {}
 
ad_proc -public cmit::group::get {
    -group_id:required
    -array:required
} {
    Returns group datas
} {
    upvar $array row
    db_1row query "
      select g.group_id,
             o.title as group_name,
             g.description as group_description,
             cg.valid_from,
             cg.valid_to
	from groups g, cmit_groups cg, acs_objects o
            where g.group_id   = :group_id
	      and cg.group_id  = :group_id
	      and o.object_id = :group_id
    " -column_array row
    set row(group_name) [_ [string trim $row(group_name) #]]
}

ad_proc -public cmit::group::add {
    -group_name:required
    {-valid_from        ""}
    {-valid_to          ""}
} {
    Adds a new group
} {
    # find the subsite root
    array set arr [site_node::get_from_url -url /]
    
    set context_id $arr(package_id)
    
    # add group
    set group_id [group::new \
	-group_name $group_name \
	-context_id $context_id \
	"application_group"]
    
    # The proc for creating a group translates its name with key 'group_title_${group_id}',
    # while the update procs uses 'group_title.${group_id}'. This is bad... 
    # I force an update after the group creation to fix it.
    lang::message::unregister "acs-translations" "group_title_${group_id}"
    
    # update OpenAcs group datas
    set gdatas(group_name) $group_name
    group::update -group_id $group_id -array gdatas
    
    # get the root group for the subsite
    set subsite_group_id [application_group::group_id_from_package_id -package_id $context_id]
    
    relation_add composition_rel $subsite_group_id $group_id
       
    # save expiration date of the group
    db_dml query "
      insert into cmit_groups (
	   group_id
	  ,valid_from
	  ,valid_to
	) values (
	   :group_id
	  ,:valid_from
	  ,:valid_to
	)"
    
    
    return $group_id
}

ad_proc -public cmit::group::edit {
    -group_id:required
    {-group_name ""}
    -valid_from
    -valid_to
} {
    Edits a group
} { 
    cmit::group::get -group_id $group_id -array group
    
    set group_name [string trim $group_name]
    if {$group_name eq ""} {
	set group_name $group(group_name)
    }
    if {![info exists valid_from]} {
	set valid_from $group(valid_from)
    }
    if {![info exists valid_from]} {
	set valid_to $group(valid_to)
    }
    
    # update OpenAcs group datas
    set gdatas(group_name) $group_name
    group::update -group_id $group_id -array gdatas
    
    # save expiration date of the group
    db_dml query "
      update cmit_groups set
	   valid_from = :valid_from
	  ,valid_to   = :valid_to
	where group_id = :group_id"
}

ad_proc -public cmit::group::delete {
    -group_id:required
} {
    Deletes a group
} { 
    # delete the group
    db_dml query "delete from cmit_groups where group_id = :group_id"
    lang::message::unregister "acs-translations" "group_title.${group_id}"
    group::delete $group_id
}



#
### Membership procs
#

namespace eval cmit::membership {}

ad_proc -public cmit::membership::get {
    -membership_id:required
    -array:required
} {
    Gets a membership
} { 
    upvar $array row
    db_1row query "
      select m.*,
             r.object_id_one as group_id,
	     r.object_id_two as member_id
	from cmit_memberships m,
	     acs_rels r
    where r.rel_id = m.membership_id
      and membership_id = :membership_id
    " -column_array row
}

ad_proc -public cmit::membership::add {
    -group_id:required
    -member_id:required
    {-valid_from ""}
    {-valid_to   ""}
} {
    Adds a user to a group
} { 
    # create membership relationship
    set rel_id [relation_add -member_state approved membership_rel $group_id $member_id]
    
    db_dml query "
      insert into cmit_memberships (
	    membership_id
	   ,valid_from
	   ,valid_to
	  ) values (
	    :rel_id
	   ,:valid_from
	   ,:valid_to
	  )"
    
    return $rel_id
}

ad_proc -public cmit::membership::edit {
    -membership_id:required
    -member_id
    -valid_from
    -valid_to
} {
    Edits a membership
} {
    cmit::membership::get -membership_id $membership_id -array membership
    
    foreach var [array names membership] {
	if {![info exists $var]} {
	    set $var $membership($var)
	}
    }
    
    db_dml query "
      update cmit_memberships set
	  valid_from = :valid_from,
	  valid_to   = :valid_to
	where membership_id = :membership_id;
      
      update acs_rels set
	  object_id_two = :member_id
	where rel_id = :membership_id"
}

ad_proc -public cmit::membership::delete {
    {-membership_id ""}
    {-group_id      ""}
    {-member_id     ""}
} {
    Deletes a member from a group
} {
    # all the relationships between user and group...
    if {$membership_id eq ""} {
      if {$group_id eq "" || $member_id eq ""} {
	  return
      }
      set rels [db_list query "
	select rel_id from acs_rels 
      where object_id_one = :group_id 
	and object_id_two = :member_id"]
    # ...or a single membership
    } else {
	set rels $membership_id
	db_1row query "
	  select object_id_one as group_id,
	         object_id_two as member_id
	      from acs_rels
	    where rel_id = :membership_id"
    }
    
    foreach rel_id $rels {
	db_dml query "
	  delete from party_approved_member_map 
	where member_id = :member_id 
	  and tag       = :rel_id;
    
	  delete from cmit_memberships
	where membership_id = :rel_id"
    }

    group::remove_member \
        -group_id $group_id \
        -user_id  $member_id
}