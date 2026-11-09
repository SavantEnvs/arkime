/* Compiled in place of capture/packet.c for the fuzz build (see build.sh). It includes the upstream file
 * unchanged and appends one function, so it can reach the file-local IP fragment table. */
#include "packet.c"

/* Drop every pending IPv4 fragment. Upstream only expires them when a later fragment arrives with a
 * timestamp more than fragsTimeout ahead, so fragments of one input would otherwise pair with the next. */
void fuzzloch_reset_fragments(void)
{
    ArkimeFrags_t *f;

    ARKIME_LOCK(frags);
    while ((f = DLL_PEEK_HEAD(fragl_, &fragsList)))
        arkime_packet_frags_free(f);
    ARKIME_UNLOCK(frags);
}
