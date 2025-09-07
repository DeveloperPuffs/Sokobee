/*
#include "Assets.h"

#include <stdlib.h>
#include <stdbool.h>

#include "Utilities.h"
#include "cJSON.h"

static bool load_levels(const cJSON *const json);
static void unload_levels(void);

bool load_assets(const char *const path) {
        send_message(MESSAGE_INFORMATION, "Assets data file to load: \"%s\"", path);
        char *const json_string = load_text_file(path);
        if (!json_string) {
                send_message(MESSAGE_ERROR, "Failed to load assets: Failed to load data file");
                return false;
        }

        cJSON *const json = cJSON_Parse(json_string);
        xfree(json_string);
        if (!json) {
                send_message(MESSAGE_ERROR, "Failed to load assets: Failed to parse \"%s\" as JSON data: %s", path, cJSON_GetErrorPtr());
                return false;
        }

        if (!load_levels((const void *)cJSON_GetObjectItemCaseSensitive(json, "levels"))) {
                send_message(MESSAGE_ERROR, "Failed to load assets: Failed to load levels");
                cJSON_Delete(json);
                unload_assets();
                return false;
        }

        cJSON_Delete(json);
        return true;
}

void unload_assets(void) {
        unload_levels();
}

static struct LevelMetadata *level_metadatas = NULL;
static size_t level_metadata_count = 0ULL;

size_t get_level_count(void) {
        return level_metadata_count;
}

const struct LevelMetadata *get_level_metadata(const size_t level) {
        if (!level || level > level_metadata_count) {
                return NULL;
        }

        return &level_metadatas[level - 1ULL];
}

static bool load_levels(const cJSON *const json) {
        if (!cJSON_IsArray(json)) {
                send_message(MESSAGE_ERROR, "Failed to load levels: JSON data is invalid");
                return false;
        }

        level_metadata_count = (size_t)cJSON_GetArraySize(json);
        level_metadatas = (struct LevelMetadata *)xmalloc(level_metadata_count * sizeof(struct LevelMetadata));

        size_t level_metadata_index = 0ULL;
        const cJSON *level_metadata_json = NULL;
        cJSON_ArrayForEach(level_metadata_json, json) {
                if (!cJSON_IsObject(level_metadata_json)) {
                        send_message(MESSAGE_ERROR, "Failed to load levels: JSON data is invalid");
                        return false;
                }

                const cJSON *const title = cJSON_GetObjectItemCaseSensitive(level_metadata_json, "title");
                const cJSON *const path = cJSON_GetObjectItemCaseSensitive(level_metadata_json, "path");

                if (!cJSON_IsString(title) || !cJSON_IsString(path)) {
                        send_message(MESSAGE_ERROR, "Failed to load levels: JSON data is invalid");
                        return false;
                }

                struct LevelMetadata *const level_metadata = &level_metadatas[level_metadata_index++];
                level_metadata->title = xstrdup(title->valuestring);
                level_metadata->path  = xstrdup(path->valuestring);
        }

        return true;
}

static void unload_levels(void) {
        if (!level_metadata_count) {
                return;
        }

        for (size_t level_metadata_index = 0ULL; level_metadata_index < level_metadata_count; ++level_metadata_index) {
                xfree(level_metadatas[level_metadata_index].title);
                xfree(level_metadatas[level_metadata_index].path);
        }

        xfree(level_metadatas);
}
*/