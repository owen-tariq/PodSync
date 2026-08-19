#include "clibgpod.h"
#include <string.h>
#include <stdlib.h>

// Full definition required to set struct fields directly
struct _Itdb_Track
{
  Itdb_iTunesDB *itdb;
  gchar   *title;
  gchar   *ipod_path;
  gchar   *album;
  gchar   *artist;
  gchar   *genre;
  gchar   *filetype;
  gchar   *comment;
  gchar   *category;
  gchar   *composer;
  gchar   *grouping;
  gchar   *description;
  gchar   *podcasturl;
  gchar   *podcastrss;
  Itdb_Chapterdata *chapterdata;
  gchar   *subtitle;
  gchar   *tvshow;
  gchar   *tvepisode;
  gchar   *tvnetwork;
  gchar   *albumartist;
  gchar   *keywords;
  gchar   *sort_artist;
  gchar   *sort_title;
  gchar   *sort_album;
  gchar   *sort_albumartist;
  gchar   *sort_composer;
  gchar   *sort_tvshow;
  guint32 id;
  gint32  size;
  gint32  tracklen;
  gint32  cd_nr;
  gint32  cds;
  gint32  track_nr;
  gint32  tracks;
  gint32  bitrate;
  guint16 samplerate;
  guint16 samplerate_low;
  gint32  year;
  gint32  volume;
  guint32 soundcheck;
  time_t  time_added;
  time_t  time_modified;
  time_t  time_played;
  guint32 bookmark_time;
  guint32 rating;
  guint32 playcount;
  guint32 playcount2;
  guint32 recent_playcount;
  gboolean transferred;
  gint16  BPM;
  guint8  app_rating;
  guint8  type1;
  guint8  type2;
  guint8  compilation;
  guint32 starttime;
  guint32 stoptime;
  guint8  checked;
  guint64 dbid;
  guint32 drm_userid;
  guint32 visible;
  guint32 filetype_marker;
  guint16 artwork_count;
  guint32 artwork_size;
  float samplerate2;
  guint16 unk126;
  guint32 unk132;
  time_t  time_released;
  guint16 unk144;
  guint16 explicit_flag;
  guint32 unk148;
  guint32 unk152;
  guint32 skipcount;
  guint32 recent_skipcount;
  guint32 last_skipped;
  guint8 has_artwork;
  guint8 skip_when_shuffling;
  guint8 remember_playback_position;
  guint8 flag4;
  guint64 dbid2;
  guint8 lyrics_flag;
  guint8 movie_flag;
  guint8 mark_unplayed;
  guint8 unk179;
  guint32 unk180;
  guint32 pregap;
  guint64 samplecount;
  guint32 unk196;
  guint32 postgap;
  guint32 unk204;
  guint32 mediatype;
  guint32 season_nr;
  guint32 episode_nr;
  guint32 unk220;
  guint32 unk224;
  guint32 unk228, unk232, unk236, unk240, unk244;
  guint32 gapless_data;
  guint32 unk252;
  guint16 gapless_track_flag;
  guint16 gapless_album_flag;
  guint16 obsolete;
  struct _Itdb_Artwork *artwork;
  guint32 skip_count;
  guint32 recent_skip_count;
  time_t last_skipped_time;
  gint32 has_video;
  guint32 content_rating;
  guint32 content_rating_level;
  gpointer userdata;
  guint64 usertype;
};

void gpod_track_set_extended_info(Itdb_Track *track, gint32 tracklen, gint32 size, gint32 year, gint32 track_nr, gint32 cd_nr) {
    if (!track) return;
    track->tracklen = tracklen;
    track->size = size;
    track->year = year;
    track->track_nr = track_nr;
    track->cd_nr = cd_nr;
    track->visible = 1;
}

// Structs for list iteration
struct _MyGList {
  void *data;
  struct _MyGList *next;
  struct _MyGList *prev;
};

struct _MyItdb_iTunesDB {
  struct _MyGList *tracks;
};

void gpod_track_set_filetype(Itdb_Track *track, const char *filetype) {
    if (!track) return;
    if (track->filetype) free(track->filetype);
    track->filetype = filetype ? strdup(filetype) : NULL;
}

void gpod_track_set_mediatype(Itdb_Track *track, guint32 mediatype) {
    if (!track) return;
    track->mediatype = mediatype;
    
    // Auto-set flags based on media type
    if (mediatype == 2 || mediatype == 32 || mediatype == 64) {
        track->has_video = 1;
        track->movie_flag = 1;
        track->remember_playback_position = 1;
    } else if (mediatype == 8 || mediatype == 4) { // Audiobook or Podcast
        track->remember_playback_position = 1;
        track->skip_when_shuffling = 1;
    }
}

