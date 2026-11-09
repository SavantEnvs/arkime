# Extra make rules for the fuzz build (make -f Makefile -f fuzzloch.mk): build session.o and packet.o from the
# reset wrappers, which #include the unchanged upstream .c files. Same recipe as capture/Makefile's %.o rule.
session.o: $(MAYHEM_DIR)/session_reset.c session.c arkime.h hash.h dll.h bsb.h
	$(CC) -fno-strict-aliasing -pthread -fPIC -g -O2 $(EXTRA_CFLAGS) -Wall -Wextra -D_GNU_SOURCE -std=gnu99 -I. -c $< -o $@ \
            $(INCLUDE_PCAP) $(INCLUDE_OTHER) -DBUILD_VERSION='"$(BUILD_VERSION)"'

packet.o: $(MAYHEM_DIR)/packet_reset.c packet.c arkime.h hash.h dll.h bsb.h
	$(CC) -fno-strict-aliasing -pthread -fPIC -g -O2 $(EXTRA_CFLAGS) -Wall -Wextra -D_GNU_SOURCE -std=gnu99 -I. -c $< -o $@ \
            $(INCLUDE_PCAP) $(INCLUDE_OTHER) -DBUILD_VERSION='"$(BUILD_VERSION)"'

reader-scheme.o: $(MAYHEM_DIR)/scheme_reset.c reader-scheme.c arkime.h hash.h dll.h bsb.h
	$(CC) -fno-strict-aliasing -pthread -fPIC -g -O2 $(EXTRA_CFLAGS) -Wall -Wextra -D_GNU_SOURCE -std=gnu99 -I. -c $< -o $@ \
            $(INCLUDE_PCAP) $(INCLUDE_OTHER) -DBUILD_VERSION='"$(BUILD_VERSION)"'
