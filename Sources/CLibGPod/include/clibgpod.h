// CLibGPod - Bridging header for libgpod
// This provides Swift access to the libgpod C functions for iPod database management.

#ifndef CLIBGPOD_H
#define CLIBGPOD_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

// Forward declarations for GLib types that libgpod depends on
typedef void* GList;
typedef void* GTree;
typedef uint32_t GQuark;
typedef char gchar;
typedef int gint;
typedef unsigned int guint;
typedef int32_t gint32;
typedef uint32_t guint32;
typedef int64_t gint64;
typedef uint64_t guint64;
typedef int gboolean;
typedef uint16_t guint16;

struct _GError {
    GQuark domain;
    gint code;
    gchar *message;
};
typedef struct _GError GError;
typedef int16_t gint16;
typedef uint8_t guint8;
typedef float gfloat;
typedef double gdouble;
typedef unsigned long gulong;
typedef void* gpointer;

// iPod device info
typedef enum {
    ITDB_IPOD_MODEL_INVALID,
    ITDB_IPOD_MODEL_UNKNOWN,
    ITDB_IPOD_MODEL_COLOR,
    ITDB_IPOD_MODEL_COLOR_U2,
    ITDB_IPOD_MODEL_REGULAR,
    ITDB_IPOD_MODEL_REGULAR_U2,
    ITDB_IPOD_MODEL_MINI,
    ITDB_IPOD_MODEL_MINI_BLUE,
    ITDB_IPOD_MODEL_MINI_PINK,
    ITDB_IPOD_MODEL_MINI_GREEN,
    ITDB_IPOD_MODEL_MINI_GOLD,
    ITDB_IPOD_MODEL_SHUFFLE,
    ITDB_IPOD_MODEL_NANO_WHITE,
    ITDB_IPOD_MODEL_NANO_BLACK,
    ITDB_IPOD_MODEL_VIDEO_WHITE,
    ITDB_IPOD_MODEL_VIDEO_BLACK,
    ITDB_IPOD_MODEL_VIDEO_U2,
    ITDB_IPOD_MODEL_CLASSIC_SILVER,
    ITDB_IPOD_MODEL_CLASSIC_BLACK
} Itdb_IpodModel;

typedef enum {
    ITDB_IPOD_GENERATION_UNKNOWN,
    ITDB_IPOD_GENERATION_FIRST,
    ITDB_IPOD_GENERATION_SECOND,
    ITDB_IPOD_GENERATION_THIRD,
    ITDB_IPOD_GENERATION_FOURTH,
    ITDB_IPOD_GENERATION_PHOTO,
    ITDB_IPOD_GENERATION_MOBILE,
    ITDB_IPOD_GENERATION_MINI_1,
    ITDB_IPOD_GENERATION_MINI_2,
    ITDB_IPOD_GENERATION_SHUFFLE_1,
    ITDB_IPOD_GENERATION_SHUFFLE_2,
    ITDB_IPOD_GENERATION_SHUFFLE_3,
    ITDB_IPOD_GENERATION_SHUFFLE_4,
    ITDB_IPOD_GENERATION_NANO_1,
    ITDB_IPOD_GENERATION_NANO_2,
    ITDB_IPOD_GENERATION_NANO_3,
    ITDB_IPOD_GENERATION_NANO_4,
    ITDB_IPOD_GENERATION_NANO_5,
    ITDB_IPOD_GENERATION_NANO_6,
    ITDB_IPOD_GENERATION_NANO_7,
    ITDB_IPOD_GENERATION_VIDEO_1,
    ITDB_IPOD_GENERATION_VIDEO_2,
    ITDB_IPOD_GENERATION_CLASSIC_1,
    ITDB_IPOD_GENERATION_CLASSIC_2,
    ITDB_IPOD_GENERATION_CLASSIC_3,
    ITDB_IPOD_GENERATION_TOUCH_1,
    ITDB_IPOD_GENERATION_TOUCH_2,
    ITDB_IPOD_GENERATION_TOUCH_3,
    ITDB_IPOD_GENERATION_TOUCH_4,
    ITDB_IPOD_GENERATION_IPHONE_1,
    ITDB_IPOD_GENERATION_IPHONE_2,
    ITDB_IPOD_GENERATION_IPHONE_3,
    ITDB_IPOD_GENERATION_IPHONE_4
} Itdb_IpodGeneration;

typedef struct {
    Itdb_IpodModel ipod_model;
    Itdb_IpodGeneration ipod_generation;
    const char *model_number;
    guint32 capacity;
} Itdb_IpodInfo;

// Opaque struct declarations - these match the libgpod internal structures
typedef struct _Itdb_Device Itdb_Device;
typedef struct _Itdb_iTunesDB Itdb_iTunesDB;
typedef struct _Itdb_Playlist Itdb_Playlist;
typedef struct _Itdb_Track Itdb_Track;
typedef struct _Itdb_Artwork Itdb_Artwork;
typedef struct _Itdb_Chapterdata Itdb_Chapterdata;
typedef struct _Itdb_Track_Private Itdb_Track_Private;

extern char* g_strdup(const char *str);

