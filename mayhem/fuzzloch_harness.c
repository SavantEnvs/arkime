#include <stddef.h>
#include <stdint.h>

/* Upstream's FUZZLOCH harness (capture/main.c), renamed at compile time with -DLLVMFuzzerTestOneInput=... */
int fuzzloch_upstream_one_input(const uint8_t *data, size_t size);
void fuzzloch_reset_sessions(void);
void fuzzloch_reset_fragments(void);

/* Runs upstream's per-input function, then closes every session and drops every pending fragment, so the
 * next input starts from the same pipeline state and a crash reproduces from its input file alone. */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    int rc = fuzzloch_upstream_one_input(data, size);

    fuzzloch_reset_sessions();
    fuzzloch_reset_fragments();
    return rc;
}
