ad_page_contract {
    Views dependency information about a version.
    @author Jon Salz [jsalz@arsdigita.com]
    @creation-date 17 April 2000
    @cvs-id $Id: version-dependencies.tcl,v 1.4 2009/04/13 23:10:27 donb Exp $
} {
    {version_id:integer}
}

db_1row  apm_package_info_by_version_id {
    select package_key, pretty_name, version_name, installed_p 
    from apm_package_version_info 
    where version_id = :version_id
}

doc_body_append "[apm_header [list "version-view?version_id=$version_id" "$pretty_name $version_name"] "Dependencies"]

"

foreach dependency_type { provide extend require } {

    set dependency_type_prep "${dependency_type}s"
    if { [string index $dependency_type end] eq "e" } {
        set dependency_type_prep_2 ${dependency_type}d
    } else {
        set dependency_type_prep_2 ${dependency_type}ed
    }
    doc_body_append "<h3>Services [string totitle $dependency_type_prep_2]</h3><ul>\n"

    db_foreach apm_all_dependencies {} {
	doc_body_append "<li>[string totitle $dependency_type_prep] service $service_uri, version $service_version (<a href=\"version-dependency-remove?[export_url_vars dependency_id version_id dependency_type]\">remove</a>)\n"
	
	# If this package provides a service, show a list of all packages that require it,
	# or vice versa. If this package provides a service, show other packages requiring
	# a *lower* version of the service; if it requires one, show packages providing
	# a *higher* version.

	set sign [ad_decode $dependency_type "provide" "<=" ">="]

	set counter 0
        set other_dependency_in [ad_decode $dependency_type "provide" "'requires','extends'" "'provides'"]
	db_foreach apm_specific_version_dependencies {} {
            incr counter
	    if { $counter == 1 } {
		doc_body_append "<ul>\n"
	    }
            switch $dep_type {
                provides { set dep_d provided }
                requires { set dep_d required }
                extends { set dep_d extended }
            } 
	    doc_body_append "<li>[string totitle $dep_d] by <a href=\"version-view?version_id=$dep_version_id\">$dep_pretty_name, version $dep_version_name</a>\n"
	}
	if { $counter != 0 } {
	    doc_body_append "</ul>\n"
	}	
    } else {
	doc_body_append "<li>This package does not $dependency_type any services.\n"
    }
    if { $installed_p eq "t" } {
	doc_body_append "<li><a href=\"version-dependency-add?[export_url_vars version_id dependency_type]\">Add a service $dependency_type_prep_2 by this package</a>\n"
    }
    doc_body_append "</ul>\n"
}

db_release_unused_handles
doc_body_append "
</ul>
[ad_footer]
"

