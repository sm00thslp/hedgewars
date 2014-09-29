#ifndef FLIB_H
#define FLIB_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum MessageType {
    MSG_PREVIEW
};

typedef union string255_
    {
        struct {
            unsigned char s[256];
        };
        struct {
            unsigned char len;
            unsigned char str[255];
        };
    } string255;

typedef void RunEngine_t(int argc, const char ** argv);
typedef void registerGUIMessagesCallback_t(void * context, void (*)(void * context, MessageType mt, const char * msg, uint32_t len));
typedef void getPreview_t();
typedef void runQuickGame_t();
typedef void setSeed_t(const char * seed);
typedef char *getSeed_t();
typedef void flibInit_t(const char * localPrefix, const char * userPrefix);
typedef void flibFree_t();

typedef char **getThemesList_t();
typedef void freeThemesList_t(char **list);

#ifdef __cplusplus
}
#endif

#endif // FLIB_H
