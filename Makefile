# Generic Makefile, by Blaise Lengrand

# Usefull predefined
MINIFY_JS_FLAGS_HARDCORE := \
	--compress sequences=true,dead_code=true,conditionals=true,booleans=true,unused=true,if_return=true,join_vars=true,drop_console=true \
	--mangle toplevel=true,eval=true \
	--lint -v

-include config.mk

# Prevent makefile auto-clean
.SECONDARY:
# Use of rule-specific variables
.SECONDEXPANSION:
.PHONY: all silent verbose help build rebuild release

# List all available targets
ALL_RULES := $(shell test -s config.mk && cat config.mk | grep -e '^process[-_]\|^copy[-_]\|^concat[-_]' |  awk -F':' '{print $$1}' | uniq)
ifeq ("$(wildcard config.mk)","")
ALL_MAKEFILES := Makefile
else
ALL_MAKEFILES := Makefile config.mk
endif

# Default values
PACKAGE ?= package.zip
STAMP_TXT ?= $(OUTPUT) (`date +'%Y.%m.%d'`)
VERBOSE ?= 1
COMPACT_MODE ?= 1
BUILDDIR ?= .make
DISTDIR ?= dist
INPUT ?= 
OUTPUT ?= 
MAKEFILE_ADDRESS := https://raw.githubusercontent.com/blaizard/Makefile/master/Makefile

# Commands
PRINT_CMD ?= printf
MINIFY_JS_CMD ?= uglifyjs
MINIFY_CSS_CMD ?= uglifycss
SASS_CMD ?= sass
SCSS_CMD ?= sass
CONCAT_CMD ?= cat
MKDIR_CMD ?= mkdir
RMDIR_CMD ?= rm
COPY_CMD ?= cp
PACK_CMD ?= zip
CD_CMD ?= cd
WGET_CMD ?= wget

# Flags
PRINT_FLAGS ?=
MINIFY_JS_FLAGS ?= --compress --mangle -v --lint
MINIFY_CSS_FLAGS ?=
SASS_FLAGS ?= --sourcemap=none --unix-newlines
SCSS_FLAGS ?= --sourcemap=none --unix-newlines --scss
CONCAT_FLAGS ?=
MKDIR_FLAGS ?= -p
RMDIR_FLAGS ?= -rfd
COPY_FLAGS ?= -R
PACK_FLAGS ?= -o -r
CD_FLAGS :=
WGET_FLAGS := --no-check-certificate -q

# Available colors
COLOR_END := $(shell printf "\033[0m")
COLOR_RED := $(shell printf "\033[0;31m")
COLOR_YELLOW := $(shell printf "\033[0;33m")
COLOR_GREEN := $(shell printf "\033[0;32m")
COLOR_BLUE := $(shell printf "\033[0;34m")
COLOR_ORANGE := $(shell printf "\033[0;33m")
COLOR_DARK_GRAY := $(shell printf "\033[1;30m")
COLOR_CYAN := $(shell printf "\033[0;36m")
COLOR_LIGHT_BLUE := $(shell printf "\033[0;94m")

# Command update helpers
PRINT_V0 := :
PRINT_V1 := $(PRINT_CMD) $(PRINT_FLAGS)
PRINT_V2 := $(PRINT_V1)
PRINT = $(PRINT_V$(VERBOSE))
AT_V0 := @
AT_V1 := @
AT_V2 :=  
AT = $(AT_V$(VERBOSE))
COMMA := ,
PWD := $(shell pwd)
CLEAR_LINE := $(shell printf "\r\033[K")
OUTPUT_LIST :=

