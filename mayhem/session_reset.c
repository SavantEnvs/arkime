/* Compiled in place of capture/session.c for the fuzz build (see build.sh). It includes the upstream file
 * unchanged and appends one function, so it can reach the file-local session tables. */
#include "session.c"

/* Close every session of every packet thread, through upstream's own flush path. */
void fuzzloch_reset_sessions(void)
{
    for (int t = 0; t < config.packetThreads; t++) {
        // Commands hold session pointers: run them before the sessions are freed
        while (DLL_COUNT(cmd_, &sessionThreadData[t].sessionCmds) > 0)
            arkime_session_process_commands(t);
        arkime_session_flush_close(NULL, GINT_TO_POINTER(t), NULL);
    }
}
