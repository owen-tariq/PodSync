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
    track->visible = 1;
    track->mediatype = 1; // 1 = Audio
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
