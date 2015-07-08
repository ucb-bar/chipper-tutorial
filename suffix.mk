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

# If we don't have an output directory, here is the rule to make it.
$(objdir):
	mkdir -p $@

chipper	?= $(bindir)/chipper
filter	?= $(bindir)/filter
firrtl	?= $(bindir)/firrtl
genharness ?= $(bindir)/gen-harness
flollvm ?= flo-llvm

clang	?= clang++

# Don't expect reasonable output from all *.stanza files.
# Currently, all .stanza files are okay so we use a dummy 'none'.
units := $(filter-out none,\
            $(notdir $(basename $(wildcard $(srcdir)/*.stanza))))

executables := $(addprefix $(objdir)/,$(units))

# Generate the rule to make something in the object directory

tut_outs    := $(addsuffix .out, $(executables))
tut_firs    := $(addsuffix .fir, $(executables))

default: all

all: outs

clean:
	cd $(top_srcdir) && rm -rf $(objdir)

firs: $(tut_firs)

outs: $(tut_outs)

verilog: $(addsuffix .v, $(executables))

$(objdir)/%.out: $(objdir)/% $(objdir)/%.fir
	echo $(chipper) or something

$(objdir)/lib%.so:	$(objdir)/lib%.o $(objdir)/%.o
	cd $(objdir) && $(clang) -shared -o $(@F) -fPIC $(<F) $(patsub lib%.so,%,$(@F))

$(objdir)/lib%.o:	$(objdir)/lib%.cpp
	cd $(objdir) && $(clang) -c -fPIC $(<F) -o $(@F)

$(objdir)/lib%.cpp:	$(objdir)/%.flo
	cd $(objdir) && $(genharness) $(patsub %.flo,%,$(<F)) > $(@F)

$(objdir)/%.o:	$(objdir)/%.flo
	cd $(objdir) && $(flollvm) --vcdtmp $(<F)


$(objdir)/%.flo:	$(objdir)/%.fir
	cd $(objdir) && $(firrtl) -i $(<F) -o $(@F).tmp -X flo
	cd $(objdir) && $(filter) < $(@F).tmp > $(@F)

$(objdir)/%.fir:	$(objdir)/%
	$< > $@

$(objdir)/%: %.stanza
	$(chipper) -i $< -o $@

compile smoke: firs

.PHONY: all check clean outs firs smoke

%: $(objdir)/%
	echo tried to make $@

# Optimization - Don't try seeing if these have dependencies and need to be regenerated.
Makefile : ;
%.mk :: ;
