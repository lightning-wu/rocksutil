CLEAN_FILES = # deliberately empty, so we can append below.
CFLAGS += ${EXTRA_CFLAGS}
CXXFLAGS += ${EXTRA_CXXFLAGS}
LDFLAGS += $(EXTRA_LDFLAGS)
ARFLAGS = rs
OPT=

# Set the default DEBUG_LEVEL to 1
DEBUG_LEVEL?=0

ifeq ($(MAKECMDGOALS),dbg)
  DEBUG_LEVEL=2
endif

ifeq ($(MAKECMDGOALS),all)
  DEBUG_LEVEL=0
endif

ifeq ($(MAKECMDGOALS),clean)
  DEBUG_LEVEL=0
endif

ifeq ($(MAKECMDGOALS),shared_lib)
  DEBUG_LEVEL=0
endif

ifeq ($(MAKECMDGOALS),static_lib)
  DEBUG_LEVEL=0
endif

# compile with -O2 if debug level is not 2
ifneq ($(DEBUG_LEVEL), 2)
OPT += -O2 -fno-omit-frame-pointer
# Skip for archs that don't support -momit-leaf-frame-pointer
ifeq (,$(shell $(CXX) -fsyntax-only -momit-leaf-frame-pointer -xc /dev/null 2>&1))
OPT += -momit-leaf-frame-pointer
endif
endif

