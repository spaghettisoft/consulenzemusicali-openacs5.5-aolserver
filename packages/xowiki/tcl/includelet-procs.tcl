ad_library {
    XoWiki - define various kind of includelets

    @creation-date 2006-10-10
    @author Gustaf Neumann
    @cvs-id $Id: includelet-procs.tcl,v 1.77 2008/11/11 12:25:35 gustafn Exp $
}
namespace eval ::xowiki::includelet {
  #
  # Define a meta-class for creating Includelet classes.
  # We use a meta-class for making it easier to define properties
  # on classes of includelets, which can be used without instantiating
  # it. One can for example use the query from the page fragment 
  # cache the caching properties of the class.
  #
  Class create ::xowiki::IncludeletClass \
      -superclass ::xotcl::Class \
      -parameter {
        {localized true} 
        {personalized true} 
        {cacheable false} 
        {aggregating false}
      }

  # The general superclass for includelets

  Class create ::xowiki::Includelet \
      -superclass ::xo::Context \
      -parameter {
        {name ""} 
        {title ""} 
        {__decoration "portlet"} 
        {parameter_declaration {}}
        {id}
      }

  ::xowiki::Includelet proc require_YUI_CSS {{-version 2.6.0} {-ajaxhelper true} path} {
    if {$ajaxhelper} {
      ::xo::Page requireCSS "/resources/ajaxhelper/yui/$path"
    } else {
      ::xo::Page requireCSS "http://yui.yahooapis.com/$version/build/$path"
    }
  }

  ::xowiki::Includelet proc require_YUI_JS {{-version 2.6.0} {-ajaxhelper true} path} {
    if {$ajaxhelper} {
      ::xo::Page requireJS "/resources/ajaxhelper/yui/$path"
    } else {
      ::xo::Page requireJS "http://yui.yahooapis.com/$version/build/$path"
    }
  }    
    
  ::xowiki::Includelet proc describe_includelets {includelet_classes} {
    my log "--plc=$includelet_classes "
    foreach cl $includelet_classes {
      set result ""
      append result "{{<b>[namespace tail $cl]</b>"
      foreach p [$cl info parameter] {
        if {[llength $p] != 2} continue
        foreach {name value} $p break
        if {$name eq "parameter_declaration"} {
          foreach pp $value {
            #append result ""
            switch [llength $pp] {
              1 {append result " $pp"}
              2 {
                set v [lindex $pp 1]
                if {$v eq ""} {set v {""}}
                append result " [lindex $pp 0] <em>$v</em>"
              }
            }
            #append result "\n"
          }
        }
      }
      append result "}}\n"
      my set html([namespace tail $cl]) $result
      my describe_includelets [$cl info subclass]
    }
  }
  ::xowiki::Includelet proc available_includelets {} {
    if {[my array exists html]} {my array unset html}
    my describe_includelets [::xowiki::Includelet info subclass]
    set result "<UL>"
    foreach d [lsort [my array names html]] {
      append result "<LI>" [my set html($d)] "</LI>" \n
    }
    append result "</UL>"
    return $result
  }

  ::xowiki::Includelet proc html_to_text {string} {
    return [string map [list "&amp;" &] $string]
  }

  ::xowiki::Includelet proc js_name {name} {
    return [string map [list : _ # _] $name]
  }
  
  ::xowiki::Includelet proc html_id {name} {
    # Construct a valid HTML id or name. 
    # For details, see http://www.w3.org/TR/html4/types.html
    #
    # For XOTcl object names, strip first the colons
    set name [string trimleft $name :]
    
    # make sure, the ID starts with characters
    if {![regexp {^[A-Za-z]} $name]} {
      set name id_$name
    }

    # replace unwanted characters
    regsub -all {[^A-Za-z0-9_:.-]} $name _ name
    return $name
  }

  ::xowiki::Includelet proc detail_link {
     {-absolute:boolean false} 
     -package_id 
     -name 
     -instance_attributes
   } {
    array set __ia $instance_attributes
    if {[info exists __ia(detail_link)] && $__ia(detail_link) ne ""} {
      set link $__ia(detail_link)
    } else {
      set link [::$package_id pretty_link $name]
    }
    return $link
  }

  ::xowiki::Includelet proc incr_page_order {p} {
    regexp {^(.*[.]?)([^.])$} $p _ prefix suffix
    if {[string is integer -strict $suffix]} {
      incr suffix
    } elseif {[string is lower -strict $suffix]} {
      regexp {^(.*)(.)$} $suffix _ before last
      if {$last eq "z"} {
	set last "aa"
      } else {
	set last [format %c [expr {[scan $last %c] + 1}]]
      }
      set suffix $before$last
    } elseif {[string is upper -strict $suffix]} {
      regexp {^(.*)(.)$} $suffix _ before last
      if {$last eq "Z"} {
	set last "AA"
      } else {
	set last [format %c [expr {[scan $last %c] + 1}]]
      }
      set suffix $before$last
    }
    return $prefix$suffix
  }

  ::xowiki::Includelet proc publish_status_clause {{-base_table ci} value} {
    if {$value eq "all"} {
      # legacy
      set publish_status_clause ""
    } else {
      array set valid_state [list production 1 ready 1 life 1 expired 1]
      set clauses [list]
      foreach state [split $value |] {
        if {![info exists valid_state($state)]} {
          error "no such state: '$state'; valid states are: production, ready, life, expired"
        }
        lappend clauses "$base_table.publish_status='$state'"
      }
      set publish_status_clause " and ([join $clauses { or }])"
    }
    return $publish_status_clause
  }

  ::xowiki::Includelet proc locale_clause {
    -revisions 
    -items 
    package_id 
    locale
  } {
    set default_locale [$package_id default_locale]
    set system_locale ""

    set with_system_locale [regexp {(.*)[+]system} $locale _ locale]
    if {$locale eq "default"} {
      set locale $default_locale
      set include_system_locale 0
    }
    #my msg "--L with_system_locale=$with_system_locale, locale=$locale, default_locale=$default_locale"

    set locale_clause ""    
    if {$locale ne ""} {
      set locale_clause " and $revisions.nls_language = '$locale'" 
      if {$with_system_locale} {
        set system_locale [lang::system::locale -package_id $package_id]
        #my msg "system_locale=$system_locale, default_locale=$default_locale"
        if {$system_locale ne $default_locale} {
          set locale_clause " and ($revisions.nls_language = '$locale' 
		or $revisions.nls_language = '$system_locale' and not exists
		  (select 1 from cr_items i where i.name = '[string range $locale 0 1]:' || 
		  substring($items.name,4) and i.parent_id = $items.parent_id))"
        }
      } 
    }

    #my msg "--locale $locale, def=$default_locale sys=$system_locale, cl=$locale_clause locale_clause=$locale_clause"
    return [list $locale $locale_clause]
  }

  ::xowiki::Includelet instproc category_clause {category_spec {item_ref p.item_id}} {
    # the category_spec has the syntax "a,b,c|d,e", where the values are category_ids
    # pipe symbols are or-operations, commas are and-operations;
    # no parenthesis are permitted
    set extra_where_clause ""
    set or_names [list]
    set ors [list]
    foreach cid_or [split $category_spec |] {
      set ands [list]
      set and_names [list]
      foreach cid_and [split $cid_or ,] {
        lappend and_names [::category::get_name $cid_and]
        lappend ands "exists (select 1 from category_object_map \
           where object_id = $item_ref and category_id = $cid_and)"
      }
      lappend or_names "[join $and_names { and }]"
      lappend ors "([join $ands { and }])"
    }
    set cnames "[join $or_names { or }]"
    set extra_where_clause "and ([join $ors { or }])"
    #my log "--cnames $category_spec -> $cnames"
    return [list $cnames $extra_where_clause]
  }



  ::xowiki::Includelet instproc resolve_page_name {page_name} {
    return [[my set __including_page] resolve_included_page_name $page_name]
  }  

  ::xowiki::Includelet instproc get_page_order {-source -ordered_pages -pages} {
    my instvar page_order pages ordered_pages
    # 
    # first check, if we can load the page_order from the page
    # denoted by source
    #
    if {[info exists source]} {
      set p [my resolve_page_name $source]
      if {$p ne ""} {
	array set ia [$p set instance_attributes]
	if {[info exists ia(pages)]} {
	  set pages $ia(pages)
	} elseif {[info exists ia(ordered_pages)]} {
	  set ordered_pages $ia(ordered_pages)
	}
      }
    }
    
    # compute a list of ordered_pages from pages, if necessary
    if {[info exists ordered_pages]} {
      foreach {order page} $ordered_pages {set page_order($page) $order}
    } else {
      set i 0
      foreach page $pages {set page_order($page) [incr i]}
    }
  }

  ::xowiki::Includelet instproc include_head_entries {} {
    # The purpose of this method is to contain all calls to include
    # CSS files, javascript, etc. in the HTML Head. This kind of
    # requirements could as well be included e.g. in render, but this
    # won't work, if "render" is cached.  This method is called before
    # render to be executed even when render is not due to caching.
    # It is intended to be overloaded by subclasses.
  }

  ::xowiki::Includelet instproc initialize {} {
    # This method is called at a time after init and before render.
    # It can be used to alter specified parameter from the user,
    # or to influence the rendering of a decoration (e.g. title etc.)
  }
  
  ::xowiki::Includelet instproc js_name {} {
    return [[self class] js_name [self]]
  }

  ::xowiki::Includelet instproc screen_name {user_id} {
    acs_user::get -user_id $user_id -array user
    return [expr {$user(screen_name) ne "" ? $user(screen_name) : $user(name)}]
  }  
}

namespace eval ::xowiki::includelet {
  #############################################################################
  ::xowiki::IncludeletClass create available-includelets \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "The following includelets can be used in a page"}
      }

  available-includelets instproc render {} {
    my get_parameters
    return [::xowiki::Includelet available_includelets]
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # Page Fragment Cache
  # 
  # The following mixin-class implements page fragment caching in the
  # xowiki-cache. Caching can be turned on for every
  # ::xowiki::IncludeletClass instance.
  #
  # Fragment caching depends in the class variables
  #   - cacheable    (the mixin is only registered, when cacheable is set to true)
  #   - aggregating  (requires flusing when items are added/edited/deleted)
  #   - localized    (dependency on locale)
  #   - personalized (dependency on userid)
  #
  Class create ::xowiki::includelet::page_fragment_cache  -instproc render {} {
    set c [my info class]
    #
    # Construct a key based on the class parameters and the 
    # actual parameters
    #
    set key "PF-[my package_id]-"
    append key [expr {[$c aggregating] ? "agg" : "ind"}]
    append key "-$c [my set __caller_parameters]"
    if {[$c localized]}    {append key -[my locale]}
    if {[$c personalized]} {append key -[::xo::cc user_id]}
    set HTML [ns_cache eval xowiki_cache $key next]
    if {[catch {set data [ns_cache get xowiki_cache $key-data]}]} {
      my cache_includelet_data $key-data
    } else {
      #my msg "eval $data"
      eval $data
    }
    return $HTML
  } -instproc cache_includelet_data {key} {
    #my msg "data=[next]"
    set data [next]
    if {$data ne ""} {ns_cache set xowiki_cache $key $data}
  }
}  
namespace eval ::xowiki::includelet {
  #############################################################################
  # dotlrn style includelet decoration for includelets
  #
  Class create ::xowiki::includelet::decoration=portlet -instproc render {} {
    my instvar package_id name title
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    set html [next]
    set localized_title [::xo::localize $title]
    set link [expr {[string match "*:*" $name] ? 
                    "<a href='[$package_id pretty_link $name]'>$localized_title</a>" : 
                    $localized_title}]
    ::xo::render_localizer
    return [subst [[self class] set template]]
  } -set template [expr {[apm_version_names_compare [ad_acs_version] 5.3.0] == 1 ? 
       {<div class='$class'><div class='portlet-wrapper'><div class='portlet-header'>
	 <div class='portlet-title-no-controls'>$link</div></div>
	 <div $id class='portlet'>$html</div></div></div>
       } : {<div class='$class'><div class='portlet-title'><span>$link</span></div>
        <div $id class='portlet'>[next]</div></div>}
       }]

