/* Compiled in place of capture/reader-scheme.c for the fuzz build (see build.sh). It includes the upstream file
 * unchanged and appends one function, so it can reach the file-local reader state. */
#include "reader-scheme.c"

/* Put the reader in the state arkime_reader_scheme_load_thread gives it before it reads a new file. */
void sfuzzloch_reset_reader(void)
{
    if (readerState.packet)
        arkime_packet_free(readerState.packet);
    memset(&readerState, 0, sizeof(readerState));
    readerState.state = ARKIME_SCHEME_FILEHEADER;
    readerState.fileHeaderLen = 24;
    readerState.haveInterface = -1;
}
