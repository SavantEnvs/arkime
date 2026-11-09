#define _GNU_SOURCE
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Upstream's FUZZLOCH harness loads config.test.ini, parsers/ and plugins/ relative to tests/. Mayhem runs
 * the target from its own cwd, so enter the baked-in fuzz tests/ dir (next to this binary) before main.
 * Relative input/corpus/artifact arguments are made absolute first so they keep meaning the original cwd. */
static const char *path_flags[] = { "-artifact_prefix=", "-exact_artifact_path=", "-dict=", "-features_dir=",
                                    "-seed_inputs=", "-exit_on_src_pos=", "-cross_over_from=", NULL };

static char *absolutize(const char *cwd, const char *prefix, size_t plen, const char *path)
{
    size_t len = plen + strlen(cwd) + strlen(path) + 2;
    char *out = malloc(len);

    if (out)
        snprintf(out, len, "%.*s%s/%s", (int)plen, prefix, cwd, path);
    return out;
}

__attribute__((constructor)) static void arkime_fuzz_enter_tests_dir(int argc, char **argv)
{
    char exe[PATH_MAX], cwd[PATH_MAX], dir[PATH_MAX + 32];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
    char *slash;

    if (n <= 0 || !getcwd(cwd, sizeof(cwd)))
        return;
    exe[n] = 0;
    slash = strrchr(exe, '/');
    if (!slash)
        return;
    *slash = 0;

    for (int i = 1; i < argc; i++) {
        char *a = argv[i], *fixed = NULL;
        if (a[0] != '-') {
            if (a[0] != '/')
                fixed = absolutize(cwd, "", 0, a);
        } else {
            for (int f = 0; path_flags[f]; f++) {
                size_t plen = strlen(path_flags[f]);
                if (strncmp(a, path_flags[f], plen) == 0 && a[plen] != '/')
                    fixed = absolutize(cwd, a, plen, a + plen);
            }
        }
        if (fixed)
            argv[i] = fixed;
    }

    snprintf(dir, sizeof(dir), "%s/mayhem/build/fuzz/tests", exe);
    if (chdir(dir) != 0) {
        perror(dir);
        _exit(66);
    }
}
