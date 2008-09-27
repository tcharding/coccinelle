#############################################################################
# Configuration section
#############################################################################

-include Makefile.config

VERSION=$(shell cat globals/config.ml |grep version |perl -p -e 's/.*"(.*)".*/$$1/;')

##############################################################################
# Variables
##############################################################################
TARGET=spatch

SRC=flag_cocci.ml cocci.ml testing.ml test.ml main.ml


ifeq ($(FEATURE_PYTHON),1)
PYCMA=pycaml/pycaml.cma
PYDIR=pycaml
PYLIB=dllpycaml_stubs.so
# the following is essential for Coccinelle to compile under gentoo (wierd)
OPTLIBFLAGS=-cclib dllpycaml_stubs.so
else
PYCMA=
PYDIR=
PYLIB=
OPTLIBFLAGS=
endif


SYSLIBS=str.cma unix.cma
LIBS=commons/commons.cma globals/globals.cma\
     ctl/ctl.cma \
     parsing_cocci/cocci_parser.cma parsing_c/parsing_c.cma \
     engine/cocciengine.cma popl09/popl.cma \
     extra/extra.cma $(PYCMA) python/coccipython.cma

MAKESUBDIRS=commons globals menhirlib $(PYDIR) ctl parsing_cocci parsing_c engine popl09 \
 extra python
INCLUDEDIRS=commons globals menhirlib $(PYDIR) ctl parsing_cocci parsing_c engine popl09 \
 extra python

##############################################################################
# Generic variables
##############################################################################

INCLUDES=$(INCLUDEDIRS:%=-I %)

OBJS=    $(SRC:.ml=.cmo)
OPTOBJS= $(SRC:.ml=.cmx)

EXEC=$(TARGET)

##############################################################################
# Generic ocaml variables
##############################################################################

OCAMLCFLAGS=-g -dtypes # -w A

# for profiling add  -p -inline 0
# but 'make forprofiling' below does that for you.
# This flag is also used in subdirectories so don't change its name here.
OPTFLAGS=

# the OPTBIN variable is here to allow to use ocamlc.opt instead of 
# ocaml, when it is available, which speeds up compilation. So
# if you want the fast version of the ocaml chain tools, set this var 
# or setenv it to ".opt" in your startup script.
OPTBIN= #.opt

OCAMLC=ocamlc$(OPTBIN) $(OCAMLCFLAGS)  $(INCLUDES)
OCAMLOPT=ocamlopt$(OPTBIN) $(OPTFLAGS) $(INCLUDES) 
OCAMLLEX=ocamllex #-ml # -ml for debugging lexer, but slightly slower
OCAMLYACC=ocamlyacc -v
OCAMLDEP=ocamldep $(INCLUDES)
OCAMLMKTOP=ocamlmktop -g -custom $(INCLUDES)

# can also be set via 'make static'
STATIC= #-ccopt -static

# can also be unset via 'make purebytecode'
BYTECODE_STATIC=-custom

##############################################################################
# Top rules
##############################################################################

all: rec $(EXEC)
opt: rec.opt $(EXEC).opt
all.opt: opt

rec:
	set -e; for i in $(MAKESUBDIRS); do $(MAKE) -C $$i all; done 
rec.opt:
	set -e; for i in $(MAKESUBDIRS); do $(MAKE) -C $$i all.opt; done 

$(EXEC): $(LIBS) $(OBJS)
	$(OCAMLC) $(BYTECODE_STATIC) -o $@ $(SYSLIBS)  $^

$(EXEC).opt: $(LIBS:.cma=.cmxa) $(OPTOBJS) 
	$(OCAMLOPT) $(STATIC) -o $@ $(SYSLIBS:.cma=.cmxa) $(OPTLIBFLAGS)  $^

$(EXEC).top: $(LIBS) $(OBJS) 
	$(OCAMLMKTOP) -custom -o $@ $(SYSLIBS) $^

clean::
	rm -f $(TARGET) $(TARGET).opt $(TARGET).top

clean::
	set -e; for i in $(MAKESUBDIRS); do $(MAKE) -C $$i clean; done 

clean::
	rm -f dllpycaml_stubs.so


.PHONY: tools

tools:
	$(MAKE) -C tools
clean::
	$(MAKE) -C tools clean


static:
	rm -f spatch.opt spatch
	$(MAKE) STATIC="-ccopt -static" spatch.opt
	cp spatch.opt spatch

purebytecode:
	rm -f spatch.opt spatch
	$(MAKE) BYTECODE_STATIC="" spatch


