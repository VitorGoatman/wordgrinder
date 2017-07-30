hide = @

PREFIX ?= $(HOME)
BINDIR ?= $(PREFIX)/bin
DOCDIR ?= $(PREFIX)/share/doc
MANDIR ?= $(PREFIX)/share/man
DESTDIR ?=

# Where do the temporary files go?
OBJDIR = /tmp/wg-build

# The compiler used for the native build (curses, X11)
CC ?= gcc

# Used for the Windows build (either cross or native)
WINCC ?= i686-w64-mingw32-gcc
WINDRES ?= i686-w64-mingw32-windres
MAKENSIS ?= makensis
ifneq ($(strip $(shell type $(MAKENSIS) >/dev/null 2>&1; echo $$?)),0)
	# If makensis isn't on the path, chances are we're on Cygwin doing a
	# Windows build --- so look in the default installation directory.
	MAKENSIS := /cygdrive/c/Program\ Files\ \(x86\)/NSIS/makensis.exe
endif

# For native builds only, which Lua do you want to use? This affects
# only which one gets installed. The Windows build always uses the
# internal Lua.
#
# Choices are: internallua, a pkg-config name, or a flag spec like:
# --cflags={-I/usr/include/thingylua} --libs={-L/usr/lib/thingylua -lthingylua}
LUA_PACKAGE := lua-5.2

# For native builds only,
VERSION := 0.7.0
FILEFORMAT := 7
DATE := $(shell date +'%-d %B %Y')

LUA_INTERPRETER = $(OBJDIR)/lua

# Hack to try and detect OSX's non-pkg-config compliant ncurses.
ifneq ($(Apple_PubSub_Socket_Render),)
	CURSES_PACKAGE := --cflags={-I/usr/include} --libs={-L/usr/lib -lncurses}
else
	CURSES_PACKAGE := ncursesw
endif

NINJABUILD = \
	$(hide) ninja -f $(OBJDIR)/build.ninja $(NINJAFLAGS)

# Builds and tests the Unix release versions only.
.PHONY: all
all: $(OBJDIR)/build.ninja
	$(NINJABUILD) all

# Builds, tests and installs the Unix release versions only.
.PHONY: install
install: $(OBJDIR)/build.ninja
	$(NINJABUILD) install

# Builds and tests everything.
.PHONY: dev
dev: $(OBJDIR)/build.ninja
	$(NINJABUILD) dev

# Builds Windows (but doesn't test it).
.PHONY: windows
windows: $(OBJDIR)/build.ninja
	$(NINJABUILD) bin/WordGrinder-$(VERSION)-setup.exe

$(OBJDIR)/build.ninja:: $(LUA_INTERPRETER) build.lua Makefile
	@mkdir -p $(dir $@)
	$(hide) $(LUA_INTERPRETER) build.lua \
		BINDIR="$(BINDIR)" \
		BUILDFILE="$@" \
		CC="$(CC)" \
		CURSES_PACKAGE="$(CURSES_PACKAGE)" \
		DATE="$(DATE)" \
		DESTDIR="$(DESTDIR)" \
		DOCDIR="$(DOCDIR)" \
		FILEFORMAT="$(FILEFORMAT)" \
		LUA_INTERPRETER="$(LUA_INTERPRETER)" \
		LUA_PACKAGE="$(LUA_PACKAGE)" \
		MAKENSIS="$(MAKENSIS)" \
		MANDIR="$(MANDIR)" \
		OBJDIR="$(OBJDIR)" \
		VERSION="$(VERSION)" \
		WINCC="$(WINCC)" \
		WINDRES="$(WINDRES)" \

clean:
	@echo CLEAN
	@rm -rf $(OBJDIR)

$(LUA_INTERPRETER): src/c/emu/lua-5.1.5/*.[ch]
	@echo Bootstrapping build
	@mkdir -p $(dir $@)
	@$(CC) -o $(LUA_INTERPRETER) -O src/c/emu/lua-5.1.5/*.c -lm -DLUA_USE_MKSTEMP