  Class create ::xowiki::includelet::decoration=edit -instproc render {} {
    my instvar package_id name title
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    set html [next]
    set localized_title [::xo::localize $title]
    set edit_button [my include [list edit-item-button -book_mode true]]
    set link [expr {[string match "*:*" $name] ? 
                    "<a href='[$package_id pretty_link $name]'>$localized_title</a>" : 
                    $localized_title}]
    return [subst [[self class] set template]]
  } -set template {<div class='$class'><div class='portlet-wrapper'><div class='portlet-header'>
    <div><div style='float:right;'>$edit_button</div></div></div>
    <div $id class='portlet'>$html</div></div></div>
  }

  Class create ::xowiki::includelet::decoration=plain -instproc render {} {
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    return "<div $id class='$class'>[next]</div>"
  }

  Class create ::xowiki::includelet::decoration=rightbox -instproc render {} {
    set class [namespace tail [my info class]]
    set id [expr {[my exists id] ? "id='[my id]'" : ""}]
    return "<div class='rightbox'><div $id class='$class'>[next]</div></div>"
  }
}

namespace eval ::xowiki::includelet {

  ::xowiki::IncludeletClass create get \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-variable}
          {-form_variable}
          {-source ""}
        }}
      } -instproc render {} {
        my get_parameters
        if {![info exists variable] && ![info exists form_variable]} {
          return "either -variable or -form_variable must be specified"
        }
        set page [my resolve_page_name $source]

        if {[info exists variable] && [$page exists $variable]} {
          return [$page set $variable]
        } 
        if {[info exists form_variable] && [$page exists instance_attributes]} {
          array set __ia [$page set instance_attributes]
          if {[info exists __ia($form_variable)]} {
            return $__ia($form_variable)
          }
        }
        if {[info exists variable]} {
          return "no such variable $variable defined in page [$page set name]"
        }
        return "no such form_variable $form_variable defined in page [$page set name]"
      }
 
  ::xowiki::IncludeletClass create creation-date \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-source ""}
          {-format "%m-%d-%Y"}
        }}
      } -instproc render {} {
        my get_parameters
        set page [my resolve_page_name $source]
        set time [$page set creation_date]
        regexp {^([^.]+)[.]} $time _ time
        return [lc_time_fmt [clock format [clock scan $time] -format "%Y-%m-%d %H:%M:%S"] $format [my locale]]
        #return [clock format [clock scan $time] -format $format]
      }

  #############################################################################
  # rss button
  #
  ::xowiki::IncludeletClass create rss-button \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-span "10d"}
          {-name_filter}
          {-entries_of}
          {-title}
        }}
      }

  rss-button instproc render {} {
    my get_parameters
    set href [export_vars -base [$package_id package_url] {{rss $span} name_filter title entries_of}]
    regsub -all & $href "&amp;" href
    ::xo::Page requireLink -rel alternate -type application/rss+xml -title RSS -href $href
    return "<a href=\"$href \" class='rss'>RSS</a>"
  }

  #############################################################################
  # bookmarklet button
  #
  ::xowiki::IncludeletClass create bookmarklet-button \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-siteurl ""}
          {-label ""}
        }}
      }

  bookmarklet-button instproc render {} {
    my get_parameters
    set url [$package_id pretty_link -absolute 1 -siteurl $siteurl news-item]
    if {$label eq ""} {set label "Add to [$package_id instance_name]"}
    set href [subst -nocommands -nobackslash {
      javascript:d=document;w=window;t='';
      if(d.selection){t=d.selection.createRange().text} else 
      if(d.getSelection){t=d.getSelection()} else 
      if(w.getSelection){t=w.getSelection()} 
      void(open('$url?m=create-new&title='+escape(d.title)+
                    '&detail_link='+escape(d.location.href)+'&text='+escape(t),'_blank',
                    'scrollbars=yes,width=700,height=575,status=yes,resizable=yes,scrollbars=yes'))
    }]
    regsub -all {[\n ]+} $href " " href
    regsub -all & $href "&amp;" href
    return "<a href=\"$href \" title='$label' class='rss'>$label</a>"
  }

  #############################################################################
  # set-parameter "includelet"
  #
  ::xowiki::IncludeletClass create set-parameter \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}}

  set-parameter instproc render {} {
    my get_parameters
    set pl [my set __caller_parameters]
    if {[llength $pl] % 2 == 1} {
      error "no even number of parameters '$pl'"
    }
    foreach {att value} $pl {
      ::xo::cc set_parameter $att $value
    }
    return ""
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  # valid parameters for he categories includelet are
  #     tree_name: match pattern, if specified displays only the trees 
  #                with matching names
  #     no_tree_name: if specified, tree names are not displayed
  #     open_page: name (e.g. en:iMacs) of the page to be opened initially
  #     tree_style: boolean, default: true, display based on mktree

  ::xowiki::IncludeletClass create categories \
      -superclass ::xowiki::Includelet \
      -cacheable true -personalized false -aggregating true \
      -parameter {
        {title "#xowiki.categories#"}
        {parameter_declaration {
          {-tree_name ""}
          {-tree_style:boolean 1}
          {-no_tree_name:boolean 0}
          {-count:boolean 0}
          {-summary:boolean 0}
          {-locale ""}
          {-open_page ""}
          {-order_items_by "title,asc"}
          {-category_ids ""}
          {-except_category_ids ""}
          {-ordered_composite}
        }}
      }

  
  categories instproc render {} {
    my get_parameters

    set content ""
    set folder_id [$package_id folder_id]
    set open_item_id [expr {$open_page ne "" ?
                [::xo::db::CrClass lookup -name $open_page -parent_id $folder_id] : 0}]

    foreach {locale locale_clause} \
        [::xowiki::Includelet locale_clause -revisions r -items ci $package_id $locale] break

    set trees [::xowiki::Category get_mapped_trees -object_id $package_id -locale $locale \
                   -names $tree_name \
                   -output {tree_id tree_name}]

    #my msg "[llength $trees] == 0 && $tree_name"
    if {[llength $trees] == 0 && $tree_name ne ""} {
      # we have nothing left from mapped trees, maybe the tree_names are not mapped; 
      # try to get these
      foreach name $tree_name {
        #lappend trees [list [lindex [category_tree::get_id $tree_name $locale] 0]  $name]
        lappend trees [list [lindex [category_tree::get_id $tree_name] 0] $name]
      }
    }

    if {[llength $trees] == 0} {
      my log "No mapped category tree found\n\
	(mapped trees = [llength $trees],\n\
	tree_name = '$tree_name')"
      return ""
    }

    foreach tree $trees {
      foreach {tree_id my_tree_name ...} $tree {break}
      if {!$no_tree_name} {
        append content "<h3>$my_tree_name</h3>"
      }
      set categories [list]
      set pos 0
      set cattree(0) [::xowiki::CatTree new -volatile -orderby pos -name $my_tree_name]
      set category_infos [::xowiki::Category get_category_infos -locale $locale -tree_id $tree_id]

      foreach category_info $category_infos {
        foreach {cid category_label deprecated_p level} $category_info {break}
        
        set c [::xowiki::Category new -orderby pos -category_id $cid -package_id $package_id \
                   -level $level -label $category_label -pos [incr pos]]
        set cattree($level) $c
        set plevel [expr {$level -1}]
        $cattree($plevel) add $c
        set category($cid) $c
        lappend categories $cid
      }

      if {[info exists ordered_composite]} {
        set items [list]
        foreach c [$ordered_composite children] {lappend items [$c item_id]}
        if {[llength $items]<1} {set items -4711}

        if {$count} {
          set sql "category_object_map c
             where c.object_id in ([join $items ,]) "
        } else {
          # TODO: the non-count-part for the ordered_composite is not
          # tested yet. Although "ordered compostite" can be used
          # only programmatically for now, the code below should be
          # tested. It would be as well possible to obtain titles and
          # names etc. from the ordered composite, resulting in a
          # faster SQL like above.
          set sql "category_object_map c, cr_items ci, cr_revisions r
            where c.object_id in ([join $items ,])
              and c.object_id = ci.item_id and 
              and r.revision_id = ci.live_revision 
           "
        }
      } else {
        set sql "category_object_map c, cr_items ci, cr_revisions r, xowiki_page p \
		where c.object_id = ci.item_id and ci.parent_id = $folder_id \
		and ci.content_type not in ('::xowiki::PageTemplate') \
		and c.category_id in ([join $categories ,]) \
		and r.revision_id = ci.live_revision \
		and p.page_id = r.revision_id \
                and ci.publish_status <> 'production'"
      }

      if {$except_category_ids ne ""} {
        append sql \
            " and not exists (select * from category_object_map c2 \
		where ci.item_id = c2.object_id \
		and c2.category_id in ($except_category_ids))"
      }
      #ns_log notice "--c category_ids=$category_ids"
      if {$category_ids ne ""} {
        foreach cid [split $category_ids ,] {
          append sql " and exists (select * from category_object_map \
	where object_id = ci.item_id and category_id = $cid)"
        }
      }
      append sql $locale_clause
      
      if {$count} {
        db_foreach [my qn get_counts] \
            "select count(*) as nr,category_id from $sql group by category_id" {
              $category($category_id) set count $nr
              set s [expr {$summary ? "&summary=$summary" : ""}]
              $category($category_id) href [ad_conn url]?category_id=$category_id$s
              $category($category_id) open_tree
	  }
        append content [$cattree(0) render -tree_style $tree_style]
      } else {
        foreach {orderby direction} [split $order_items_by ,]  break     ;# e.g. "title,asc"
        set increasing [expr {$direction ne "desc"}]
	set order_column ", p.page_order" 

        db_foreach [my qn get_pages] \
            "select ci.item_id, ci.name, r.title, category_id $order_column from $sql" {
              if {$title eq ""} {set title $name}
              set itemobj [Object new]
              set prefix ""
              set suffix ""
              foreach var {name title prefix suffix page_order} {$itemobj set $var [set $var]}
              
              $cattree(0) add_to_category \
                  -category $category($category_id) \
                  -itemobj $itemobj \
                  -orderby $orderby \
                  -increasing $increasing \
                  -open_item [expr {$item_id == $open_item_id}]
            }
        append content [$cattree(0) render -tree_style $tree_style]
      }
    }
    return $content
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # display recent entries by categories
  # -gustaf neumann
  #
  # valid parameters from the include are 
  #     tree_name: match pattern, if specified displays only the trees with matching names
  #     max_entries: show given number of new entries
  
  ::xowiki::IncludeletClass create categories-recent \
      -superclass ::xowiki::Includelet \
      -cacheable true -personalized false -aggregating true \
      -parameter {
        {title "#xowiki.recently_changed_pages_by_categories#"}
        {parameter_declaration {
          {-max_entries:integer 10}
          {-tree_name ""}
          {-locale ""}
        }}
      }

  categories-recent instproc render {} {
    my get_parameters
  
    set cattree [::xowiki::CatTree new -volatile -name "categories-recent"]

    foreach {locale locale_clause} \
        [::xowiki::Includelet locale_clause -revisions r -items ci $package_id $locale] break

    set tree_ids [::xowiki::Category get_mapped_trees -object_id $package_id -locale $locale \
                      -names $tree_name -output tree_id]
    
    if {$tree_ids ne ""} {
      set tree_select_clause "and c.tree_id in ([join $tree_ids ,])"
    } else {
      set tree_select_clause ""
    }
    set sql [::xo::db::sql select \
                 -vars "c.category_id, ci.name, r.title, r.publish_date, \
                        to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as formatted_date" \
                 -from "category_object_map_tree c, cr_items ci, cr_revisions r, xowiki_page p" \
                 -where "c.object_id = ci.item_id and ci.parent_id = [$package_id folder_id] \
	 and r.revision_id = ci.live_revision \
	 and p.page_id = r.revision_id $tree_select_clause $locale_clause \
         and ci.publish_status <> 'production'" \
                 -orderby "publish_date desc" \
                 -limit $max_entries]
    db_foreach [my qn get_pages] $sql {
      if {$title eq ""} {set title $name}
      set itemobj [Object new]
      set prefix  "$formatted_date "
      set suffix  ""
      foreach var {name title prefix suffix} {$itemobj set $var [set $var]}
      if {![info exists categories($category_id)]} {
        set categories($category_id) [::xowiki::Category new \
                                          -package_id $package_id \
                                          -label [category::get_name $category_id $locale]\
                                          -level 1]
        $cattree add  $categories($category_id)
      }
      $cattree add_to_category -category $categories($category_id) -itemobj $itemobj
    }
    return [$cattree render]
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # display recent entries 
  #
  
  ::xowiki::IncludeletClass create recent \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.recently_changed_pages#"}
        {parameter_declaration {
          {-max_entries:integer 10}
          {-allow_edit:boolean false}
          {-allow_delete:boolean false}
        }}
      }
  
  recent instproc render {} {
    my get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"
    TableWidget t1 -volatile \
        -set allow_edit $allow_edit \
        -set allow_delete $allow_delete \
        -columns {
          Field date -label [_ xowiki.Page-last_modified]
          if {[[my info parent] set allow_edit]} {
            ImageField_EditIcon edit -label "" -html {style "padding-right: 2px;"}
          }
          AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
          if {[[my info parent] set allow_delete]} {
            ImageField_DeleteIcon delete -label ""
          }
        }
    
    db_foreach [my qn get_pages] \
        [::xo::db::sql select \
             -vars "i.name, r.title, p.page_id, r.publish_date, i.parent_id, \
                to_char(r.publish_date,'YYYY-MM-DD HH24:MI:SS') as formatted_date" \
             -from "cr_items i, cr_revisions r, xowiki_page p" \
             -where "i.parent_id = [$package_id folder_id] \
                and r.revision_id = i.live_revision \
                and p.page_id = r.revision_id \
		and i.publish_status <> 'production'" \
             -orderby "publish_date desc" \
             -limit $max_entries ] {

        set page_link [$package_id pretty_link -parent_id $parent_id $name]
        t1 add \
            -title $title \
            -title.href $page_link \
            -date $formatted_date

        if {$allow_edit} {
          set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
          set edit_link [$package_id make_link -link $page_link $p edit return_url]
          #my log "page_link=$page_link, edit=$edit_link"
          [t1 last_child] set edit.href $edit_link
        }
        if {$allow_delete} {
          if {![info exists p]} {
            set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
          }
          set delete_link [$package_id make_link -link $page_link $p delete return_url]
          [t1 last_child] set delete.href $delete_link
        }
      }
    return [t1 asHTML]
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # display last visited entries 
  #
  
  ::xowiki::IncludeletClass create last-visited \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.last_visited_pages#"}
        {parameter_declaration {
          {-max_entries:integer 20}
        }}
      }
  
  last-visited instproc render {} {
    my get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    TableWidget t1 -volatile \
        -columns {
          AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
        }

    db_foreach [my qn get_pages] \
       [::xo::db::sql select \
            -vars "i.parent_id, r.title,i.name, to_char(time,'YYYY-MM-DD HH24:MI:SS') as visited_date" \
            -from "xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r"  \
            -where "x.page_id = i.item_id and i.live_revision = p.page_id  \
	    and r.revision_id = p.page_id and x.user_id = [::xo::cc user_id] \
	    and x.package_id = $package_id  and i.publish_status <> 'production'" \
            -orderby "visited_date desc" \
            -limit $max_entries] \
        {
          t1 add \
              -title $title \
              -title.href [$package_id pretty_link -parent_id $parent_id $name] 
        }
    return [t1 asHTML]
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # list the most popular pages
  #

  ::xowiki::IncludeletClass create most-popular \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.most_popular_pages#"}
        {parameter_declaration {
          {-max_entries:integer "10"}
          {-interval}
        }}
      }
  
  most-popular instproc render {} {
    my get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"
   
    if {[info exists interval]} {
      # 
      # If we have and interval, we cannot get report the number of visits 
      # for that interval, since we have only the aggregated values in
      # the database.
      #
      my append title " in last $interval"

      TableWidget t1 -volatile \
          -columns {
            AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
            Field users -label Visitors -html { align right }
          }
      set since_condition "and [::xo::db::sql since_interval_condition time $interval]"
      db_foreach [my qn get_pages] \
          [::xo::db::sql select \
               -vars "count(x.user_id) as nr_different_users, x.page_id, r.title,i.name, i.parent_id" \
               -from "xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r"  \
               -where "x.page_id = i.item_id and i.live_revision = p.page_id  and r.revision_id = p.page_id \
            and x.package_id = $package_id and i.publish_status <> 'production' \
            $since_condition" \
               -groupby "x.page_id, r.title, i.name, i.parent_id" \
               -orderby "nr_different_users desc" \
               -limit $max_entries ] {
                 t1 add \
                     -title $title \
                     -title.href [$package_id pretty_link -parent_id $parent_id $name] \
                     -users $nr_different_users
               }
    } else {

      TableWidget t1 -volatile \
          -columns {
            AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
            Field count -label [_ xowiki.includelets-visits] -html { align right }
            Field users -label [_ xowiki.includelet-visitors] -html { align right }
          }
      db_foreach [my qn get_pages] \
          [::xo::db::sql select \
               -vars "sum(x.count) as sum, count(x.user_id) as nr_different_users, x.page_id, r.title,i.name, i.parent_id" \
               -from "xowiki_last_visited x, xowiki_page p, cr_items i, cr_revisions r"  \
               -where "x.page_id = i.item_id and i.live_revision = p.page_id  and r.revision_id = p.page_id \
            and x.package_id = $package_id and i.publish_status <> 'production'" \
               -groupby "x.page_id, r.title, i.name, i.parent_id" \
               -orderby "sum desc" \
               -limit $max_entries] {
                 t1 add \
                     -title $title \
                     -title.href [$package_id pretty_link -parent_id $parent_id $name] \
                     -users $nr_different_users \
                     -count $sum
               }
    }
    return [t1 asHTML]
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # list the most frequent visitors
  #

  ::xowiki::IncludeletClass create rss-client \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.rss_client#"}
        {parameter_declaration {
          {-url:required}
          {-max_entries:integer "15"}
        }}
      }

  rss-client instproc initialize {} {
    my instvar feed
    my get_parameters
    my set feed [::xowiki::RSS-client new -url $url -destroy_on_cleanup]
    if {[info command [$feed channel]] ne ""} {
      my title [ [$feed channel] title]
    }
  }
  
  rss-client instproc render {} {
    my instvar feed
    my get_parameters
    if {[info command [$feed channel]] eq ""} {
      set detail ""
      if {[$feed exists errorMessage]} {set detail \n[$feed set errorMessage]}
      return "No data available from $url<br>$detail"
    } else {
      set channel [$feed channel]
      #set html "<H1>[$channel title]</H1>"
      set html "<UL>\n"
      set i 0
      foreach item [ $feed items ] {
        append html "<LI><B>[$item title]</B><BR> [$item description] <a href='[$item link]'>#xowiki.weblog-more#</a>\n"
        if {[incr i] >= $max_entries} break
      }
      append html "</UL>\n"
      return $html
    }
  }
}

namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # list the most frequent visitors
  #

  ::xowiki::IncludeletClass create most-frequent-visitors \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.most_frequent_visitors#"}
        {parameter_declaration {
          {-max_entries:integer "15"}
        }}
      }
  
  most-frequent-visitors instproc render {} {
    my get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"
   
    TableWidget t1 -volatile \
        -columns {
          Field user  -label Visitors -html { align right }
          Field count -label Visits -html { align right }
        }
    db_foreach [my qn get_pages] \
          [::xo::db::sql select \
               -vars "sum(count) as sum, user_id"  \
               -from "xowiki_last_visited"  \
               -where "package_id = $package_id"  \
               -groupby "user_id" \
               -orderby "sum desc" \
               -limit $max_entries] {
                 t1 add \
                     -user [::xo::get_user_name $user_id] \
                     -count $sum
               }
    return [t1 asHTML]
  }

}


namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # Display unread items
  #
  # Currently moderately useful
  # 
  # TODO: display of unread *revisions* should be included optionally, one has to
  # consider what to do with auto-created stuff (put it into 'production' state?)
  # 

  ::xowiki::IncludeletClass create unread-items \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "#xowiki.unread_items#"}
        {parameter_declaration {
          {-max_entries:integer 20}
        }}
      }
  
  unread-items instproc render {} {
    my get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    TableWidget t1 -volatile \
        -columns {
          AnchorField title -label [::xowiki::Page::slot::title set pretty_name]
        }

    set or_clause "or i.item_id in (
	select x.page_id 
	from xowiki_last_visited x, acs_objects o  \
	where x.time < o.last_modified 
	and x.page_id = o.object_id 
	and x.package_id = $package_id
        and x.user_id = [::xo::cc user_id]
     )"

    set or_clause ""

    db_foreach [my qn get_pages] \
       [::xo::db::sql select \
            -vars "a.title, i.name, i.parent_id" \
            -from "xowiki_page p, cr_items i, acs_objects a "  \
            -where "(i.item_id not in (
			select x.page_id from xowiki_last_visited x 
                        where x.user_id = [::xo::cc user_id] and x.package_id = $package_id
		    ) $or_clause
                    )
                    and i.live_revision = p.page_id 
                    and i.parent_id = [$package_id folder_id] 
                    and i.publish_status <> 'production'
                    and a.object_id = i.item_id" \
            -orderby "a.creation_date desc" \
            -limit $max_entries] \
        {
          t1 add \
              -title $title \
              -title.href [$package_id pretty_link -parent_id $parent_id $name] 
        }
    return [t1 asHTML]
  }
}




namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # Show the tags
  #

  ::xowiki::IncludeletClass create tags \
      -superclass ::xowiki::Includelet \
      -parameter {
        {title "Tags"}
        {parameter_declaration {
          {-limit:integer 20}
          {-summary:boolean 0}
          {-popular:boolean 0}
          {-page}
        }}
      }
  
  tags instproc render {} {
    my get_parameters
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"

    if {$popular} {
      set label [_ xowiki.popular_tags_label]
      set tag_type ptag
      set sql [::xo::db::sql select \
                   -vars "count(*) as nr,tag" \
                   -from xowiki_tags \
                   -where "package_id=$package_id" \
                   -groupby tag \
                   -orderby tag \
                   -limit $limit]
    } else {
      set label [_ xowiki.your_tags_label]
      set tag_type tag 
      set sql "select count(*) as nr,tag from xowiki_tags where \
        user_id=[::xo::cc user_id] and package_id=$package_id group by tag order by tag"
    }
    set entries [list]

    if {![info exists page]} {set page [$package_id get_parameter weblog_page]}
    set base_url [$package_id pretty_link $page]

    set href [$package_id package_url]tag/
    db_foreach [my qn get_counts] $sql {
      set q [list]
      if {$summary} {lappend q "summary=$summary"}
      if {$popular} {lappend q "popular=$popular"}
      set link $href$tag?[join $q &]
      #set href $base_url?$tag_type=[ad_urlencode $tag]$s
      #lappend entries "$tag <a href='$href'>($nr)</a>"
      lappend entries "$tag <a rel='tag' href='$link'>($nr)</a>"
    }
    return [expr {[llength $entries]  > 0 ? 
                  "<h3>$label</h3> <BLOCKQUOTE>[join $entries {, }]</BLOCKQUOTE>\n" :
                  ""}]
  }

  ::xowiki::IncludeletClass create my-tags \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-summary 1}
        }}
        id
      }
  
  my-tags instproc render {} {
    my get_parameters
    my instvar __including_page tags
    ::xo::Page requireJS  "/resources/xowiki/get-http-object.js"
    
    set p_link [$package_id pretty_link [$__including_page name]]
    set return_url "[::xo::cc url]?[::xo::cc actual_query]"
    set weblog_page [$package_id get_parameter weblog_page weblog]
    set save_tag_link [$package_id make_link -link $p_link $__including_page \
                           save-tags return_url]
    set popular_tags_link [$package_id make_link -link $p_link $__including_page \
                               popular-tags return_url weblog_page]

    set tags [lsort [::xowiki::Page get_tags -user_id [::xo::cc user_id] \
                         -item_id [$__including_page item_id] -package_id $package_id]]
    set href [$package_id package_url]$weblog_page?summary=$summary&tag

    set entries [list]

    #foreach tag $tags {lappend entries "<a href='$href&tag=[ad_urlencode $tag]'>$tag</a>"}
    set href [$package_id package_url]/tag/
    foreach tag $tags {lappend entries "<a rel='tag' href='$href[ad_urlencode $tag]?summary=$summary'>$tag</a>"}
    set tags_with_links [join [lsort $entries] {, }]

    if {![my exists id]} {my set id [::xowiki::Includelet html_id [self]]}
    set content [subst -nobackslashes {
      #xowiki.your_tags_label#: $tags_with_links
      (<a href='#' onclick='document.getElementById("[my id]-edit_tags").style.display="block";return false;'>#xowiki.edit_link#</a>,
       <a href='#' onclick='get_popular_tags("$popular_tags_link","[my id]");return false;'>#xowiki.popular_tags_link#</a>)
      <FORM id='[my id]-edit_tags' style='display: none' action="$save_tag_link" method='POST'>
        <INPUT name='new_tags' type='text' value="$tags">
      </FORM>
      <span id='[my id]-popular_tags' style='display: none'></span><br >
    }]
    return $content
  }

  
  ::xowiki::IncludeletClass create my-categories \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-summary 1}
        }}
      }
  
  my-categories instproc render {} {
    my get_parameters
    my instvar __including_page
    set content ""

    set weblog_page [$package_id get_parameter weblog_page weblog]
    set entries [list]
    set href [$package_id package_url]$weblog_page?summary=$summary
    set notification_type ""
    if {[$package_id get_parameter "with_notifications" 1] &&
        [::xo::cc user_id] != 0} { ;# notifications require login
      set notification_type [notification::type::get_type_id -short_name xowiki_notif]
    }
    if {[$package_id exists_query_parameter return_url]} {
      set return_url [$package_id query_parameter return_url]
    }
    foreach cat_id [category::get_mapped_categories [$__including_page set item_id]] {
      foreach {category_id category_name tree_id tree_name} [category::get_data $cat_id] break
      #my log "--cat $cat_id $category_id $category_name $tree_id $tree_name"
      set entry "<a href='$href&category_id=$category_id'>$category_name ($tree_name)</a>"
      if {$notification_type ne ""} {
        set notification_text "Subscribe category $category_name in tree $tree_name"
        set notifications_return_url [expr {[info exists return_url] ? $return_url : [ad_return_url]}]
        set notification_image \
            "<img style='border: 0px;' src='/resources/xowiki/email.png' \
   	     alt='$notification_text' title='$notification_text'>"

        set cat_notif_link [export_vars -base /notifications/request-new \
                                {{return_url $notifications_return_url} \
                                     {pretty_name $notification_text} \
                                     {type_id $notification_type} \
                                     {object_id $category_id}}]
        append entry "<a href='$cat_notif_link'> " \
                         "<img style='border: 0px;' src='/resources/xowiki/email.png' " \
                         "alt='$notification_text' title='$notification_text'>" </a>

      }
      lappend entries $entry
    }
    if {[llength $entries]>0} {
      set content "#xowiki.categories#: [join $entries {, }]"
    }
    return $content
  }

  ::xowiki::IncludeletClass create my-general-comments \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}}
  
  my-general-comments instproc render {} {
    my get_parameters
    my instvar __including_page
    set item_id [$__including_page item_id] 
    set gc_return_url [$package_id url]
    # Even, if general_comments is turned on, don't offer the
    # link to add comments, unless the user is logged in.
    # Otherwise, this attracts spammers and search bots
    if {[::xo::cc user_id] != 0} {
      set gc_link [general_comments_create_link \
                       -object_name [$__including_page title] \
                       $item_id $gc_return_url]
      set gc_link <p>$gc_link</p>
    } else {
      set gc_link ""
    }
    set gc_comments [general_comments_get_comments $item_id $gc_return_url]
    if {$gc_comments ne ""} {
      return "<p>#general-comments.Comments#<ul>$gc_comments</ul></p>$gc_link"
    } else {
      return "$gc_link"
    }
  }
  
  ::xowiki::IncludeletClass create digg \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-description ""}
          {-url}
        }}
      }
  
  digg instproc render {} {
    my get_parameters
    my instvar __including_page
    set digg_link [export_vars -base "http://digg.com/submit" {
      {phase 2} 
      {url       $url}
      {title     "[string range [$__including_page title] 0 74]"}
      {body_text "[string range $description 0 349]"}
    }]
    regsub -all & $digg_link "&amp;" digg_link
    return "<a class='image-button' href='$digg_link'><img src='http://digg.com/img/badges/100x20-digg-button.png' width='100' height='20' alt='Digg!'></a>"
  }

  ::xowiki::IncludeletClass create delicious \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-description ""}
          {-tags ""}
          {-url}
        }}
      }
  
  delicious instproc render {} {
    my get_parameters
    my instvar __including_page

    # the following opens a window, where a user can edit the posted info.
    # however, it seems not possible to add tags this way automatically.
    # Alternatively, one could use the api as descibed below; this allows
    # tags, but no editing...
    # http://farm.tucows.com/blog/_archives/2005/3/24/462869.html#adding

    set delicious_link [export_vars -base "http://del.icio.us/post" {
      {v 4}
      {url   $url}
      {title "[string range [$__including_page title] 0 79]"}
      {notes "[string range $description 0 199]"}
      tags
    }]
    regsub -all & $delicious_link "&amp;" delicious_link
    return "<a class='image-button' href='$delicious_link'><img src='http://i.i.com.com/cnwk.1d/i/ne05/fmwk/delicious_14x14.gif' width='14' height='14' alt='Add to your del.icio.us' />del.icio.us</a>"
  }


  ::xowiki::IncludeletClass create my-yahoo-publisher \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-publisher ""}
          {-rssurl}
        }}
      }
  
  my-yahoo-publisher instproc render {} {
    my get_parameters
    my instvar __including_page

    set publisher [ad_urlencode $publisher]
    set feedname  [ad_urlencode [[$package_id folder_id] title]]
    set rssurl    [ad_urlencode $rssurl]
    set my_yahoo_link "http://us.rd.yahoo.com/my/atm/$publisher/$feedname/*http://add.my.yahoo.com/rss?url=$rssurl"

    return "<a class='image-button' href='$my_yahoo_link'><img src='http://us.i1.yimg.com/us.yimg.com/i/us/my/addtomyyahoo4.gif' width='91' height='17' align='middle' alt='Add to My Yahoo!'></a>"
  }


  #
  # my-references lists the pages which are refering to the 
  # including page
  #
  ::xowiki::IncludeletClass create my-references \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}}
  
  my-references instproc render {} {
    my get_parameters
    my instvar __including_page

    set item_id [$__including_page item_id] 
    set refs [list]
    # The same image might be linked both, as img or file on one page, 
    # so we need DISTINCT.
    db_foreach [my qn get_references] "SELECT DISTINCT page,ci.name,f.package_id \
        from xowiki_references,cr_items ci,cr_folders f \
        where reference=$item_id and ci.item_id = page and ci.parent_id = f.folder_id" {
          ::xowiki::Package require $package_id
          lappend refs "<a href='[$package_id pretty_link $name]'>$name</a>"
        }
    set references [join $refs ", "]

    array set lang {found "" undefined ""}
    foreach i [$__including_page array names lang_links] {
      set lang($i) [join [$__including_page set lang_links($i)] ", "]
    }
    append references " " $lang(found)
    set result ""
    if {$references ne " "} {
      append result "#xowiki.references_label# $references"
    }
    if {$lang(undefined) ne ""} {
      append result "#xowiki.create_this_page_in_language# $lang(undefined)"
    }
    return $result
  }

  #
  # my-refers lists the pages which are refered to by the 
  # including page
  #
  ::xowiki::IncludeletClass create my-refers \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration none}}
  
  my-refers instproc render {} {
    my get_parameters
    my instvar __including_page

    set item_id [$__including_page item_id] 
    set refs [list]
    db_foreach [my qn get_references] "SELECT reference,ci.name,f.package_id,ci.parent_id \
        from xowiki_references,cr_items ci,cr_folders f \
        where page=$item_id and ci.item_id = reference and ci.parent_id = f.folder_id" {
          ::xowiki::Package require $package_id
          lappend refs "<a href='[$package_id pretty_link -parent_id $parent_id $name]'>$name</a>"
        }
    set references [join $refs ", "]

    array set lang {found "" undefined ""}
    foreach i [$__including_page array names lang_links] {
      set lang($i) [join [$__including_page set lang_links($i)] ", "]
    }
    append references " " $lang(found)
    set result ""
    if {$references ne " "} {
      append result "#xowiki.references_of_label# $references"
    }
    if {$lang(undefined) ne ""} {
      append result "#xowiki.create_this_page_in_language# $lang(undefined)"
    }
    return $result
  }

}

namespace eval ::xowiki::includelet {
  #############################################################################
  # presence
  #
  ::xowiki::IncludeletClass create presence \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration rightbox}
        {parameter_declaration {
          {-interval "10 minutes"}
          {-max_users:integer 40}
          {-show_anonymous "summary"}
          {-page}
        }}
      }

  # TODO make display style -decoration

  presence instproc render {} {
    my get_parameters

    set summary 0
    if {[::xo::cc user_id] == 0} {
      switch -- $show_anonymous {
        nothing {return ""}
        all     {set summary 0} 
        default {set summary 1} 
      }
    }

    if {[info exists page] && $page eq "this"} {
      my instvar __including_page
      set extra_where_clause "and page_id = [$__including_page item_id] "
      set what " on page [$__including_page title]"
    } else {
      set extra_where_clause ""
      set what " in community [$package_id instance_name]"
    }

    if {!$summary} {
      set select_users "user_id, to_char(max(time),'YYYY-MM-DD HH24:MI:SS') as max_time from xowiki_last_visited "
    }
    set since_condition [::xo::db::sql since_interval_condition time $interval]
    set where_clause "package_id=$package_id and $since_condition $extra_where_clause"
    set when "<br>in last $interval"

    set output ""

    if {$summary} {
      set count [db_string [my qn presence_count_users] \
                     "select count(distinct user_id) from xowiki_last_visited WHERE $where_clause"]
    } else {
      set values [db_list_of_lists [my qn get_users] \
                      [::xo::db::sql select \
                           -vars "user_id, to_char(max(time),'YYYY-MM-DD HH24:MI:SS') as max_time" \
                           -from xowiki_last_visited \
                           -where $where_clause \
                           -groupby user_id \
                           -orderby "max_time desc" \
                           -limit $max_users ]]
      set count [llength $values]
      if {$count == $max_users} {
        # we have to check, whether there were more users...
        set count [db_string [my qn presence_count_users] "$select_count $where_clause"] 
      }
      foreach value  $values {
        foreach {user_id time} $value break
        set seen($user_id) $time
        
        regexp {^([^.]+)[.]} $time _ time
        set pretty_time [util::age_pretty -timestamp_ansi $time \
                             -sysdate_ansi [clock_to_ansi [clock seconds]] \
                             -mode_3_fmt "%d %b %Y, at %X"]
        set name [::xo::get_user_name $user_id]

        append output "<TR><TD class='user'>$name</TD><TD class='timestamp'>$pretty_time</TD></TR>\n"
      }
      if {$output ne ""} {set output "<TABLE>$output</TABLE>\n"}
    }
    set users [expr {$count == 0 ? "No registered users" : 
                     $count == 1 ? "1 registered user" : 
                     "$count registered users"}]
    return "<div class='title'>$users$what$when</div>$output"
  }
}


namespace eval ::xowiki::includelet {
  #############################################################################
  # includelets based on order
  #
  ::xowiki::IncludeletClass create toc \
      -superclass ::xowiki::Includelet \
      -cacheable true -personalized false -aggregating true \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-style ""} 
          {-open_page ""}
          {-book_mode false}
          {-ajax true}
          {-expand_all false}
          {-remove_levels 0}
          {-category_id}
          {-locale ""}
          {-source ""}
          {-range ""}
        }}
        id
      }

