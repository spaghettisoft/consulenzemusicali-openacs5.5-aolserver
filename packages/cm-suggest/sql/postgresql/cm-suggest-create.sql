begin;

-- Users. They are OpenAcs users with expiration dates
create table cmit_users (
     user_id integer  primary key references users(user_id)
    ,valid_from       date
    ,valid_to         date
);

-- Membership. It's a membership relation with expiration dates
create table cmit_memberships (
     membership_id     integer primary key references acs_rels(rel_id)
    ,valid_from         date
    ,valid_to           date
);

-- Groups. They are OpenAcs groups with expiration dates
create table cmit_groups (
     group_id   integer primary key references groups(group_id)
    ,valid_from date
    ,valid_to   date
);

-- Playlists will be categories with an expiration date to which we map FileStorage Files
create table cmit_playlists (
     playlist_id  integer primary key references categories(category_id)
    ,thumbnail_id integer references cr_revisions(revision_id)
    ,valid_from   date
    ,valid_to     date
);

-- Songs will be FileStorage files with an expiration date
create table cmit_songs (
     song_id     integer primary key references cr_revisions(item_id)
    ,valid_from  date
    ,valid_to    date
);

-- A song can be specified to belong to a playlist for a limited period of time
create table cmit_playlist_songs (
     playlist_id  integer references cmit_playlists(playlist_id)
    ,song_id      integer references cmit_songs(song_id)
    ,valid_from   date
    ,valid_to     date
    ,order_no     integer not null
    ,foreign key (playlist_id, song_id) references category_object_map (category_id, object_id)
);

end;