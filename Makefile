# require this because it's just easier
SHELL = /bin/bash

name := $(shell d=`pwd`; d=$${d\#\#*/}; d=$${d%%-[0-9]*}; echo "$$d")
name_in := $(wildcard $(name).in)
ver := $(shell d=`pwd`; [[ $$d == */$(name)-[0-9]* ]] && \
	 echo $${d\#\#*/$(name)-} || ./tagver)

tar := ../$(name)-$(ver).tar
tgz := $(tar).gz
srpm := ../$(name)-$(ver)-1.src.rpm
rpm := ../$(name)-$(ver)-1.noarch.rpm

pods := $(wildcard *.pod)
html := $(patsubst %.pod, %.html, $(pods))
man := $(patsubst %.pod, %, $(pods))
spec_in := $(wildcard $(name).spec.in)
spec := $(patsubst %.in, %, $(spec_in))

gen := $(html) $(man) $(spec)
ifneq ($(name_in),)
gen += $(name)
endif

.PHONY: all
all: $(gen)

# use FORCE to avoid old version info
FORCE:

%: %.in
	sed 's/\<HEAD\>/$(ver)/g' $< > $@.gen
	mv $@.gen $@
	[[ -x $< ]] && chmod +x $@ ||:

%.html: %.pod
	pod2html --title=$(<:.pod=) --noindex < $< > $@.gen
	mv $@.gen $@

%: %.pod
	pod2man --name=$(<:.pod=) --center="$(name)" \
	  --section=1 --release="$(ver)" < $< > $@.gen
	mv $@.gen $@

.PHONY: tgz
tgz: $(tgz)
$(tgz): Makefile $(name) $(spec)
ifeq ($(wildcard .hg),.hg)
	hg archive -t tar -p $(name)-$(ver) $(tar)
else ifeq ($(wildcard .git),.git)
	git archive --format=tar --prefix=$(name)-$(ver)/ -o $(tar) HEAD
else
	@echo "### not a git or hg repo, eek ###"
	@exit 1
endif
ifneq ($(spec),)
	mkdir $(name)-$(ver)
	cp $(spec) $(name)-$(ver)
	tar rf $(tar) $(name)-$(ver)/*
	rm -rf $(name)-$(ver)
endif
	gzip -f $(tar)
	ls -l $(tgz)

.PHONY: rpm
rpm: $(rpm)
$(rpm): $(tgz)
	rpmbuild -ta --define='_topdir $(abspath ../$(name)-$(ver))' $(tgz)
	mv ../$(name)-$(ver)/SRPMS/* ..
	mv ../$(name)-$(ver)/RPMS/*/* ..
	rm -rf ../$(name)-$(ver)
	ls -l $(srpm) $(rpm)

# .PHONY: release
# release: $(tar) $(rpm)
# 	scp $(tar) $(rpm) $(srpm) ldl:public_html/$(name)/
# 	ssh ldl createrepo public_html/$(name)

.PHONY: clean
clean:
	rm -f $(gen) pod2*.tmp

prefix = /usr/local
bindir = $(prefix)/bin
mandir = $(prefix)/share/man

.PHONY: install
install:
	mkdir -p $(DESTDIR)$(bindir)
ifeq ($(name_in),)
	sed 's/\<HEAD\>/$(ver)/g' $(name) > $(DESTDIR)$(bindir)/$(name)
	chmod 0755 $(DESTDIR)$(bindir)/$(name)
else
	install -m 0755 $(name) $(DESTDIR)$(bindir)/$(name)
endif
ifneq ($(man),)
	for m in $(man); do \
	    d=$(DESTDIR)$(mandir)/man$${m##*[^0-9]}; \
	    mkdir -p $$d; \
	    gzip -c $$m > $$d/$$m.gz; \
	    chmod 0644 $$d/$$m.gz; \
	done
endif