#"select page_id,  page_order, name, title, \
#	(select count(*)-1 from xowiki_page_live_revision where page_order <@ p.page_order) as count \
#	from xowiki_page_live_revision p where not page_order is NULL order by page_order asc"

  toc instproc count {} {return [my set navigation(count)]}
  toc instproc current {} {return [my set navigation(current)]}
  toc instproc position {} {return [my set navigation(position)]}
  toc instproc page_name {p} {return [my set page_name($p)]}
  toc instproc cache_includelet_data {key} {
    append data \
	[list my array set navigation [my array get navigation]] \n \
	[list my array set page_name [my array get page_name]] \n
    return $data
  }

  toc proc anchor {name} {
    # try to strip the language prefix from the name
    regexp {^.*:([^:]+)$} $name _ name
    # anchor is used between single quotes
    regsub -all ' $name {\'} anchor
    return $anchor
  }

  toc instproc build_toc {package_id locale source range} {
    my instvar navigation page_name book_mode
    array set navigation {parent "" position 0 current ""}

    set extra_where_clause ""
    if {[my exists category_id]} {
      foreach {cnames extra_where_clause} [my category_clause [my set category_id]] break
    }
    foreach {locale locale_clause} \
        [::xowiki::Includelet locale_clause -revisions p -items p $package_id $locale] break
    #my msg locale_clause=$locale_clause

    if {$source ne ""} {
      my get_page_order -source $source
      set page_names ('[join [my array names page_order] ',']')
      set page_order_clause "and name in $page_names"
      set page_order_att ""
    } else {
      set page_order_clause "and not page_order is NULL"
      set page_order_att "page_order,"
    }

    set sql [::xo::db::sql select \
                 -vars "page_id, $page_order_att name, title" \
                 -from "xowiki_page_live_revision p" \
                 -where "parent_id=[$package_id folder_id] \
			$page_order_clause \
			$extra_where_clause $locale_clause"]
    set pages [::xowiki::Page instantiate_objects -sql $sql]

    $pages mixin add ::xo::OrderedComposite::IndexCompare
    if {$range ne "" && $page_order_att ne ""} {
      foreach {from to} [split $range -] break
      foreach p [$pages children] {
	if {[$pages __value_compare [$p set page_order] $from 0] == -1
	    || [$pages __value_compare [$p set page_order] $to 0] > 0} {
	  $pages delete $p
	}
      }
    }

    $pages orderby page_order
    if {$source ne ""} {
      # add the page_order to the objects
      foreach p [$pages children] {
	$p set page_order [my set page_order([$p set name])]
      }
    }

    return $pages
  }

  toc instproc href {package_id book_mode name} {
    if {$book_mode} {
      set href [$package_id url]#[toc anchor $name]
    } else {
      set href [$package_id pretty_link $name]
    }
    return $href
  }

  toc instproc page_number {page_order remove_levels} {
    #my log "o: $page_order"
    set displayed_page_order $page_order
    for {set i 0} {$i < $remove_levels} {incr i} {
      regsub {^[^.]+[.]} $displayed_page_order "" displayed_page_order
    }
    return $displayed_page_order
  }

  toc instproc yui_tree {pages open_page package_id expand_all remove_levels} {
    my instvar navigation page_name book_mode
    array set navigation {parent "" position 0 current ""}

    set js ""
    set node() root
    set node_cnt 0
    #my log "--book read [llength [$pages children]] pages"

    foreach o [$pages children] {
      $o instvar page_order title page_id name  

      set label "[my page_number $page_order $remove_levels] $title"
      set id tmpNode[incr node_cnt]
      set node($page_order) $id
      set jsobj [my js_name].objs\[$node_cnt\]

      set page_name($node_cnt) $name
      if {![regexp {^(.*)[.]([^.]+)} $page_order _ parent]} {set parent ""}

      set href [my href $package_id $book_mode $name]
      
      if {$expand_all} {
	set expand "true"
      } else {
	set expand [expr {$open_page eq $name} ? "true" : "false"]
	if {$expand} {
	  set navigation(parent) $parent
	  set navigation(position) $node_cnt
	  set navigation(current) $page_order
	  for {set p $parent} {$p ne ""} {} {
	    if {![info exists node($p)]} break
	    append js "$node($p).expand();\n"
	    if {![regexp {^(.*)[.]([^.]+)} $p _ p]} {set p ""}
	  }
	}
      }
      set parent_node [expr {[info exists node($parent)] ? $node($parent) : "root"}]
      set refvar [expr {[my set ajax] ? "ref" : "href"}]
      regsub -all {\"} $label {\"} label
      #my log "$jsobj = {label: \"$label\", id: \"$id\", $refvar: \"$href\",  c: $node_cnt};"
      append js \
	  "$jsobj = {label: \"$label\", id: \"$id\", $refvar: \"$href\",  c: $node_cnt};" \
	  "var $node($page_order) = new YAHOO.widget.TextNode($jsobj, $parent_node, $expand);\n" \
          ""

    }
    set navigation(count) $node_cnt
    #my log "--COUNT=$node_cnt"
    return $js
  }

  toc instproc ajax_tree {js_tree_cmds} {
    return "<div id='[my id]'>
      <script type = 'text/javascript'>
      var [my js_name] = {

         count: [my set navigation(count)],

         getPage: function(href, c) {
             //  console.log('getPage: ' + href + ' type: ' + typeof href) ;

             if ( typeof c == 'undefined' ) {

                 // no c given, search it from the objects
                 // console.log('search for href <' + href + '>');

                 for (i in this.objs) {
                     if (this.objs\[i\].ref == href) {
                        c = this.objs\[i\].c;
                        // console.log('found href ' + href + ' c=' + c);
                        var node = this.tree.getNodeByIndex(c);
                        if (!node.expanded) {node.expand();}
                        node = node.parent;
                        while (node.index > 1) {
                            if (!node.expanded) {node.expand();}
                            node = node.parent;
                        }
                        break;
                     }
                 }
                 if (typeof c == 'undefined') {
                     // console.warn('c undefined');
                     return false;
                 }
             }
             // console.log('have href ' + href + ' c=' + c);

             var transaction = YAHOO.util.Connect.asyncRequest('GET', \
                 href + '?template_file=view-page&return_url=' + href, 
                {
                  success:function(o) {
                     var bookpage = document.getElementById('book-page');
     		     var fadeOutAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 0} }, 0.5 );

                     var doFadeIn = function(type, args) {
                        // console.log('fadein starts');
                        var bookpage = document.getElementById('book-page');
                        bookpage.innerHTML = o.responseText;
                        var fadeInAnim = new YAHOO.util.Anim(bookpage, { opacity: {to: 1} }, 0.1 );
                        fadeInAnim.animate();
                     }

                     // console.log(' tree: ' + this.tree + ' count: ' + this.count);
                     // console.info(this);

                     if (this.count > 0) {
                        var percent = (100 * o.argument / this.count).toFixed(2) + '%';
                     } else {
                        var percent = '0.00%';
                     }

                     if (o.argument > 1) {
                        var link = this.objs\[o.argument - 1 \].ref;
                        var src = '/resources/xowiki/previous.png';
                        var onclick = 'return [my js_name].getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/previous-end.png';
                     }

                     // console.log('changing prev href to ' + link);
                     // console.log('changing prev onclick to ' + onclick);

                     document.getElementById('bookNavPrev.img').src = src;
                     document.getElementById('bookNavPrev.a').href = link;
                     document.getElementById('bookNavPrev.a').setAttribute('onclick',onclick);

                     if (o.argument < this.count) {
                        var link = this.objs\[o.argument + 1 \].ref;
                        var src = '/resources/xowiki/next.png';
                        var onclick = 'return [my js_name].getPage(\"' + link + '\");' ;
                     } else {
                        var link = '#';
                        var onclick = '';
                        var src = '/resources/xowiki/next-end.png';
                     }

                     // console.log('changing next href to ' + link);
                     // console.log('changing next onclick to ' + onclick);
                     document.getElementById('bookNavNext.img').src = src;
                     document.getElementById('bookNavNext.a').href = link;

                     document.getElementById('bookNavNext.a').setAttribute('onclick',onclick);
                     document.getElementById('bookNavRelPosText').innerHTML = percent;
                     document.getElementById('bookNavBar').setAttribute('style', 'width: ' + percent + ';');

                     fadeOutAnim.onComplete.subscribe(doFadeIn);
  		     fadeOutAnim.animate();
                  }, 
                  failure:function(o) {
                     // console.error(o);
                     // alert('failure ');
                     return false;
                  },
                  argument: c,
                  scope: [my js_name]
                }, null);

                return false;
            },


         treeInit: function() { 
            [my js_name].tree = new YAHOO.widget.TreeView('[my id]'); 
            root = [my js_name].tree.getRoot(); 
            [my js_name].objs = new Array();
            $js_tree_cmds

            [my js_name].tree.subscribe('labelClick', function(node) {
              [my js_name].getPage(node.data.ref, node.data.c); });
            [my js_name].tree.draw();
         }

      };

     YAHOO.util.Event.addListener(window, 'load', [my js_name].treeInit);
      </script>
    </div>"
  }

  toc instproc tree {js_tree_cmds} {
    return "<div id='[my id]'>
      <script type = 'text/javascript'>
      var [my js_name] = {

         getPage: function(href, c) { return true; },

         treeInit: function() { 
            [my js_name].tree = new YAHOO.widget.TreeView('[my id]'); 
            root = [my js_name].tree.getRoot(); 
            [my js_name].objs = new Array();
            $js_tree_cmds
            [my js_name].tree.draw();
         }
      };
      YAHOO.util.Event.on(window, 'load', [my js_name].treeInit);
      </script>
    </div>"
  }


  toc instproc include_head_entries_yui_tree {ajax style} {
    set ajaxhelper 1

    ::xo::Page requireCSS "/resources/ajaxhelper/yui/treeview/assets/${style}tree.css"
    if {$style eq ""} {
      ::xowiki::Includelet require_YUI_CSS -ajaxhelper $ajaxhelper \
          treeview/assets/skins/sam/treeview.css
    }
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "yahoo/yahoo-min.js"
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "event/event-min.js"

    if {$ajax} {
      ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "dom/dom-min.js"    ;# ANIM
      ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "connection/connection-min.js"
      ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "animation/animation-min.js"   ;# ANIM
    }  
    ::xowiki::Includelet require_YUI_JS -ajaxhelper $ajaxhelper "treeview/treeview.js"
  }


  toc instproc render_yui_tree {pages style} {
    my get_parameters

    my set book_mode $book_mode
    if {!$book_mode} {
      ###### my set book_mode [[my set __including_page] exists __is_book_page]
    } elseif $ajax {
      #my log "--warn: cannot use bookmode with ajax, resetting ajax"
      set ajax 0
    }
    my set ajax $ajax
            
    set js_tree_cmds [my yui_tree $pages $open_page $package_id $expand_all $remove_levels]
    return [expr {$ajax ? [my ajax_tree $js_tree_cmds ] : [my tree $js_tree_cmds ]}]
  }

  toc instproc render_list {pages} {
    my get_parameters
    set html "<UL>\n"
    set level 0
    foreach o [$pages children] {
      $o instvar page_order title page_id name
      set page_number [my page_number $page_order $remove_levels]
      set new_level [regsub -all {[.]} $page_number . _]
      if {$new_level > $level} {
	for {set l $level} {$l < $new_level} {incr l} {append html "<ul>\n"}
	set level $new_level
      } elseif {$new_level < $level} {
	for {set l $new_level} {$l < $level} {incr l} {append html "</ul>\n"}
	set level $new_level
      }
      set href [my href $package_id $book_mode $name]
      append html "<li><a href='$href'>$page_number $title</a>\n"
    }
    for {set l 0} {$l <= $level} {incr l} {append html "</ul>\n"}
    return $html
  }

  toc instproc include_head_entries {} {
    my get_parameters
    if {$style ne "list"} {
      my include_head_entries_yui_tree $ajax $style
    }
  }

  toc instproc render {} {
    my get_parameters
    set list_mode 0
    if {![my exists id]} {my set id [::xowiki::Includelet html_id [self]]}
    if {[info exists category_id]} {my set category_id $category_id}

    switch -- $style {
      "menu" {set s "menu/"}
      "folders" {set s "folders/"}
      "list"    {set s ""; set list_mode 1}
      "default" {set s ""}
    }
    set pages [my build_toc $package_id $locale $source $range]

    if {$list_mode} {
      return [my render_list $pages]
    } else {
      return [my render_yui_tree $pages $s]
    }
  }

  #############################################################################
  # Selection
  #
  # TODO: base book (and toc) on selection
  ::xowiki::IncludeletClass create selection \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-edit_links:boolean true}
          {-pages ""}
          {-ordered_pages ""}
          {-source}
          {-menu_buttons edit}
	  {-range ""}
        }}
      }

  selection instproc render {} {
    my instvar page_order
    my get_parameters
    my set package_id $package_id
    my set edit_links $edit_links

    if {[info exists source]} {
      my get_page_order -source $source
    } else {
      my get_page_order -pages $pags -ordered_pages $ordered_pages
    }

    # should check for quotes in names
    set page_names ('[join [array names page_order] ',']')
    set pages [::xowiki::Page instantiate_objects -sql \
                   "select page_id, name, title, item_id \
		from xowiki_page_live_revision p \
		where parent_id = [$package_id folder_id] \
		and name in $page_names \
		[::xowiki::Page container_already_rendered item_id]" ]
    foreach p [$pages children] {
      $p set page_order $page_order([$p set name])
    }

    $pages mixin add ::xo::OrderedComposite::IndexCompare
    if {$range ne ""} {
      foreach {from to} [split $range -] break
      foreach p [$pages children] {
	if {[$pages __value_compare [$p set page_order] $from 0] == -1
	    || [$pages __value_compare [$p set page_order] $to 0] > 0} {
	  $pages delete $p
	}
      }
    }
    
    $pages orderby page_order
    return [my render_children $pages $menu_buttons]
  }

  selection instproc render_children {pages menu_buttons} {
    my instvar package_id edit_links
    foreach o [$pages children] {
      $o instvar page_order title page_id name title
      set level [expr {[regsub {[.]} $page_order . page_order] + 1}] 
      set edit_markup ""
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]
      $p set unresolved_references 0
      
      switch [$p info class] {
        ::xowiki::Form {
          set content [$p render]
        }
        default { 
          set content [$p get_content]
          set content [string map [list "\{\{" "\\\{\{"] $content]
        }
      }

      set menu [list]
      foreach b $menu_buttons {
	if {[info command ::xowiki::includelet::$b] eq ""} {
	  set b $b-item-button
	}
	set html [$p include [list $b -book_mode true]]
	if {$html ne ""} {lappend menu $html}
      }
      append output "<h$level class='book'>" \
          "<div style='float: right'>" [join $menu "&nbsp;"] "</div>" \
          "<a name='[toc anchor $name]'></a>$page_order $title</h$level>" \
          $content
    }
    return $output
  }

  ::xowiki::IncludeletClass create composite-form \
      -superclass ::xowiki::includelet::selection \
      -parameter {
        {parameter_declaration {
          {-edit_links:boolean false}
          {-pages ""}
          {-ordered_pages}
        }}
      }

  composite-form instproc render {} {
    my get_parameters
    my instvar __including_page
    set inner_html [next]
    #my log "innerhtml=$inner_html"
    regsub -nocase -all "<form " $inner_html "<div class='form' " inner_html
    regsub -nocase -all "<form>" $inner_html "<div class='form'>" inner_html
    regsub -nocase -all "</form *>" $inner_html "</div>" inner_html
    dom parse -simple -html <form>$inner_html</form> doc
    $doc documentElement root

    set fields [$root selectNodes "//div\[@class = 'wiki-menu'\]"]
    foreach field $fields {$field delete}

    set inner_html [$root asHTML]
    set id ID[$__including_page item_id]
    set base [$package_id pretty_link [$__including_page name]]
    #set id ID$item_id
    #$root setAttribute id $id
    set as_att_value [string map [list & "&amp;" < "&lt;" > "&gt;" \" "&quot;" ' "&apos;"] $inner_html]

    set save_form [subst {
      <p>
      <a href='#' onclick='document.getElementById("$id").style.display="inline";return false;'>Create Form from Content</a>
      </p>
      <span id='$id' style='display: none'>
      Form Name: 
      <FORM action="$base?m=create-new" method='POST' style='display: inline'>
         <INPUT name='class' type='hidden' value="::xowiki::Form">
         <INPUT name='content' type='hidden' value="$as_att_value">
         <INPUT name='name' type='text'>
      </FORM>
      </span>
    }]

    return $inner_html$save_form
  }

  #############################################################################
  # book style
  #
  ::xowiki::IncludeletClass create book \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-category_id}
          {-menu_buttons edit}
          {-locale ""}
	  {-range ""}
        }}
      }

  book instproc render {} {
    my get_parameters

    my instvar __including_page
    lappend ::xowiki_page_item_id_rendered [$__including_page item_id]
    $__including_page set __is_book_page 1

    set extra_where_clause ""
    set cnames ""
    if {[info exists category_id]} {
      foreach {cnames extra_where_clause} [my category_clause $category_id] break
    }

    foreach {locale locale_clause} \
        [::xowiki::Includelet locale_clause -revisions p -items p $package_id $locale] break

    set pages [::xowiki::Page instantiate_objects -sql \
        "select page_id, page_order, name, title, item_id \
		from xowiki_page_live_revision p \
		where parent_id = [$package_id folder_id] \
		and not page_order is NULL $extra_where_clause \
		$locale_clause \
		[::xowiki::Page container_already_rendered item_id]" ]
    $pages mixin add ::xo::OrderedComposite::IndexCompare
    $pages orderby page_order

    set output ""
    if {$cnames ne ""} {
      append output "<div class='filter'>Filtered by categories: $cnames</div>"
    }
    set return_url [::xo::cc url]

    if {$range ne ""} {
      foreach {from to} [split $range -] break
      foreach p [$pages children] {
	if {[$pages __value_compare [$p set page_order] $from 0] == -1
	    || [$pages __value_compare [$p set page_order] $to 0] > 0} {
	  $pages delete $p
	}
      }
    }

    foreach o [$pages children] {
      $o instvar page_order title page_id name title 
      set level [expr {[regsub -all {[.]} $page_order . page_order] + 1}]
      set p [::xo::db::CrClass get_instance_from_db -item_id 0 -revision_id $page_id]

      $p set unresolved_references 0
      #$p set render_adp 0
      switch [$p info class] {
        ::xowiki::Form {
          set content [$p render]
        }
        default { 
          set content [$p get_content]
          #set content [string map [list "\{\{" "\\\{\{"] $content]
        }
      }
      set menu [list]
      foreach b $menu_buttons {
	if {[info command ::xowiki::includelet::$b] eq ""} {
	  set b $b-item-button
	}
	set html [$p include [list $b -book_mode true]]
	if {$html ne ""} {lappend menu $html}
      }
      set menu [join $menu "&nbsp;"]
      if {$menu ne ""} {
        # <div> not allowed in h*: style='float: right; position: relative; top: -32px
        set menu "<span style='float: right;'>$menu</span>"
      }

      append output \
          "<h$level class='book'>" $menu \
          "<a name='[toc anchor $name]'></a>$page_order $title</h$level>" \
          $content
    }
    return $output
  }
}