##############################################################################
# Install
##############################################################################

# DESTDIR can be set by package build system like ebuild
install: all
	mkdir -p $(DESTDIR)$(BINDIR)
	mkdir -p $(DESTDIR)$(LIBDIR)
	mkdir -p $(DESTDIR)$(SHAREDIR)
	cp spatch $(DESTDIR)$(BINDIR)	
	cp -f dllpycaml_stubs.so $(DESTDIR)$(LIBDIR)	
	cp standard.h $(DESTDIR)$(SHAREDIR)
	cp standard.iso $(DESTDIR)$(SHAREDIR)
	mkdir -p $(DESTDIR)$(SHAREDIR)/python
	cp -a python/coccilib $(DESTDIR)$(SHAREDIR)/python
	@echo ""
	@echo "You can also install spatch by copying the program spatch"
	@echo "(available in this directory) anywhere you want and"
	@echo "give it the right options to find its configuration files."

uninstall:
	rm -f $(BINDIR)/spatch
	rm -f $(LIBDIR)/dllpycaml_stubs.so
	rm -f $(DESTDIR)$(SHAREDIR)/standard.h
	rm -f $(DESTDIR)$(SHAREDIR)/standard.iso
	rm -rf $(DESTDIR)$(SHAREDIR)/python/coccilib



version:
	@echo $(VERSION)


##############################################################################
# Package rules, pad's specific
##############################################################################

# To test you can try compile and run spatch from different instances 
# like my ~/coccinelle, ~/release/coccinelle, and the /tmp/coccinelle-0.X 
# downloaded from my website. For 'make srctar' I must do it from a clean
# repo such as ~/release/coccinelle. It must also be a repo where 
# the scripts/licensify have been run at least once.
# For the 'make bintar' I can do it from my original repo.

PACKAGE=coccinelle-$(VERSION)