extern void gpod_track_set_title(Itdb_Track *track, const char *title);
extern void gpod_track_set_artist(Itdb_Track *track, const char *artist);
extern void gpod_track_set_album(Itdb_Track *track, const char *album);
extern void gpod_track_set_artwork_from_data(Itdb_Track *track, const void *data, size_t length);
extern int itdb_track_set_thumbnails(Itdb_Track *track, const char *filename);
extern void gpod_ensure_sysinfo_artwork_formats(Itdb_iTunesDB *itdb);
extern void gpod_ensure_hash_info(Itdb_iTunesDB *itdb);
extern void gpod_track_set_extended_info(Itdb_Track *track, gint32 tracklen, gint32 size, gint32 year, gint32 track_nr, gint32 cd_nr);

extern void** gpod_get_all_tracks(Itdb_iTunesDB *itdb, uint32_t *count);
extern void gpod_free_track_array(void **arr);
extern guint32 gpod_track_get_id_field(Itdb_Track *track);
extern guint32 gpod_track_get_playcount_field(Itdb_Track *track);
extern time_t gpod_track_get_time_played(Itdb_Track *track);
extern const char* gpod_track_get_title_field(Itdb_Track *track);
extern const char* gpod_track_get_artist_field(Itdb_Track *track);
extern const char* gpod_track_get_album_field(Itdb_Track *track);
extern const char* gpod_track_get_ipod_path(Itdb_Track *track);
extern void gpod_track_remove(Itdb_iTunesDB *itdb, Itdb_Track *track);

extern Itdb_Playlist* itdb_playlist_new(const char *name, gboolean is_master);
extern void itdb_playlist_set_mpl(Itdb_Playlist *pl);
extern void itdb_playlist_add(Itdb_iTunesDB *itdb, Itdb_Playlist *pl, gint32 pos);

extern Itdb_Playlist* itdb_playlist_mpl(Itdb_iTunesDB *itdb);
extern void itdb_playlist_add_track(Itdb_Playlist *pl, Itdb_Track *track, gint32 pos);

extern void itdb_set_mountpoint(Itdb_iTunesDB *itdb, const char *mp);
typedef struct _Itdb_Artwork Itdb_Artwork;

// ============================================================
// Core Database Functions
// ============================================================

// Create/Parse/Write/Free database
extern Itdb_iTunesDB* itdb_new(void);
extern Itdb_iTunesDB* itdb_parse(const char *mp, GError **error);
extern gboolean itdb_write(Itdb_iTunesDB *itdb, GError **error);
extern void itdb_free(Itdb_iTunesDB *itdb);
extern Itdb_iTunesDB* itdb_duplicate(Itdb_iTunesDB *itdb);

// Initialize iPod directory structure
extern gboolean itdb_init_ipod(const char *mountpoint,
                                const char *model_number,
                                const char *ipod_name,
                                GError **error);

// ============================================================
// Track Functions
// ============================================================

extern Itdb_Track* itdb_track_new(void);
extern void itdb_track_free(Itdb_Track *track);
extern void itdb_track_add(Itdb_iTunesDB *itdb, Itdb_Track *track, gint32 pos);
extern void itdb_track_remove(Itdb_Track *track);
extern Itdb_Track* itdb_track_duplicate(Itdb_Track *track);
extern Itdb_Track* itdb_track_by_id(Itdb_iTunesDB *itdb, guint32 id);
extern gboolean itdb_cp_track_to_ipod(Itdb_Track *track,
                                       const char *filename,
                                       GError **error);

// ============================================================
// Playlist Functions
// ============================================================

extern Itdb_Playlist* itdb_playlist_new(const char *title, gboolean spl);
extern void itdb_playlist_free(Itdb_Playlist *pl);
extern void itdb_playlist_add(Itdb_iTunesDB *itdb, Itdb_Playlist *pl, gint32 pos);
extern void itdb_playlist_add_track(Itdb_Playlist *pl, Itdb_Track *track, gint32 pos);
extern void itdb_playlist_remove_track(Itdb_Playlist *pl, Itdb_Track *track);
extern Itdb_Playlist* itdb_playlist_mpl(Itdb_iTunesDB *itdb);
extern Itdb_Playlist* itdb_playlist_by_id(Itdb_iTunesDB *itdb, guint64 id);
extern Itdb_Playlist* itdb_playlist_by_name(Itdb_iTunesDB *itdb, char *name);
extern gboolean itdb_playlist_contains_track(Itdb_Playlist *pl, Itdb_Track *track);
extern guint32 itdb_playlist_tracks_number(Itdb_Playlist *pl);

// ============================================================
// Device Functions
// ============================================================

extern Itdb_Device* itdb_device_new(void);
extern void itdb_device_free(Itdb_Device *device);
extern void itdb_device_set_mountpoint(Itdb_Device *device, const char *mp);
extern const Itdb_IpodInfo* itdb_device_get_ipod_info(Itdb_Device *device);
extern gboolean itdb_device_supports_artwork(Itdb_Device *device);
extern gboolean itdb_device_supports_video(Itdb_Device *device);
extern gboolean itdb_device_supports_photo(Itdb_Device *device);
extern gboolean itdb_device_supports_podcast(Itdb_Device *device);

// ============================================================
// Artwork Functions
// ============================================================

extern Itdb_Artwork* itdb_artwork_new(void);
extern void itdb_artwork_free(Itdb_Artwork *artwork);
extern gboolean itdb_artwork_set_thumbnail(Itdb_Artwork *artwork,
                                            const char *filename,
                                            gint rotation,
                                            GError **error);

#endif /* CLIBGPOD_H */