namespace eval ::xowiki::includelet {
  ::xowiki::IncludeletClass create item-button \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {return_url ""}
      }

  item-button instproc initialize {} {
      if {[my return_url] eq "" } { my return_url [[my package_id] url]}
  }

  item-button instproc render_button {
    -page 
    -package_id
    -method
    -link
    -src 
    -alt 
    -title 
    -return_url 
    -page_order
    -object_type
    -source_item_id
  } {
    set html ""
    if {![info exists return_url] || $return_url eq ""} {set return_url [$package_id url]}
    if {![info exists alt]} {set alt $method}
    if {![info exists src]} {set src [my set src]}
    if {![info exists link] || $link eq ""} {
      if {[$page istype ::xowiki::Package]} {
	set link  [$package_id make_link $package_id edit-new object_type \
		       return_url page_order source_item_id]
      } else {
	set p_link [$package_id pretty_link -parent_id [$page parent_id] [$page name]]
	set link [$package_id make_link -link $p_link $page $method \
		      return_url page_order source_item_id]
      }
    }
    if {$link ne ""} {
      set html "<a class='image-button' href=\"$link\"><img src='$src' alt=\"$alt\" title=\"$title\"></a>"
    }
    return $html
  }

  ::xowiki::IncludeletClass create edit-item-button -superclass ::xowiki::includelet::item-button \
      -parameter {
        {parameter_declaration {
          {-page_id}
          {-title "#xowiki.edit#"}
          {-alt "edit"}
          {-book_mode false}
        }}
      }
  
  edit-item-button instproc render {} {
    my get_parameters
    my instvar __including_page return_url
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]
    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      set title "$title [$template title] [$page name]"
    }
    
    if {$book_mode} {
      append return_url #[toc anchor [$page name]]
    }
    return [my render_button \
		-page $page -method edit -package_id $package_id \
		-title $title -alt $alt -return_url $return_url \
		-src /resources/acs-subsite/Edit16.gif]
  }

  ::xowiki::IncludeletClass create delete-item-button \
      -superclass ::xowiki::includelet::item-button \
      -parameter {
        {__decoration none}
        {src /resources/acs-subsite/Delete16.gif}
        {parameter_declaration {
          {-page_id}
          {-title "#xowiki.delete#"}
          {-alt "delete"}
          {-book_mode false}
        }}
      }

  delete-item-button instproc render {} {
    my get_parameters
    my instvar __including_page return_url
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]
    return [my render_button \
		  -page $page -method delete -package_id $package_id \
		  -title $title -alt $alt \
		  -return_url $return_url]
  }

 ::xowiki::IncludeletClass create view-item-button \
      -superclass ::xowiki::includelet::item-button \
      -parameter {
        {__decoration none}
        {src /resources/acs-subsite/Zoom16.gif}
        {parameter_declaration {
          {-page_id}
          {-title "#xowiki.view#"}
          {-alt "view"}
          {-link ""}
          {-book_mode false}
        }}
      }

  view-item-button instproc render {} {
    my get_parameters
    my instvar __including_page return_url
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]
    return [my render_button \
		-page $page -method view -package_id $package_id \
		-link $link -title $title -alt $alt \
		-return_url $return_url]
  }


  ::xowiki::IncludeletClass create create-item-button \
      -superclass ::xowiki::includelet::item-button \
      -parameter {
        {__decoration none}
        {src /resources/acs-subsite/Add16.gif}
        {parameter_declaration {
          {-page_id}
          {-alt "new"}
          {-book_mode false}
        }}
      }

  create-item-button instproc render {} {
    my get_parameters
    my instvar __including_page return_url
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]
    set page_order [::xowiki::Includelet incr_page_order [$page page_order]]
    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      return [my render_button \
		  -page $template -method create-new -package_id $package_id \
		  -title [_ xowiki.create_new_entry_of_type [list type [$template title]]] \
		  -alt $alt -page_order $page_order \
		  -return_url $return_url]
    } else {
      set object_type [$__including_page info class]
      return [my render_button \
		  -page $package_id -method edit_new -package_id $package_id \
		  -title [_ xowiki.create_new_entry_of_type [list type $object_type]] \
		  -alt $alt -page_order $page_order \
		  -return_url $return_url \
                  -object_type $object_type]
    }
  }

  ::xowiki::IncludeletClass create copy-item-button -superclass ::xowiki::includelet::item-button \
      -parameter {
        {__decoration none}
        {src /resources/acs-subsite/Copy16.gif}
        {parameter_declaration {
          {-page_id}
          {-alt "copy"}
          {-book_mode false}
        }}
      }

  copy-item-button instproc render {} {
    my get_parameters
    my instvar __including_page return_url
    set page [expr {[info exists page_id] ? $page_id : $__including_page}]

    if {[$page istype ::xowiki::FormPage]} {
      set template [$page page_template]
      return [my render_button \
		  -page $template -method create-new -package_id $package_id \
		  -title [_ xowiki.copy_entry [list type [$template title]]] \
		  -alt $alt -source_item_id [$page item_id] \
		  -return_url $return_url]
    } else {
      set object_type [$__including_page info class]
      return [my render_button \
		  -page $package_id -method edit_new -package_id $package_id \
		  -title [_ xowiki.copy_entry [list type $object_type]] \
		  -alt $alt -source_item_id [$page item_id] \
		  -return_url $return_url \
                  -object_type $object_type]
    }
  }


}


namespace eval ::xowiki::includelet {

  ::xowiki::IncludeletClass create graph \
      -superclass ::xowiki::Includelet \
      -parameter {{__decoration plain}}