# if we're compiling for release, compile without debug code (-DNDEBUG) and
# don't treat warnings as errors
ifeq ($(DEBUG_LEVEL),0)
OPT += -DNDEBUG
DISABLE_WARNING_AS_ERROR=1
else
$(warning Warning: Compiling in debug mode. Don't use the resulting binary in production)
endif

#-----------------------------------------------

include ./src.mk

AM_DEFAULT_VERBOSITY = 0

AM_V_GEN = $(am__v_GEN_$(V))
am__v_GEN_ = $(am__v_GEN_$(AM_DEFAULT_VERBOSITY))
am__v_GEN_0 = @echo "  GEN     " $@;
am__v_GEN_1 =
AM_V_at = $(am__v_at_$(V))
am__v_at_ = $(am__v_at_$(AM_DEFAULT_VERBOSITY))
am__v_at_0 = @
am__v_at_1 =

AM_V_CC = $(am__v_CC_$(V))
am__v_CC_ = $(am__v_CC_$(AM_DEFAULT_VERBOSITY))
am__v_CC_0 = @echo "  CC      " $@;
am__v_CC_1 =
CCLD = $(CC)
LINK = $(CCLD) $(AM_CFLAGS) $(CFLAGS) $(AM_LDFLAGS) $(LDFLAGS) -o $@
AM_V_CCLD = $(am__v_CCLD_$(V))
am__v_CCLD_ = $(am__v_CCLD_$(AM_DEFAULT_VERBOSITY))
am__v_CCLD_0 = @echo "  CCLD    " $@;
am__v_CCLD_1 =
AM_V_AR = $(am__v_AR_$(V))
am__v_AR_ = $(am__v_AR_$(AM_DEFAULT_VERBOSITY))
am__v_AR_0 = @echo "  AR      " $@;
am__v_AR_1 =

AM_LINK = $(AM_V_CCLD)$(CXX) $^ $(EXEC_LDFLAGS) -o $@ $(LDFLAGS) $(COVERAGEFLAGS)
# detect what platform we're building on
dummy := $(shell (export ROCKSUTIL_ROOT="$(CURDIR)"; "$(CURDIR)/build_detect_platform" "$(CURDIR)/make_config.mk"))
# this file is generated by the previous line to set build flags and sources
include make_config.mk
CLEAN_FILES += make_config.mk

missing_make_config_paths := $(shell        \
  grep "\/\S*" -o $(CURDIR)/make_config.mk |    \
  while read path;          \
    do [ -e $$path ] || echo $$path;    \
  done | sort | uniq)

$(foreach path, $(missing_make_config_paths), \
  $(warning Warning: $(path) dont exist))

ifneq ($(PLATFORM), IOS)
CFLAGS += -g
CXXFLAGS += -g
else
# no debug info for IOS, that will make our library big
OPT += -DNDEBUG
endif

ifeq ($(PLATFORM), OS_SOLARIS)
  PLATFORM_CXXFLAGS += -D _GLIBCXX_USE_C99
endif

# This (the first rule) must depend on "all".
default: all

WARNING_FLAGS = -W -Wextra -Wall -Wsign-compare -Wshadow \
  -Wno-unused-parameter

ifndef DISABLE_WARNING_AS_ERROR
  WARNING_FLAGS += -Werror
endif

CFLAGS += $(WARNING_FLAGS) -I. -I./include $(PLATFORM_CCFLAGS) $(OPT)
CXXFLAGS += $(WARNING_FLAGS) -I. -I./include $(PLATFORM_CXXFLAGS) $(OPT) -Woverloaded-virtual -Wnon-virtual-dtor -Wno-missing-field-initializers

LDFLAGS += $(PLATFORM_LDFLAGS)

date := $(shell date +%F)
git_sha := $(shell git rev-parse HEAD 2>/dev/null)
gen_build_version = sed -e s/@@GIT_SHA@@/$(git_sha)/ -e s/@@GIT_DATE_TIME@@/$(date)/ util/build_version.cc.in
# Record the version of the source that we are compiling.
# We keep a record of the git revision in this file.  It is then built
# as a regular source file as part of the compilation process.
# One can run "strings executable_filename | grep _build_" to find
# the version of the source that we used to build the executable file.
CLEAN_FILES += util/build_version.cc

util/build_version.cc: FORCE
	$(AM_V_GEN)rm -f $@-t
	$(AM_V_at)$(gen_build_version) > $@-t
	$(AM_V_at)if test -f $@; then         \
	  cmp -s $@-t $@ && rm -f $@-t || mv -f $@-t $@;    \
	else mv -f $@-t $@; fi
FORCE: 

LIBOBJECTS = $(LIB_SOURCES:.cc=.o)

# if user didn't config LIBNAME, set the default
ifeq ($(LIBNAME),)
# we should only run rocksutil in production with DEBUG_LEVEL 0
ifeq ($(DEBUG_LEVEL),0)
        LIBNAME=librocksutil
else
        LIBNAME=librocksutil_debug
endif
endif
LIBRARY = ${LIBNAME}.a

ROCKSUTIL_MAJOR = $(shell egrep "ROCKSUTIL_MAJOR.[0-9]" include/rocksutil/version.h | cut -d ' ' -f 3)
ROCKSUTIL_MINOR = $(shell egrep "ROCKSUTIL_MINOR.[0-9]" include/rocksutil/version.h | cut -d ' ' -f 3)
ROCKSUTIL_PATCH = $(shell egrep "ROCKSUTIL_PATCH.[0-9]" include/rocksutil/version.h | cut -d ' ' -f 3)

#-----------------------------------------------
# Create platform independent shared libraries.
#-----------------------------------------------
ifneq ($(PLATFORM_SHARED_EXT),)

ifneq ($(PLATFORM_SHARED_VERSIONED),true)
SHARED1 = ${LIBNAME}.$(PLATFORM_SHARED_EXT)
SHARED2 = $(SHARED1)
SHARED3 = $(SHARED1)
SHARED4 = $(SHARED1)
SHARED = $(SHARED1)
else
SHARED_MAJOR = $(ROCKSUTIL_MAJOR)
SHARED_MINOR = $(ROCKSUTIL_MINOR)
SHARED_PATCH = $(ROCKSUTIL_PATCH)
SHARED1 = ${LIBNAME}.$(PLATFORM_SHARED_EXT)
ifeq ($(PLATFORM), OS_MACOSX)
SHARED_OSX = $(LIBNAME).$(SHARED_MAJOR)
SHARED2 = $(SHARED_OSX).$(PLATFORM_SHARED_EXT)
SHARED3 = $(SHARED_OSX).$(SHARED_MINOR).$(PLATFORM_SHARED_EXT)
SHARED4 = $(SHARED_OSX).$(SHARED_MINOR).$(SHARED_PATCH).$(PLATFORM_SHARED_EXT)
else
SHARED2 = $(SHARED1).$(SHARED_MAJOR)
SHARED3 = $(SHARED1).$(SHARED_MAJOR).$(SHARED_MINOR)
SHARED4 = $(SHARED1).$(SHARED_MAJOR).$(SHARED_MINOR).$(SHARED_PATCH)
endif
SHARED = $(SHARED1) $(SHARED2) $(SHARED3) $(SHARED4)
$(SHARED1): $(SHARED4)
	ln -fs $(SHARED4) $(SHARED1)
$(SHARED2): $(SHARED4)
	ln -fs $(SHARED4) $(SHARED2)
$(SHARED3): $(SHARED4)
	ln -fs $(SHARED4) $(SHARED3)
endif

$(SHARED4): $(LIBOBJECTS)
	$(CXX) $(PLATFORM_SHARED_LDFLAGS)$(SHARED3) $(CXXFLAGS) $(PLATFORM_SHARED_CFLAGS) $(LIB_SOURCES) \
    $(LDFLAGS) -o $@

endif  # PLATFORM_SHARED_EXT

.PHONY: clean tags dbg static_lib shared_lib all

EXAMPLES = log_example thread_local_example mutexlock_example thread_pool_example lru_cache_example \
					 file_reader_writer_example wal_example

all: $(LIBRARY)

static_lib: $(LIBRARY)

shared_lib: $(SHARED)

example: $(EXAMPLES)

dbg: $(LIBRARY) $(EXAMPLES)

$(LIBRARY): $(LIBOBJECTS)
	$(AM_V_AR)rm -f $@
	$(AM_V_at)$(AR) $(ARFLAGS) $@ $(LIBOBJECTS)

log_example: examples/log_example.o $(LIBOBJECTS)
	$(AM_LINK)

thread_local_example: examples/thread_local_example.o $(LIBOBJECTS)
	$(AM_LINK)

mutexlock_example: examples/mutexlock_example.o $(LIBOBJECTS)
	$(AM_LINK)

thread_pool_example: examples/thread_pool_example.o $(LIBOBJECTS)
	$(AM_LINK)

lru_cache_example: examples/lru_cache_example.o $(LIBOBJECTS)
	$(AM_LINK)

file_reader_writer_example: examples/file_reader_writer_example.o $(LIBOBJECTS)
	$(AM_LINK)

wal_example: examples/wal_example.o $(LIBOBJECTS)
	$(AM_LINK)

clean:
	make -C ./examples clean
	rm -f $(EXAMPLES) $(LIBRARY) $(SHARED)
	rm -rf $(CLEAN_FILES) ios-x86 ios-arm
	find . -name "*.[oda]" -exec rm -f {} \;
	find . -type f -regex ".*\.\(\(gcda\)\|\(gcno\)\)" -exec rm {} \;
