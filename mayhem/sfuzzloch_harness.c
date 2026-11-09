#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Upstream's SFUZZLOCH harness (capture/main.c), renamed at compile time with -DLLVMFuzzerTestOneInput=...:
 * it hands its whole input to the scheme reader as one read. */
int sfuzzloch_upstream_one_input(const uint8_t *data, size_t size);
void sfuzzloch_reset_reader(void);
void fuzzloch_reset_sessions(void);
void fuzzloch_reset_fragments(void);

static void feed(const uint8_t *data, size_t size)
{
    if (size == 0)
        return;
    /* an exact-size heap copy, so reads past the chunk are caught */
    uint8_t *copy = malloc(size);
    memcpy(copy, data, size);
    sfuzzloch_upstream_one_input(copy, size);
    free(copy);
}

/* A capture file reaches the scheme reader in reads of any size. The reader's state is global and upstream's
 * harness never resets it, so one input would depend on the ones before it. Here the reader starts fresh for
 * every input, and the input is delivered as two reads: bytes 0-1 (big endian, modulo the rest + 1) say where
 * the first read ends, so a block header can span the boundary between reads. */
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    if (size < 2)
        return 0;
    size_t rest = size - 2;
    size_t split = (((size_t)data[0] << 8) | data[1]) % (rest + 1);
    data += 2;

    sfuzzloch_reset_reader();
    feed(data, split);
    feed(data + split, rest - split);

    sfuzzloch_reset_reader();
    fuzzloch_reset_sessions();
    fuzzloch_reset_fragments();
    return 0;
}