  graph instproc graphHTML {-edges -nodes -max_edges -cutoff -base {-attrib node_id}} {

    ::xo::Page requireJS "/resources/ajaxhelper/prototype/prototype.js"
    set user_agent [string tolower [ns_set get [ns_conn headers] User-Agent]]
    if {[string match "*msie *" $user_agent]} {
      # canvas support for MSIE
      ::xo::Page requireJS "/resources/xowiki/excanvas.js"
    }
    ::xo::Page requireJS "/resources/xowiki/collab-graph.js"
    ::xo::Page requireJS "/resources/ajaxhelper/yui/yahoo/yahoo.js"
    ::xo::Page requireJS "/resources/ajaxhelper/yui/event/event.js"

    set nodesHTML ""
    array set n $nodes

    foreach {node label} $nodes {
      set link "<a href='$base?$attrib=$node'>$label</a>"
      append nodesHTML "<div id='$node' style='position:relative;'>&nbsp;&nbsp;&nbsp;&nbsp;$link</div>\n"
    }

    set edgesHTML ""; set c 0
    foreach p [lsort -index 1 -decreasing -integer $edges] {
      foreach {edge weight width} $p break
      foreach {a b} [split $edge ,] break
      #my log "--G $a -> $b check $c > $max_edges, $weight < $cutoff"
      if {[incr c]>$max_edges} break
      if {$weight < $cutoff} continue
      append edgesHTML "g.addEdge(\$('$a'), \$('$b'), $weight, 0, $width);\n"
    }
    # [lsort -index 1 -decreasing -integer $edges]<br>[set cutoff] - [set c]<br>

    return [subst -novariables {
<div>
<canvas id="collab" width="500" height="500" style="border: 0px solid black">
</canvas>
[set nodesHTML]
<script type="text/javascript">
function draw() {
  if (typeof(G_vmlCanvasManager) == "object") {
      G_vmlCanvasManager.init_(window.document);
  } 
  
  var g = new Graph();
[set edgesHTML]
  var layouter = new Graph.Layout.Spring(g);
  layouter.layout();

  // IE does not pick up the canvas width or height
  $('collab').width=500;
  $('collab').height=500;

  var renderer = new Graph.Renderer.Basic($('collab'), g);
  renderer.radius = 5;
  renderer.draw();
}
 YAHOO.util.Event.addListener(window, 'load', draw);
//   YAHOO.util.Event.onContentReady('collab', draw); 
</script>
</div>
}]
  }
}

namespace eval ::xowiki::includelet {
  ::xowiki::IncludeletClass create collab-graph \
      -superclass ::xowiki::includelet::graph \
      -parameter {
        {parameter_declaration {
          {-max_edges 70} 
          {-cutoff 0.1} 
          {-show_anonymous "message"}
          -user_id
        }}
      }
  
  collab-graph instproc render {} {
    my get_parameters
    
    if {$show_anonymous ne "all" && [::xo::cc user_id] eq 0} {
      return "You must login to see the [namespace tail [self class]]"
    }
    if {![info exists user_id]} {set user_id [::xo::cc user_id]}

    set folder_id [$package_id folder_id]    
    db_foreach [my qn get_collaborators] {
      select count(revision_id), item_id, creation_user 
      from cr_revisions r, acs_objects o 
      where item_id in 
        (select distinct i.item_id from 
          acs_objects o, acs_objects o2, cr_revisions cr, cr_items i 
          where o.object_id = i.item_id and o2.object_id = cr.revision_id 
          and o2.creation_user = :user_id and i.item_id = cr.item_id 
          and i.parent_id = :folder_id order by item_id
        ) 
      and o.object_id = revision_id 
      and creation_user is not null 
      group by item_id, creation_user} {

      lappend i($item_id) $creation_user $count
      set count_var user_count($creation_user)
      if {![info exists $count_var]} {set $count_var 0}
      incr $count_var $count
      set user($creation_user) "[::xo::get_user_name $creation_user] ([set $count_var])"
      if {![info exists activities($creation_user)]} {set activities($creation_user) 0}
      incr activities($creation_user) $count
    }

    set result "<p>Collaboration Graph for <b>[::xo::get_user_name $user_id]</b> in this wiki" 
    if {[array size i] < 1} {
      append result "</p><p>No collaborations found</p>"
    } else {

      foreach x [array names i] {
        foreach {u1 c1} $i($x) {
          foreach {u2 c2} $i($x) {
            if {$u1 < $u2} {
              set var collab($u1,$u2)
              if {![info exists $var]} {set $var 0} 
              incr $var $c1
              incr $var $c2
            }
          }
        }
      }

      set max 50
      foreach x [array names collab] {
        if {$collab($x) > $max} {set max $collab($x)}
      }
 
      set edges [list]
      foreach x [array names collab] {
        lappend edges [list $x $collab($x) [expr {$collab($x)*5.0/$max}]]
      }

      append result "($activities($user_id) contributions)</p>\n"
      append result [my graphHTML \
                         -nodes [array get user] -edges $edges \
                         -max_edges $max_edges -cutoff $cutoff \
                         -base collab -attrib user_id]
    }
    
    return $result
  }


  ::xowiki::IncludeletClass create activity-graph \
      -superclass ::xowiki::includelet::graph \
      -parameter {
        {parameter_declaration {
          {-max_edges 70} 
          {-cutoff 0.1}
          {-max_activities:integer 100}
          {-show_anonymous "message"}
        }}
      }
  

  activity-graph instproc render {} {
    my get_parameters

    if {$show_anonymous ne "all" && [::xo::cc user_id] eq 0} {
      return "You must login to see the [namespace tail [self class]]"
    }

    set tmp_table_name XOWIKI_TMP_ACTIVITY
    #my msg "tmp exists [::xo::db::require exists_table $tmp_table_name]"
    set tt [::xo::db::temp_table new \
                -name $tmp_table_name \
                -query [::xo::db::sql select \
                   -vars "i.item_id, revision_id, creation_user" \
                   -from "cr_revisions cr, cr_items i, acs_objects o" \
                   -where "cr.item_id = i.item_id \
                            and i.parent_id = [$package_id folder_id] \
                            and o.object_id = revision_id" \
                   -orderby "revision_id desc" \
                   -limit $max_activities] \
                -vars "item_id, revision_id, creation_user"]
    
    set total 0
    db_foreach [my qn get_activities] "
      select count(revision_id) as count, item_id, creation_user  
      from $tmp_table_name 
      where creation_user is not null 
      group by item_id, creation_user
   " {
      lappend i($item_id) $creation_user $count
      incr total $count
      set count_var user_count($creation_user)
      if {![info exists $count_var]} {set $count_var 0}
      incr $count_var $count
      set user($creation_user) "[::xo::get_user_name $creation_user] ([set $count_var])"
    }
    $tt destroy

    if {[array size i] == 0} {
      append result "<p>No activities found</p>"
    } elseif {[array size user] == 1} {
      set user_id [lindex [array names user] 0]
      append result "<p>Last $total activities were done by user " \
          "<a href='collab?$user_id'>[::xo::get_user_name $user_id]</a>."
    } else {
      append result "<p>Collaborations in last $total activities by [array size user] Users in this wiki</p>"

      foreach x [array names i] {
        foreach {u1 c1} $i($x) {
          foreach {u2 c2} $i($x) {
            if {$u1 < $u2} {
              set var collab($u1,$u2)
              if {![info exists $var]} {set $var 0} 
              incr $var $c1
              incr $var $c2
            }
          }
        }
      }

      set max 0
      foreach x [array names collab] {
        if {$collab($x) > $max} {set max $collab($x)}
      }
 
      set edges [list]
      foreach x [array names collab] {
        lappend edges [list $x $collab($x) [expr {$collab($x)*5.0/$max}]]
      }

      append result [my graphHTML \
                         -nodes [array get user] -edges $edges \
                         -max_edges $max_edges -cutoff $cutoff \
                         -base collab -attrib user_id]
    }
    
    return $result
  }

  ::xowiki::IncludeletClass create timeline \
      -superclass ::xowiki::Includelet \
      -parameter {
        {parameter_declaration {
          -user_id 
          {-data timeline-data} 
          {-interval1 DAY} 
          {-interval2 MONTH}
        }}
      }
  
  timeline instproc render {} {
    my get_parameters

    ::xo::Page requireJS "/resources/ajaxhelper/yui/yahoo/yahoo.js"
    ::xo::Page requireJS "/resources/ajaxhelper/yui/event/event.js"
    ::xo::Page requireJS "/resources/xowiki/timeline/api/timeline-api.js"

   set stamp [clock format [clock seconds] -format "%b %d %Y %X %Z" -gmt true]
   if {[info exists user_id]} {append data "?user_id=$user_id"}

   return [subst -nocommands -nobackslashes {
 <div id="my-timeline" style="font-size:70%; height: 350px; border: 1px solid #aaa"></div>
<script type="text/javascript">
var tl;
function onLoad() {
  var eventSource = new Timeline.DefaultEventSource();
  var bandInfos = [
    Timeline.createBandInfo({
        eventSource:    eventSource,
        date:           "$stamp",
        width:          "70%", 
        intervalUnit:   Timeline.DateTime.$interval1, 
        intervalPixels: 100
    }),
    Timeline.createBandInfo({
        eventSource:    eventSource,
        date:           "$stamp",
        width:          "30%", 
        intervalUnit:   Timeline.DateTime.$interval2, 
        intervalPixels: 200
    })
  ];
  //console.info(bandInfos);
  bandInfos[1].syncWith = 0;
  bandInfos[1].highlight = true;

  tl = Timeline.create(document.getElementById("my-timeline"), bandInfos);
  //console.log('create done');
  Timeline.loadXML("$data", function(xml, url) {eventSource.loadXML(xml,url); });
}

var resizeTimerID = null;
function onResize() {
//   console.log('resize');

    if (resizeTimerID == null) {
        resizeTimerID = window.setTimeout(function() {
            resizeTimerID = null;
//   console.log('call layout');
            tl.layout();
        }, 500);
    }
}

YAHOO.util.Event.addListener(window, 'load',   onLoad());
// YAHOO.util.Event.addListener(window, 'resize', onResize());

</script>

  }]
  }

  ::xowiki::IncludeletClass create user-timeline \
      -superclass timeline \
      -parameter {
        {parameter_declaration {
           -user_id 
           {-data timeline-data} 
           {-interval1 DAY} 
           {-interval2 MONTH}
        }}
      }
  
  user-timeline instproc render {} {
    my get_parameters
    if {![info exists user_id]} {set user_id [::xo::cc user_id]]}
    ::xo::cc set_parameter user_id $user_id
    next 
 }

}


namespace eval ::xowiki::includelet {
  #############################################################################
  Class create form-menu-button \
      -parameter {
        form
        method
        link
        package_id
        base
        return_url
        {label_suffix ""}
      }
  form-menu-button instproc render {} {
    my instvar package_id base form method return_url label_suffix link
    if {![info exists link]} {
      set link [$package_id make_link -link $base $form $method return_url]
    }
    if {$link eq ""} {
      return ""
    }
    set msg_key [namespace tail [my info class]]
    set label [_ xowiki.$msg_key [list form_name [$form name]]]$label_suffix
    return "<a href='$link'>$label</a>"
  }

  Class form-menu-button-new -superclass form-menu-button -parameter {
    {method create-new}
  }
  Class form-menu-button-answers -superclass form-menu-button -parameter {
    {method list}
  }
  form-menu-button-answers instproc render {} {
    set (publish_status) ready
    array set "" [::xowiki::PageInstance get_list_from_form_constraints \
                      -name @table_properties \
                      -form_constraints [[my form] get_form_constraints -trylocal true]]
    set count [[my form] count_usages -publish_status $(publish_status)]
    my label_suffix " ($count)"
    next
  }

  Class form-menu-button-form -superclass form-menu-button -parameter {
    {method view}
  }