# Useful commands
define MINIFY_JS
@$(call MSG,MINJS,GREEN,$1);
$(AT)$(MINIFY_JS_CMD) $(MINIFY_JS_FLAGS) -o $2 $1 2>&1 | $(call PIPE_FORMAT)
endef
define MINIFY_CSS
@$(call MSG,MINCSS,GREEN,$1);
$(AT)$(MINIFY_CSS_CMD) $(MINIFY_CSS_FLAGS) $1 > $2 2>&1 | $(call PIPE_FORMAT)
endef
define SASS
@$(call MSG,SASS,GREEN,$1);
$(AT)$(SASS_CMD) $(SASS_FLAGS) $1 $2 2>&1 | $(call PIPE_FORMAT)
endef
define SCSS
@$(call MSG,SCSS,GREEN,$1);
$(AT)$(SCSS_CMD) $(SCSS_FLAGS) $1 $2 2>&1 | $(call PIPE_FORMAT)
endef
define CONCAT
@$(call MSG,CONCAT,GREEN,$2);
$(AT)$(CONCAT_CMD) $(CONCAT_FLAGS) $1 > $2
endef
#define MKDIR
#$(if $(shell test -d $1 && echo 1),,@$(call MSG,MKDIR,CYAN,$1);$(MKDIR_CMD) $(MKDIR_FLAGS) $1)
#endef
define MKDIR
$(AT)[ -d $1 ] || $(call MSG,MKDIR,CYAN,$1); mkdir -p $1
endef
define RMDIR
$(if $(shell test -d $1 && echo 1),@$(call MSG,RMDIR,CYAN,$1);$(RMDIR_CMD) $(RMDIR_FLAGS) $1,)
endef
define COPY
@$(call MSG,COPY,CYAN,$1);
$(AT)$(COPY_CMD) $(COPY_FLAGS) $1 $2
endef
define PACK
@$(call MSG,PACK,CYAN,$2);
$(AT)$(CD_CMD) $(CD_FLAGS) "$1" && $(PACK_CMD) $(PACK_FLAGS) $(PWD)/$2 * >/dev/null
endef
define STAMP
@$(call MSG,STAMP,GREEN,$1);
$(AT)echo "$(strip $2)" > .temp && cat $1 >> .temp && mv .temp $1
endef
# Fetch the latest Makefile
# $1 - Output
define FETCH_UPDATE
@$(call MSG,FETCH,GREEN,Makefile)
$(AT)$(WGET_CMD) $(WGET_FLAGS) -O "$1" $(MAKEFILE_ADDRESS) || \
$(call ERROR,Cannot fetch latest Makefile, please check your connection.) | :
endef

# Make calls
define MAKE_RUN
$(MAKE) --no-print-directory $2 $1
endef
define MAKE_NEXT
$(if $(RULES),$(call MAKE_RUN, __$(firstword $(RULES)), RULES="$(wordlist 2, 10, $(RULES))" $1),:)
endef
define MAKE_NEXT_EXPLICIT
$(call MAKE_RUN, $1, RULES="$(RULES)" $2)
endef
# List and decode the current rules:
RULES?=$(filter-out " ",$(strip $(subst -, ,$(firstword $(subst _, ,$@)))))
# If a rule is present
IS_RULE=$(if $(filter-out " ",$(strip $(foreach rule,$1,$(filter " $(rule) "," $(MAKECMDGOALS) ")))),,-1)
# Filter and replace by pattern
# Params:
# 1. The pattern: %.js %.css
# 2. The replacement: dist/%.min.js - @EXT will be replaced by the file extension
# 3. The file list
FILTER_PATSUBST=$(foreach file, $3, \
	$(foreach pat, $1, $(patsubst $(pat), \
		$(subst @EXT,$(suffix $(file)),$2), $(filter $(pat), $(file)))))
# Check that given variables are set and all have non-empty values,
# die with an error otherwise.
# Params:
#   1. Variable name to test.
#   2. (optional) Error message to print.
CHECK_DEFINED = \
	$(strip $(foreach 1,$1, \
		$(call __CHECK_DEFINED,$1,$(strip $(value 2)))))
__CHECK_DEFINED = \
	$(if $(value $1),, \
		@$(call ERROR, Undefined $1$(if $2, ($2))$(if $(value @), \
			required by target '$@')))