guint32 gpod_track_get_mediatype(Itdb_Track *track) {
    return track ? track->mediatype : 1;
}

void gpod_ensure_sysinfo_artwork_formats(Itdb_iTunesDB *itdb) {
    // Stub - removed as it crashed
}

void** gpod_get_all_tracks(Itdb_iTunesDB *itdb, uint32_t *count) {
    if (!itdb) {
        *count = 0;
        return NULL;
    }
    struct _MyItdb_iTunesDB *my_db = (struct _MyItdb_iTunesDB *)itdb;
    struct _MyGList *l = my_db->tracks;
    uint32_t c = 0;
    while(l) { c++; l = l->next; }
    *count = c;
    if (c == 0) return NULL;
    
    void **arr = malloc(c * sizeof(void*));
    l = my_db->tracks;
    c = 0;
    while(l) {
        arr[c++] = l->data;
        l = l->next;
    }
    return arr;
}

void gpod_free_track_array(void **arr) {
    if (arr) free(arr);
}

guint32 gpod_track_get_id_field(Itdb_Track *track) {
    if (!track) return 0;
    return track->id;
}

guint32 gpod_track_get_playcount_field(Itdb_Track *track) {
    if (!track) return 0;
    return track->playcount;
}

time_t gpod_track_get_time_played(Itdb_Track *track) {
    if (!track) return 0;
    return track->time_played;
}

const char* gpod_track_get_album_field(Itdb_Track *track) {
    if (!track) return NULL;
    return track->album;
}

const char* gpod_track_get_ipod_path(Itdb_Track *track) {
    if (!track) return NULL;
    return track->ipod_path;
}

void gpod_track_remove(Itdb_iTunesDB *itdb, Itdb_Track *track) {
    if (!itdb || !track) return;
    itdb_track_remove(track);
}

const char* gpod_track_get_title_field(Itdb_Track *track) {
    if (!track) return NULL;
    return track->title;
}

const char* gpod_track_get_artist_field(Itdb_Track *track) {
    if (!track) return NULL;
    return track->artist;
}

// ============================================================
// PodSync v2 additions
// ============================================================

// --- Extended track getters ---

const char* gpod_track_get_genre_field(Itdb_Track *track)       { return track ? track->genre : NULL; }
const char* gpod_track_get_albumartist_field(Itdb_Track *track) { return track ? track->albumartist : NULL; }
const char* gpod_track_get_composer_field(Itdb_Track *track)    { return track ? track->composer : NULL; }
const char* gpod_track_get_description_field(Itdb_Track *track) { return track ? track->description : NULL; }
const char* gpod_track_get_podcastrss_field(Itdb_Track *track)  { return track ? track->podcastrss : NULL; }
const char* gpod_track_get_podcasturl_field(Itdb_Track *track)  { return track ? track->podcasturl : NULL; }
const char* gpod_track_get_filetype_field(Itdb_Track *track)    { return track ? track->filetype : NULL; }
gint32  gpod_track_get_year(Itdb_Track *track)       { return track ? track->year : 0; }
gint32  gpod_track_get_track_nr(Itdb_Track *track)   { return track ? track->track_nr : 0; }
gint32  gpod_track_get_cd_nr(Itdb_Track *track)      { return track ? track->cd_nr : 0; }
gint32  gpod_track_get_tracklen(Itdb_Track *track)   { return track ? track->tracklen : 0; }
gint32  gpod_track_get_size_field(Itdb_Track *track) { return track ? track->size : 0; }
gint32  gpod_track_get_bitrate(Itdb_Track *track)    { return track ? track->bitrate : 0; }
guint32 gpod_track_get_rating(Itdb_Track *track)     { return track ? track->rating : 0; }
time_t  gpod_track_get_time_added(Itdb_Track *track)    { return track ? track->time_added : 0; }
time_t  gpod_track_get_time_released(Itdb_Track *track) { return track ? track->time_released : 0; }
guint8  gpod_track_get_mark_unplayed(Itdb_Track *track) { return track ? track->mark_unplayed : 0; }

// --- Extended track setters ---

static void gpod_replace_string(gchar **field, const char *value) {
    if (*field) free(*field);
    *field = value ? strdup(value) : NULL;
}

void gpod_track_set_genre(Itdb_Track *track, const char *genre) {
    if (!track) return;
    gpod_replace_string(&track->genre, genre);
}

void gpod_track_set_albumartist(Itdb_Track *track, const char *albumartist) {
    if (!track) return;
    gpod_replace_string(&track->albumartist, albumartist);
}