BINSRC=spatch env.sh env.csh standard.h standard.iso \
       $(PYLIB) python/coccilib/  \
       *.txt docs/* \
       demos/foo.* demos/simple.* demos/printloc.*
BINSRC2=$(BINSRC:%=$(PACKAGE)/%)

TXT=$(wildcard *.txt)

# really pad specific
TOP=/home/pad/mobile/project-coccinelle
WEBSITE=/home/pad/mobile/homepage/software/project-coccinelle

package: 
	make srctar 
	make bintar 
	make staticbintar 
	make bytecodetar

# I currently pre-generate the parser so the user does not have to 
# install menhir on his machine. I also do a few cleanups like 'rm todo_pos'.
# You may have first to do a 'make licensify'.
srctar:
	make clean
	cp -a .  $(TOP)/$(PACKAGE)
	cd $(TOP)/$(PACKAGE); cd parsing_cocci/; make parser_cocci_menhir.ml
	cd $(TOP)/$(PACKAGE); rm todo_pos
	cd $(TOP); tar cvfz $(PACKAGE).tgz $(PACKAGE)
	rm -rf  $(TOP)/$(PACKAGE)


bintar: all
	rm -f $(TOP)/$(PACKAGE)
	ln -s $(TOP)/code $(TOP)/$(PACKAGE)
	cd $(TOP); tar cvfz $(PACKAGE)-bin-x86.tgz $(BINSRC2)
	rm -f $(TOP)/$(PACKAGE)

staticbintar: all.opt
	rm -f $(TOP)/$(PACKAGE)
	ln -s $(TOP)/code $(TOP)/$(PACKAGE)
	make static
	cd $(TOP); tar cvfz $(PACKAGE)-bin-x86-static.tgz $(BINSRC2)
	rm -f $(TOP)/$(PACKAGE)

bytecodetar: all
	rm -f $(TOP)/$(PACKAGE)
	ln -s $(TOP)/code $(TOP)/$(PACKAGE)
	make purebytecode
	cd $(TOP); tar cvfz $(PACKAGE)-bin-bytecode.tgz $(BINSRC2)
	rm -f $(TOP)/$(PACKAGE)

#	ln -s $(TOP)/code $(TOP)/$(PACKAGE)
#	rm -f $(TOP)/$(PACKAGE)
#	mv $(TOP)/code $(TOP)/$(PACKAGE)
#	mv $(TOP)/$(PACKAGE) $(TOP)/code


clean::
	rm -f $(PACKAGE) 
	rm -f $(PACKAGE)-bin-x86.tgz 
	rm -f $(PACKAGE)-bin-x86-static.tgz 
	rm -f $(PACKAGE)-bin-bytecode.tgz


website:
	cp $(TOP)/$(PACKAGE).tgz                $(WEBSITE)
	cp $(TOP)/$(PACKAGE)-bin-x86.tgz        $(WEBSITE)
	cp $(TOP)/$(PACKAGE)-bin-x86-static.tgz $(WEBSITE)
	cp $(TOP)/$(PACKAGE)-bin-bytecode.tgz   $(WEBSITE)

syncwiki:
#	unison ~/public_html/wiki/wiki-LFS/data/pages/ docs/wiki/
#	set -e; for i in $(TXT); do unison $$i docs/wiki/$$i; done 

darcsweb:
#	@echo pull from ~/public_html/darcs/c-coccinelle and c-commons and lib-xxx

TOLICENSIFY=ctl engine parsing_cocci popl popl09 python
licensify:
	ocaml tools/licensify.ml 
	set -e; for i in $(TOLICENSIFY); do cd $$i; ocaml ../tools/licensify.ml; cd ..; done 


##############################################################################
# Developer rules
##############################################################################

test: $(TARGET)
	./$(TARGET) -testall

testparsing:
	./$(TARGET) -D standard.h -parse_c -dir parsing_c/tests
#	./$(TARGET) -D standard.h -parse_c -dir tests/
# -parse_c big-files/
# -parse_c pb_parsing/ 
# -parse_c pb_parsing_ecoop/


#-filter_define_error
PARSECMD=./spatch.opt -D standard.h -filter_define_error -filter_classic_passed \
	  -dir

testparsing2: 
	$(PARSECMD) -parse_c ~/kernels/git/linux-2.6/sound/ > /tmp/parse_sound_filter 2>&1 
	$(PARSECMD) -parse_c ~/kernels/git/linux-2.6/drivers/  > /tmp/parse_drivers_filter 2>&1 
	$(PARSECMD) -parse_c ~/kernels/git/linux-2.6/  > /tmp/parse_c_filter 2>&1 
	$(PARSECMD) -parse_h ~/kernels/git/linux-2.6/  > /tmp/parse_h_filter 2>&1 
	$(PARSECMD) -parse_ch ~/kernels/git/linux-2.6/ > /tmp/parse_ch_filter 2>&1

testparsing3:
	./spatch.opt -D standard.h -parse_ch -dir ~/kernels/git/linux-2.6/ > /tmp/parse_ch_all 2>&1

testparsing4:
	./spatch.opt -D standard.h -parse_c -dir tests-big/ > /tmp/parse_big_c 2>&1




# -inline 0  to see all the functions in the profile. 
# Can also use the profile framework in commons/ and run your program 
# with -profile.
forprofiling:
	$(MAKE) OPTFLAGS="-p -inline 0 " opt

clean::
	rm -f gmon.out 

tags:
	otags -no-mli-tags -r  .

dependencygraph:
	find  -name "*.ml" |grep -v "scripts" | xargs ocamldep -I commons -I globals -I ctl -I parsing_cocci -I parsing_c -I engine -I popl09 -I extra > /tmp/dependfull.depend
	ocamldot -fullgraph /tmp/dependfull.depend > /tmp/dependfull.dot
	dot -Tps /tmp/dependfull.dot > /tmp/dependfull.ps

##############################################################################
# Misc rules
##############################################################################

# each member of the project can have its own test.ml. this file is 
# not under CVS.
test.ml: 
	echo "let foo_ctl () = failwith \"there is no foo_ctl formula\"" \
	  > test.ml

beforedepend:: test.ml


#INC=$(dir $(shell which ocaml))
#INCX=$(INC:/=)
#INCY=$(dir $(INCX))
#INCZ=$(INCY:/=)/lib/ocaml
#
#prim.o: prim.c
#	gcc -c -o prim.o -I $(INCZ) prim.c


##############################################################################
# Generic ocaml rules
##############################################################################

.SUFFIXES: .ml .mli .cmo .cmi .cmx

.ml.cmo:
	$(OCAMLC)    -c $<
.mli.cmi:
	$(OCAMLC)    -c $<
.ml.cmx:
	$(OCAMLOPT)  -c $<

.ml.mldepend: 
	$(OCAMLC) -i $<

clean::
	rm -f *.cm[iox] *.o *.annot

clean::
	rm -f *~ .*~ *.exe #*#

beforedepend::

depend:: beforedepend
	$(OCAMLDEP) *.mli *.ml > .depend
	set -e; for i in $(MAKESUBDIRS); do $(MAKE) -C $$i depend; done

-include .depend