# Check if a tool is present
# Params:
#   1. Tool name
#   2. Message if not present
define CHECK_TOOL
@$(if $(shell command -v $1 2>/dev/null),$(call MSG,CHECK,CYAN,$1),$(call ERROR,$2))
endef
# Checks if one or more file(s) exists
# Params:
#   1. File
#   2. Message
#   3. (optional) Action to perform if it does not exists
FILE_NOT_EXIST=$(filter-out " ",$(strip $(foreach file,$1,$(if $(wildcard $(file)),, $(file)))))
define CHECK_FILE
@$(if $(call FILE_NOT_EXIST,$1),$(shell $(if $(value 3),$3)),)
@$(if $(call FILE_NOT_EXIST,$1),$(call ERROR,$(if $2,$2,The file(s) \"$(call FILE_NOT_EXIST,$1)\" do(es) not exist)),$(call MSG,CHECK,CYAN,$1))
endef
# Print a formated message
# Params:
#   1. Type
#   2. Color (any available colors from COLOR_*)
#   3. Message
#   4. (optional) If set, the message will not be trunc
MSG_TRUNCATE_V0 = $(MSG_TRUNCATE_V1)
MSG_TRUNCATE_V1 = $(if $(shell test 80 -gt $(shell printf "%s" "$3" | wc -m) && echo 1),$3,$(shell printf "%s" "$3" | cut -c 1-80)...)
MSG_TRUNCATE_V2 = $3
MSG_TRUNCATE = $(strip $(MSG_TRUNCATE_V$(VERBOSE)))
define MSG_ONLY
"$(COLOR_END)$(COLOR_$2)$1$(COLOR_END)\t\t$(if $(value 4),$3,$(MSG_TRUNCATE))"
endef
define MSG
$(PRINT) "$(if $(COMPACT_MODE),$(CLEAR_LINE),)"$(call MSG_ONLY,$1,$2,$3,$4)"$(if $(COMPACT_MODE),,\n)"
endef
define MSG_ALWAYS
$(PRINT) "$(if $(COMPACT_MODE),$(CLEAR_LINE),)"$(call MSG_ONLY,$1,$2,$3,$4)"\n"
endef
# Print an error message and exit
# Params:
#   1. Error message to print.
define ERROR
$(call MSG_ALWAYS,$(if $(COMPACT_MODE),\n,)ERROR,RED,$(COLOR_RED)$(strip $1)$(COMMA) abort.$(COLOR_END),1)
@exit 1
endef
# Print a warning message
# Params:
#   1. Warning message to print.
define WARNING
$(call MSG_ALWAYS,$(if $(COMPACT_MODE),\n,)WARNING,YELLOW,$(COLOR_YELLOW)$(strip $1)$(COLOR_END),1)
endef
# Info messages
# Params:
#   1. The information message
define INFO
$(call MSG_ALWAYS,INFO,LIGHT_BLUE,$1)
endef
# Added to a pipe, it will detect errors and warning and reformat the output
define PIPE_FORMAT
sed 's/^.*\(WARN\).*/$(COLOR_YELLOW)\0$(COLOR_END)/i' \
| sed 's/^\(.*ERROR\|.*EXPECTED\|[ \t]\+at\).*/$(COLOR_RED)\0$(COLOR_END)/i' \
| sed 's/.*/      \t\t\0/' \
| xargs -0 -I{} printf "$(if $(COMPACT_MODE),\n,){}"
endef

# ---- General targets --------------------------------------------------------

# Export variables to sub-makes
export
unexport RULES

TIME_START:=$(shell date +%s%N)

# Predefined rules
all: $(BUILDDIR)/Makefile | $(ALL_RULES) mute-if-nop
	@printf "$(if $(COMPACT_MODE),$(CLEAR_LINE),)"
	@$(foreach output, $(OUTPUT_LIST), $(call INFO, \
		$(output): $(shell du -bh $(DISTDIR)/$(output) | awk '{print $$1 "B"}')) && ) true
	@$(call INFO,Elapsed time: $(shell time_end=`date +%s%N`; expr \( $$time_end - $(TIME_START) \) / 1000000 | awk '{print ($$1/1000)}')s)

build: all
silent: VERBOSE := 0
silent: all
verbose: VERBOSE := 2
verbose: all
mute-if-nop:
	@:

# Trigger a clean if the makefiles have been altered
$(BUILDDIR)/Makefile: $(ALL_MAKEFILES) | check_config
	+@$(call MAKE_RUN, clean)
	@mkdir -p $(BUILDDIR) && touch $(BUILDDIR)/Makefile

# Help message
help:
	@printf "Generic Makefile by Blaise Lengrand\n"
	@printf "Usage: make [rule]\n"
	@printf "\n"
	@printf "By default, it will run all user rules starting with specific\n"
	@printf "names, the followings are currently supported:\n"
	@printf "\tprocess_*\t\tDepending on the file type, but it will process\n"
	@printf "\t         \t\ta file for publication. Example, .js and .css\n"
	@printf "\t         \t\tfiles will be minimized and concatenated.\n"
	@printf "\tprocess-stamp_*\t\tWill process and stamp the output file.\n"
	@printf "\tcopy_*\t\tSimply copy the files or directories to the output.\n"
	@printf "\tcopy-stamp_*\t\tCopy and stamp.\n"
	@printf "\tconcat_*\t\tConcatenate a list of files together.\n"
	@printf "\tconcat-stamp_*\t\tConcatenate and stamp a file.\n"
	@printf "\n"
	@printf "List of rules available:\n"
	@printf "\tsilent\t\tNo verbosity, except error messages.\n"
	@printf "\tverbose\t\tHigh verbosity, including command executed.\n"
	@printf "\thelp\t\tDisplay this help message.\n"
	@printf "\tclean\t\tClean the environment and all generated files.\n"
	@printf "\tbuild\t\tBuild the targets.\n"
	@printf "\trebuild\t\tClean and re-build the targets.\n"
	@printf "\trelease\t\tRe-build the targets and generate the package.\n"
	@printf "\tupdate\t\tAutomatically check and update the Makefile with\n"
	@printf "\t      \t\tthe latest version.\n"
	@printf "\n"
	@printf "Configuration: config.mk\n"
	@printf "\tContains all user rules definitions. They use pre-made\n"
	@printf "\trules with the following options:\n"
	@printf "\tINPUT\t\tContains the input files for the specific rule.\n"
	@printf "\tOUTPUT\t\tThe name of the output file (if relevant).\n"
	@printf "Example:\n"
	@printf "\tprocess_main: INPUT := hello.js\n"
	@printf "\tprocess_main: OUTPUT := hello.min.js\n"

# Check that all prerequired conditions are there
check_config:
	$(call CHECK_FILE, config.mk, \
			'config.mk' does not exists or is empty$(COMMA) an empty template has been created, \
			$(call MAKE_RUN, help) 2>/dev/null | sed 's/.*/#\0/' > config.mk)
	$(call CHECK_DEFINED, ALL_RULES, 'config.mk' contains no rules)
# Check if JS minify tools are present
check_minify_js:
	$(call CHECK_TOOL, $(MINIFY_JS_CMD),Please install: uglifyjs package)
# Check if CSS minify tools are present
check_minify_css:
	$(call CHECK_TOOL, $(MINIFY_CSS_CMD),Please install: uglifycss package)
# Check if SASS tool is present
check_sass:
	$(call CHECK_TOOL, $(SASS_CMD),Please install: sass package)
# Check if the packaging tools are present
check_pack:
	$(call CHECK_TOOL, $(PACK_CMD), "")

# Clean-up the created directoried
clean: | mute-if-nop
	$(call RMDIR,$(BUILDDIR)/)
	$(call RMDIR,$(DISTDIR)/)

# Clean and re-build the targets
rebuild:
	+@$(call MAKE_RUN, clean)
	+@$(call MAKE_RUN, build)

# Re-build all what is inside the dist directory and make a package of it all
release: check_pack | mute-if-nop
	$(call RMDIR,$(DISTDIR)/)
	+@$(call MAKE_RUN, build)
	$(call PACK,$(DISTDIR),$(DISTDIR)/$(PACKAGE))
	@printf "$(if $(COMPACT_MODE),$(CLEAR_LINE),)"

# Automatically checks and update the Makefile with the latest version
update:
	$(call MKDIR, $(BUILDDIR)/)
	$(call FETCH_UPDATE,$(BUILDDIR)/Makefile)
	@cmp --silent Makefile $(BUILDDIR)/Makefile || ( \
			$(call INFO,Makefile -> Makefile.old); \
			cp Makefile Makefile.old; $(call INFO,Updating new Makefile); \
			mv $(BUILDDIR)/Makefile Makefile )
	@$(call INFO,Makefile is up-to-date)

# ---- Automatic targets -----------------------------------------------------
process%:
	$(call CHECK_DEFINED, INPUT)
	$(call CHECK_FILE, $(INPUT))
	$(call CHECK_DEFINED, OUTPUT)
	+@$(call MAKE_NEXT, INPUT="$(INPUT)" OUTPUT="$(OUTPUT)")
	@$(eval OUTPUT_LIST += "$(OUTPUT)")

concat%:
	$(call CHECK_DEFINED, INPUT)
	$(call CHECK_FILE, $(INPUT))
	$(call CHECK_DEFINED, OUTPUT)
	+@$(call MAKE_NEXT, INPUT="$(INPUT)" OUTPUT="$(OUTPUT)")

copy%:
	$(call CHECK_DEFINED, INPUT)
	$(call CHECK_FILE, $(INPUT))
	+@$(foreach file, $(INPUT), $(call MAKE_NEXT, INPUT="$(file)" OUTPUT="$(OUTPUT)") && ) true

# ---- Stamp ------------------------------------------------------------------
ifeq ($(call IS_RULE, __stamp),)

ifeq ($(words $(OUTPUT)),1)
# Note, the target ensures that only 1 output is specified
ifeq ($(filter-out %.js %.css,$(OUTPUT)),)
__stamp: | mute-if-nop
	$(call CHECK_DEFINED, OUTPUT)
	$(call CHECK_FILE, $(OUTPUT))
	$(call STAMP,$(OUTPUT),/* $(STAMP_TXT) */)
	+@$(call MAKE_NEXT, OUTPUT="$(OUTPUT)")
else
__stamp:
	@$(call WARNING, The filetype \"$(suffix $(OUTPUT))\" of \"$(OUTPUT)\" is not supported for stamping)
# Unsupported supported file extensions are ignored
endif
else
__stamp:
	@$(call ERROR, This target \"$@\" supports only 1 output at a time)
endif

endif

# ---- Process ----------------------------------------------------------------
ifeq ($(call IS_RULE, __process),)

__process: $(DISTDIR)/$(OUTPUT) | mute-if-nop

# ---- Process - Javascript & CSS & SASS
ifeq ($(filter-out %.js %.css %.scss %.sass,$(INPUT)),)

$(DISTDIR)/$(OUTPUT): $(call FILTER_PATSUBST, %.js %.css %.scss %.sass, $(BUILDDIR)/%.min@EXT, $(INPUT))
	+@$(call MAKE_NEXT_EXPLICIT, __concat, INPUT="$^" OUTPUT="$(OUTPUT)")
# js files
$(BUILDDIR)/%.min.js: check_minify_js %.js
	$(call MKDIR, `dirname $@`/)
	$(call MINIFY_JS, $(lastword $^), "$@")
# css files
$(BUILDDIR)/%.min.css: check_minify_css %.css
	$(call MKDIR, `dirname $@`/)
	$(call MINIFY_CSS, $(lastword $^), "$@")
# scss files
$(BUILDDIR)/%.min.scss: check_sass %.scss
	$(call MKDIR, `dirname $@`/)
	$(call SCSS, $(lastword $^), "$@.css")
	$(call MINIFY_CSS, "$@.css", "$@")
# sass files
$(BUILDDIR)/%.min.sass: check_sass %.sass
	$(call MKDIR, `dirname $@`/)
	$(call SASS, $(lastword $^), "$@.css")
	$(call MINIFY_CSS, "$@.css", "$@")

else
$(DISTDIR)/$(OUTPUT):
	@$(call ERROR, File type \"$(firstword $(suffix $(INPUT)))\" not supported for rule processing)
endif

endif

# ---- Concatenate ------------------------------------------------------------
ifeq ($(call IS_RULE, __concat),)

__concat: $(DISTDIR)/$(OUTPUT) | mute-if-nop
# Contenate all files together
$(DISTDIR)/$(OUTPUT): $(INPUT)
	$(call MKDIR, `dirname "$(DISTDIR)/$(OUTPUT)"`/)
	$(call CONCAT, $^, "$(DISTDIR)/$(OUTPUT)")
	+@$(call MAKE_NEXT, OUTPUT="$(DISTDIR)/$(OUTPUT)")

endif

# ---- Copy -------------------------------------------------------------------
ifeq ($(call IS_RULE, __copy),)

ifeq ($(words $(INPUT)),1)
# Note: this target ensures that only 1 src and 1 dst are specified
DIR_OUTPUT = $(DISTDIR)/$(if $(OUTPUT),$(OUTPUT)/,)$(notdir $(patsubst %/,%,$(abspath $(INPUT)))$(if $(wildcard $(INPUT)/.*),,/))$(if $(wildcard $(INPUT)/.*),/,)
FILE_OUTPUT = $(DIR_OUTPUT)$(if $(wildcard $(INPUT)/.*),,$(notdir $(INPUT)))
FILES_OUTPUT = $(patsubst %, $(DIR_OUTPUT)%, $(notdir $(shell find $(INPUT) -type f)))
__copy: $(FILE_OUTPUT) | mute-if-nop
$(FILE_OUTPUT):
	$(call CHECK_DEFINED, INPUT)
	$(call MKDIR, "$(DISTDIR)/$(OUTPUT)")
	$(call COPY, $(INPUT), $(DIR_OUTPUT))
	+@$(foreach file, $(FILES_OUTPUT), $(call MAKE_NEXT, OUTPUT="$(file)") && ) true
# Hack to ensure that the find command is not executed before the copy (due to parallelism)
else
__copy:
	@$(call ERROR, This target \"$@\" supports only 1 input at a time)
endif

endif