void gpod_track_set_composer(Itdb_Track *track, const char *composer) {
    if (!track) return;
    gpod_replace_string(&track->composer, composer);
}

void gpod_track_set_year(Itdb_Track *track, gint32 year)         { if (track) track->year = year; }
void gpod_track_set_track_nr(Itdb_Track *track, gint32 track_nr) { if (track) track->track_nr = track_nr; }
void gpod_track_set_cd_nr(Itdb_Track *track, gint32 cd_nr)       { if (track) track->cd_nr = cd_nr; }
void gpod_track_set_rating(Itdb_Track *track, guint32 rating)    { if (track) track->rating = rating; }

void gpod_track_set_podcast_meta(Itdb_Track *track,
                                 const char *podcasturl,
                                 const char *podcastrss,
                                 const char *description,
                                 const char *subtitle,
                                 time_t time_released,
                                 guint8 mark_unplayed) {
    if (!track) return;
    if (podcasturl)  gpod_replace_string(&track->podcasturl, podcasturl);
    if (podcastrss)  gpod_replace_string(&track->podcastrss, podcastrss);
    if (description) gpod_replace_string(&track->description, description);
    if (subtitle)    gpod_replace_string(&track->subtitle, subtitle);
    if (time_released > 0) track->time_released = time_released;
    track->mark_unplayed = mark_unplayed;
    track->remember_playback_position = 1;
    track->skip_when_shuffling = 1;
    track->flag4 = 1; // show Title/Album on podcast screen
}

// --- Playlist access ---
// Partial mirror of libgpod's Itdb_Playlist struct. Only the leading fields
// (up to podcastflag) are accessed; layout matches libgpod itdb.h.
struct _MyItdb_Playlist {
    Itdb_iTunesDB *itdb;
    gchar *name;
    guint8 type;
    guint8 flag1;
    guint8 flag2;
    guint8 flag3;
    gint  num;
    struct _MyGList *members;
    gboolean is_spl;
    time_t timestamp;
    guint64 id;
    guint32 sortorder;
    guint32 podcastflag;
    // ... SPL structs follow; never accessed here
};

// Mirror of Itdb_iTunesDB leading fields (tracks, playlists)
struct _MyItdb_iTunesDB2 {
    struct _MyGList *tracks;
    struct _MyGList *playlists;
};

void** gpod_get_playlists(Itdb_iTunesDB *itdb, uint32_t *count) {
    if (!itdb) { *count = 0; return NULL; }
    struct _MyItdb_iTunesDB2 *my_db = (struct _MyItdb_iTunesDB2 *)itdb;
    struct _MyGList *l = my_db->playlists;
    uint32_t c = 0;
    while (l) { c++; l = l->next; }
    *count = c;
    if (c == 0) return NULL;
    void **arr = malloc(c * sizeof(void*));
    l = my_db->playlists;
    c = 0;
    while (l) { arr[c++] = l->data; l = l->next; }
    return arr;
}

void gpod_free_playlist_array(void **arr) {
    if (arr) free(arr);
}

const char* gpod_playlist_get_name(Itdb_Playlist *pl) {
    if (!pl) return NULL;
    return ((struct _MyItdb_Playlist *)pl)->name;
}

guint64 gpod_playlist_get_id(Itdb_Playlist *pl) {
    if (!pl) return 0;
    return ((struct _MyItdb_Playlist *)pl)->id;
}

int gpod_playlist_is_master(Itdb_Playlist *pl) {
    if (!pl) return 0;
    return itdb_playlist_is_mpl(pl) ? 1 : 0;
}

int gpod_playlist_is_podcast_pl(Itdb_Playlist *pl) {
    if (!pl) return 0;
    return itdb_playlist_is_podcasts(pl) ? 1 : 0;
}

void gpod_playlist_set_name(Itdb_Playlist *pl, const char *name) {
    if (!pl || !name) return;
    struct _MyItdb_Playlist *mp = (struct _MyItdb_Playlist *)pl;
    if (mp->name) free(mp->name);
    mp->name = strdup(name);
}

void** gpod_playlist_get_tracks(Itdb_Playlist *pl, uint32_t *count) {
    if (!pl) { *count = 0; return NULL; }
    struct _MyItdb_Playlist *mp = (struct _MyItdb_Playlist *)pl;
    struct _MyGList *l = mp->members;
    uint32_t c = 0;
    while (l) { c++; l = l->next; }
    *count = c;
    if (c == 0) return NULL;
    void **arr = malloc(c * sizeof(void*));
    l = mp->members;
    c = 0;
    while (l) { arr[c++] = l->data; l = l->next; }
    return arr;
}
