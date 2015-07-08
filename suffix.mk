top_srcdir  ?= ..
srcdir ?= .

# Determine where we are
curdir	:= $(abspath $(CURDIR))
# Determine which component we are
component ?= $(notdir $(patsubst %/,%,$(curdir)))
# Directory containing src
srcdir      ?= $(top_srcdir)/$(component)
# Directory containing executables
bindir	  ?= $(abspath $(top_srcdir)/chipper/bin)
# Directory below which we'll create all generated files.
objdir	?= $(abspath $(top_srcdir)/generated/$(component))

chipper	?= $(bindir)/chipper
filter	?= $(bindir)/filter
firrtl	?= $(bindir)/firrtl
genharness ?= $(bindir)/gen-harness
flollvm ?= flo-llvm

clang	?= clang++

# Don't use any built-in rules.
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

# Don't expect reasonable output from all *.stanza files.
# Currently, all .stanza files are okay so we use a dummy 'none'.
units := $(filter-out none,\
            $(notdir $(basename $(wildcard $(srcdir)/*.stanza))))

.PHONY:	$(units)

executables := $(addprefix $(objdir)/,$(units))
sos := $(addsuffix .so,$(addprefix $(objdir)/lib,$(units)))

generated_suffixes := .fir .flo .h .o .out
generated_suffixes_lib := .cpp .o .so
generated_files := $(foreach sfx,$(generated_suffixes),$(addsuffix $(sfx),$(units))) $(units) $(foreach sfx,$(generated_suffixes_lib),$(addsuffix $(sfx),$(addprefix lib,$(units))))

# Generate the rule to make something in the object directory

tut_outs    := $(addsuffix .out, $(executables))
tut_firs    := $(addsuffix .fir, $(executables))

default: all

all: outs

clean:
	cd $(objdir) && $(RM) $(generated_files)

firs: $(tut_firs)

outs: $(tut_outs)

verilog: $(addsuffix .v, $(executables))

$(objdir)/%.out: $(objdir)/%
	set -e -o pipefail; cd $(objdir) && ./$(<F) --testing | tee $(@F)

$(objdir)/lib%.so:	$(objdir)/lib%.o $(objdir)/%.o
	cd $(objdir) && $(clang) -shared -o $(@F) -fPIC $(<F) `echo $(basename $(@F)) | sed -e s/lib//`.o

$(objdir)/lib%.o:	$(objdir)/lib%.cpp
	cd $(objdir) && $(clang) -c -fPIC $(<F) -o $(@F)

$(objdir)/lib%.cpp:	$(objdir)/%.flo $(objdir)/%.o
	cd $(objdir) && $(genharness) $(basename $(<F)) > $(@F)

$(objdir)/%.o:	$(objdir)/%.flo
	cd $(objdir) && $(flollvm) $(<F) #  --vcdtmp


$(objdir)/%.flo:	$(objdir)/%.fir
	cd $(objdir) && $(firrtl) -i $(<F) -o $(@F).tmp -X flo
	cd $(objdir) && $(filter) < $(@F).tmp > $(@F)

$(objdir)/%.v:	$(objdir)/%.fir
	cd $(objdir) && $(firrtl) -i $(<F) -o $(@F) -X verilog

$(objdir)/%.fir:	$(objdir)/%
	$< > $@

$(objdir)/%: %.stanza
	$(chipper) -i $< -o $@

compile smoke: firs

check:	outs

.PHONY: all check clean outs firs smoke

# Last resort target. The first dependency will be the object directory,
# but only if it doesn't already exist.
# The dummy recipe seems to be required for Yosemite versions of Make,
# otherwise it complains about not being able to make the target.
%: $(filter-out $(wildcard $objdir),$(objdir)) $(objdir)/%
	@true

.PRECIOUS:	$(executables) $(sos)

# Optimization - Don't try seeing if these have dependencies and need to be regenerated.
Makefile : ;
%.mk :: ;

# If we don't have an output directory, here is the rule to make it.
$(objdir):
	mkdir -p $@