  ::xowiki::IncludeletClass create form-menu \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration none}
        {parameter_declaration {
          {-form_item_id:integer}
          {-buttons {new answers}}
          {-button_objs}
          {-return_url}
        }}
      }
  
  form-menu instproc render {} {
    my get_parameters
    my instvar __including_page
    if {![info exists button_objs]} {
      foreach b $buttons {
        if {[llength $b]>1} {
          foreach {button id} $b break
        } else {
          foreach {button id} [list $b $form_item_id] break
        }
        set form [::xo::db::CrClass get_instance_from_db -item_id $id]
        #
        # "Package require" is just a part of "Package initialize" creating 
        # the package object if needed
        #
        ::xowiki::Package require [$form package_id]
        set obj  [form-menu-button-$button new -volatile -package_id $package_id \
                      -base [[$form package_id] pretty_link [$form name]] -form $form]
        if {[info exists return_url]} {$obj return_url $return_url}
        lappend button_objs $obj
      }
    }
    set links [list]
    foreach b $button_objs { lappend links [$b render] }
    return "<div style='clear: both;'><div class='wiki-menu'>[join $links { &middot; }]</div></div>\n"
  }

  #############################################################################
  ::xowiki::IncludeletClass create form-usages \
      -superclass ::xowiki::Includelet \
      -parameter {
        {__decoration plain}
        {parameter_declaration {
          {-form_item_id:integer}
          {-form}
          {-orderby "__last_modified,desc"}
          {-publish_status "ready"}
          {-field_names}
          {-category_id}
          {-unless}
          {-where}
          {-with_categories}
          {-csv true}
          {-voting_form}
          {-voting_form_form ""}
          {-voting_form_anon_instances "t"}
          {-generate}
          {-with_form_link true}
        }}
      }
  
  form-usages instproc render {} {
    my get_parameters

    my instvar __including_page
    set o $__including_page
    ::xo::Page requireCSS "/resources/acs-templating/lists.css"
    set return_url [::xo::cc url]?[::xo::cc actual_query]

    if {![info exists form_item_id]} {
      set form_item_id [::xo::db::CrClass lookup -name $form -parent_id [$package_id folder_id]]
      if {$form_item_id == 0} {error "Cannot lookup page $form"}
    }

    set form_item [::xo::db::CrClass get_instance_from_db -item_id $form_item_id]
    set form_constraints [$form_item get_form_constraints -trylocal true]
    #my msg fc=[$form_item get_form_constraints]

    # load table properties; order_by won't work due to comma, but solve that later (TODO)
    set table_properties [::xowiki::PageInstance get_list_from_form_constraints \
                              -name @table_properties \
                              -form_constraints $form_constraints]
    foreach {attr value} $table_properties {
      switch $attr {
        orderby {set $attr _[::xowiki::formfield::FormField fc_decode $value]}
        publish_status -  category_id - unless -
        where -   with_categories - csv - voting_form -
        voting_form_form - voting_form_anon_instances {
          set $attr $value
          #my msg " set $attr $value"
        }
        default {error "unknown table property '$attr' provided"}
      }
    }

    if {![info exists field_names]} {
      set fn [::xowiki::PageInstance get_short_spec_from_form_constraints \
                  -name @table \
                  -form_constraints $form_constraints]
      set raw_field_names [split $fn ,]
    } elseif {[string match "*,*" $field_names] } {
      set raw_field_names [split $field_names ,]
    } else {
      set raw_field_names $field_names
    }

    if {$raw_field_names eq ""} {
      set raw_field_names {_name _last_modified _creation_user}
    }

    # finally, evaluate conditions if included
    set field_names [list]
    foreach f $raw_field_names {
      set _ [string trim [::xowiki::formfield::FormField get_single_spec \
			      -object $o -package_id $package_id $f]]
      if {$_ ne ""} {lappend field_names $_}
    }

    set form_fields [::xowiki::FormPage get_table_form_fields \
                          -base_item $form_item \
                          -field_names $field_names \
                          -form_constraints $form_constraints]
    # $form_item show_fields $form_fields
    foreach f $form_fields {set __ff([$f name]) $f}

#    if {[info exists __ff(_creation_user)]} {$__ff(_creation_user) label "By User"}

    # TODO: wiki-substituion is just hacked in here. maybe it makes
    # more sense to use it as a default for _text, but we have to
    # check all the nested cases to avoid double-substitutions.
    if {[info exists __ff(_text)]} {$__ff(_text) set wiki 1}

    set cols ""
    append cols {ImageField_EditIcon _edit -label "" -html {style "padding: 2px;"} -no_csv 1} \n
    foreach fn $field_names {
      #set richtext [expr {[$__ff($fn) istype ::xowiki::formfield::abstract_page] 
      #                    || [$__ff($fn) istype ::xowiki::formfield::richtext]}]
      append cols [list AnchorField _$fn \
		       -label [$__ff($fn) label] \
		       -richtext 1 \
		       -orderby _$fn] \n
    }
    append cols [list ImageField_DeleteIcon _delete -label "" -no_csv 1] \n
    TableWidget t1 -volatile -columns $cols

    #
    # Sorting is done for the time being in Tcl. This has the advantage
    # that page_order can be sorted with the special mixin and that
    # instance attributes can be used for sorting as well.
    #
    foreach {att order} [split $orderby ,] break
    if {$att eq "__page_order"} {
      t1 mixin add ::xo::OrderedComposite::IndexCompare
    }
    #my msg "order=[expr {$order eq {asc} ? {increasing} : {decreasing}}] $att"
    t1 orderby -order [expr {$order eq "asc" ? "increasing" : "decreasing"}] $att

    # 
    # Compute filter clauses
    #
    set init_vars [list]
    array set uc {tcl false h "" vars "" sql ""}
    if {[info exists unless]} {
      array set uc [::xowiki::FormPage filter_expression $unless ||]
      set init_vars [concat $init_vars $uc(vars)]
    }
    array set wc {tcl true h "" vars "" sql ""}
    if {[info exists where]} {
      array set wc [::xowiki::FormPage filter_expression $where &&]
      set init_vars [concat $init_vars $wc(vars)]
    }
    #my msg uc=[array get uc]
    #my msg wc=[array get wc]

    #
    # get an ordered composite of the base set (currently including extra_where clause)
    # 
    #my log "exists category_id [info exists category_id]"
    set extra_where_clause ""
    if {[info exists category_id]} {
      foreach {cnames extra_where_clause} [my category_clause $category_id bt.item_id] break
    }

    set items [::xowiki::FormPage get_form_entries \
                   -base_item_id $form_item_id \
                   -form_fields $form_fields \
                   -publish_status $publish_status \
                   -always_queried_attributes [list _name _last_modified _creation_user] \
                   -extra_where_clause $extra_where_clause \
                   -h_where [array get wc] \
                   -package_id $package_id]

    if {[info exists with_categories]} {
      if {$extra_where_clause eq ""} {
        set base_items $items
      } else {
        # difference to variable items: just the extra_where_clause
        set base_items [::xowiki::FormPage get_form_entries \
                   -base_item_id $form_item_id \
                   -form_fields $form_fields \
                   -publish_status $publish_status \
                   -always_queried_attributes [list _name _last_modified _creation_user] \
                   -h_where [array get wc] \
                   -package_id $package_id]
      }
    }
    #my log "queries done"

    foreach p [$items children] {
      $p set package_id $package_id
      array set __ia $init_vars
      array set __ia [$p instance_attributes]
      if {[expr $uc(tcl)]} continue
      #if {![expr $wc(tcl)]} continue ;# already handled in get_form_entries

      set page_link [$package_id pretty_link -parent_id [$p parent_id] [$p name]]

      t1 add \
          -_delete delete \
          -_delete.href [$package_id make_link -link $page_link $p delete return_url] \
          -_edit edit \
	  -_edit.href [$package_id make_link -link $page_link $p edit return_url] 
      
      set __c [t1 last_child]
      $__c set __name.href $page_link

      # set always last_modified for default sorting
      $__c set __last_modified [$p set last_modified]

      foreach __fn $field_names {
        $__c set _$__fn [$__ff($__fn) pretty_value [$p property $__fn]]
      }
      $__c set __name [$package_id external_name -parent_id [$p parent_id] [$p name]]
    }

    #
    # If there are multiple includelets on a single page,
    # we have to identify the right one for e.g. producing the
    # csv table. Therefore, we compute an includelet_key
    #
    my instvar name
    set includelet_key ""
    foreach var {name form_item_id form publish_states field_names unless} {
      if {[info exists $var]} {append includelet_key $var : [set $var] ,}
    }

    if {[info exists voting_form]} {
      # if the user provided a voting form name without a language prefix,
      # add one.
      if {![regexp {^..:} $voting_form]} {
        set obj [my set __including_page]
        set voting_form [$obj lang]:$voting_form
      }
    }

    set given_includelet_key [::xo::cc query_parameter includelet_key ""]
    if {$given_includelet_key ne ""} {
      if {$given_includelet_key eq $includelet_key && [info exists generate]} {
        if {$generate eq "csv"} {
          return [t1 write_csv]
        } elseif {$generate eq "voting_form"} {
          return [my generate_voting_form $voting_form $voting_form_form t1 $field_names $voting_form_anon_instances]
        }
      }
      return ""
    }

    set links [list]
    set base [$package_id pretty_link -parent_id [$form_item parent_id] [$form_item name]]
    set label [$form_item name]

    if {$with_form_link} {
      append html [_ xowiki.entries_using_form [list form "<a href='$base'>$label</a>"]]
    }
    append html [t1 asHTML]

    if {$csv} {
      set csv_href "[::xo::cc url]?[::xo::cc actual_query]&includelet_key=[ns_urlencode $includelet_key]&generate=csv"
      lappend links "<a href='$csv_href'>csv</a>"
    }
    if {[info exists voting_form]} {
      set href "[::xo::cc url]?[::xo::cc actual_query]&includelet_key=[ns_urlencode $includelet_key]&generate=voting_form"
      lappend links " <a href='$href'>Generate Voting Form $voting_form</a>"
    }
    append html [join $links ,]
    #my log "render done"

    if {[info exists with_categories]} {
      set category_html [$o include [list categories -count 1 -tree_name $with_categories \
                                         -ordered_composite $base_items]]
      return "<div style='width: 15%; float: left;'>$category_html</div></div width='69%'>$html</div>\n"
    }
    return $html
  }

  form-usages instproc generate_voting_form {form_name form_form t1 field_names voting_form_anon_instances} {
    #my msg "generate_voting anon=$voting_form_anon_instances"
    set form "<form> How do you rate<br /> 
    <table rules='all' frame='box' cellspacing='1' cellpadding='1' border='0' style='border-style: none;'>
      <tbody> 
        <tr> 
          <td style='border-style: none;'> </td> 
          <td style='border-style: none; text-align: left; width: 150px;'>&nbsp;very good<br /></td> 
          <td align='right' style='border-style: none; text-align: right; width: 150px;'>&nbsp;very bad<br /></td> 
        </tr> \n"
 
    # We use here the table t1 to preserve sorting etc. 
    # The basic assumption is that every line of the table has an instance variable
    # corresponding to the wanted field name. This is guaranteed by the construction
    # in form-usages.
    set count 0
    set table_field_names [list]
    foreach t [$t1 children] {
      incr count
      lappend table_field_names $count
      # In most situations, it seems useful to have just one field in
      # the voting table. If there are multiple, we use a comma to
      # separate the values (looks bettern than separate columns).
      set field_contents [list]
      foreach __fn $field_names {
        lappend field_contents [$t set $__fn]
      }
      append form "<tr><td>[join $field_contents {, }]</td><td align='center' colspan='2'>@$count@</td></tr>\n"
    }

    append form "</tbody></table></form>\n"
    lappend table_field_names _last_modified _creation_user

    # Check, of we have a form for editing the generated form. If yes, we will
    # instantiate a form page from it.
    set form_form_id 0 
    if {$form_form ne ""} { 
      set form_form_id  [::xo::db::CrClass lookup -name $form_form -parent_id [[my package_id] folder_id]] 
    } 
    # The normal form requires for rich-text the 2 element list as content
    if {$form_form_id == 0} { set form [list $form text/html] }

    set item_id [::xo::db::CrClass lookup -name $form_name -parent_id [[my package_id] folder_id]]
    if {$item_id == 0} {
      
      if {$form_form_id == 0} {
        set f [::xowiki::Form new \
                   -package_id [my package_id] \
                   -parent_id [[my package_id] folder_id] \
                   -name $form_name \
                   -anon_instances $voting_form_anon_instances \
                   -form $form \
                   -form_constraints "@fields:scale,n=7,inline=true @cr_fields:hidden @categories:off\n\
                   @table:[join $table_field_names ,]" \
                  ]
      } else {
        set f [::xowiki::FormPage new \
                   -page_template $form_form_id \
                   -package_id [my package_id] \
                   -parent_id [[my package_id] folder_id] \
                   -name $form_name]
        $f set_property anon_instances $voting_form_anon_instances
        $f set_property form $form
        $f set_property form_constraints "@fields:scale,n=7,inline=true @cr_fields:hidden @categories:off\n\
                   @table:[join $table_field_names ,]"
      }
      $f save_new
      $f destroy
      set action created
    } else {
      ::xo::db::CrClass get_instance_from_db -item_id $item_id
      if {$form_form_id == 0} {
        $item_id form $form
      } else {
        $item_id set_property form $form
      }
      $item_id save
      set action updated
    }
    return "#xowiki.form-$action# <a href='[[my package_id] pretty_link $form_name]'>$form_name</a>"
  }
}
 
namespace eval ::xowiki::includelet {
  #############################################################################
  #
  # Show an iframe as includelet
  #
  ::xowiki::IncludeletClass create iframe \
      -superclass ::xowiki::Includelet \
      -parameter {
        {parameter_declaration {
           {-title ""}
           {-url:required}
           {-width "100%"}
           {-height "500px"}
        }}
      }

  iframe instproc render {} {
    my get_parameters
    
    if {$title eq ""} {set title $url}
    set content "<iframe src='$url' width='$width' height='$height'></iframe>"
    append content "<p><a href='$url' title='$title'>$title</a></p>"
    return $content
  }
}
