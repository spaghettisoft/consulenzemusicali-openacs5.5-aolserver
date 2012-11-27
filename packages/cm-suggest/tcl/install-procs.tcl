ad_library {

    Procs for package installation
    
}

namespace eval cmit {}

ad_proc -private cmit::after-instantiate {
  -package_id:required
} {
    Creates some package structures
} {
    # Create the playlists tree
    set tree_name "cm-playlists-$package_id"
    
    category_tree::add -name $tree_name -description $tree_name -context_id $package_id
}

ad_proc -private cmit::before-uninstantiate {
  -package_id:required
} {
    Deletes all structures mapped to this package
} {
    # Deletes all trees mapped to this package
    set trees [category_tree::get_mapped_trees $package_id]
    
    foreach tree $trees {
	category_tree::delete [lindex $tree 0]
    }
}