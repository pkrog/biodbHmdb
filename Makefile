# Makefile for biodb extensions packages, version 1.2.0
# vi: ft=make

NEWPKG=true

# Mute R 3.6 "Registered S3 method overwritten" warning messages.
# Messages that were output:
#     Registered S3 method overwritten by 'R.oo':
#       method        from
#       throw.default R.methodsS3
#     Registered S3 method overwritten by 'openssl':
#       method      from
#       print.bytes Rcpp
export _R_S3_METHOD_REGISTRATION_NOTE_OVERWRITES_=no

# Constants
COMMA := ,

# Bioconductor check flags
BIOC_CHECK_FLAGS=quit-with-status no-check-formatting
ifeq (true,$(NEWPKG))
BIOC_CHECK_FLAGS+=new-package
endif

# Set and check name
PKG_NAME := $(notdir $(realpath $(CURDIR)))
ifeq (,$(shell echo $(PKG_NAME) | grep '^biodb\([A-Z][A-Za-z0-9]*\)\?$$'))
$(error "$(PKG_NAME)" is not a standard package name for a biodb extension. The package name for a biodb extension must respect the format "^biodb([A-Z][A-Za-z0-9]*)?")
endif
ifeq (biodb,$(PKG_NAME))
PKG_NAME_CAPS := BIODB
else
PKG_NAME_CAPS := BIODB_$(shell echo $(PKG_NAME) | sed 's/^biodb//' | tr '[:lower:]' '[:upper:]')
endif

# Check files
ifeq (,$(wildcard DESCRIPTION))
$(error Missing file DESCRIPTION)
endif

# Set cache folder
CACHE=$(CURDIR)/cache
LONG_CACHE=$(CURDIR)/cache.long
export BIODB_CACHE_DIRECTORY=$(CACHE)

# Set testthat reporter
ifndef TESTTHAT_REPORTER
ifdef VIM
TESTTHAT_REPORTER=summary
else
TESTTHAT_REPORTER=progress
endif
endif

# Enable compiling
ifneq (,$(wildcard src))
COMPILE=compile
endif

# Get package version
PKG_VERSION=$(shell grep '^Version:' DESCRIPTION | sed 's/^Version: //')

# Set zip filename
ZIPPED_PKG=$(PKG_NAME)_$(PKG_VERSION).tar.gz

# R
export _R_CHECK_LENGTH_1_CONDITION_=true
export _R_CHECK_LENGTH_1_LOGIC2_=true
RFLAGS=--slave --no-restore
R_HOME=$(shell /usr/bin/env R $(RFLAGS) RHOME)
R=$(R_HOME)/bin/R

# For R CMD SHLIB
export PKG_CXXFLAGS=$(shell $(R) $(RFLAGS) -e "Rcpp:::CxxFlags()")
PKG_CXXFLAGS+=-I$(realpath $(shell $(R) $(RFLAGS) -e "cat(file.path(testthat::testthat_examples(),'../include'))"))

# Set test file filter
ifndef TEST_FILE
TEST_FILE=NULL
else
TEST_FILE:='$(TEST_FILE)'
endif

# Check
CHECK_RENVIRON=check.Renviron
export R_CHECK_ENVIRON=$(CHECK_RENVIRON)

# Display values of main variables
$(info PKG_NAME=$(PKG_NAME))
$(info PKG_NAME_CAPS=$(PKG_NAME_CAPS))
$(info PKG_VERSION=$(PKG_VERSION))
$(info PKG_CXXFLAGS=$(PKG_CXXFLAGS))
$(info BIODB_CACHE_DIRECTORY=$(BIODB_CACHE_DIRECTORY))
$(info CODECOV_$(PKG_NAME_CAPS)_TOKEN=$(value CODECOV_$(PKG_NAME_CAPS)_TOKEN))
$(info RFLAGS=$(RFLAGS))
$(info TEST_FILE=$(TEST_FILE))
$(info BIODB_TEST_FUNCTIONS=$(BIODB_TEST_FUNCTIONS))

# Default target
all: $(COMPILE)

# Compiling
ifdef COMPILE
compile: R/RcppExports.R
	$(R) $(RFLAGS) CMD SHLIB -o src/$(PKG_NAME).so src/*.cpp

R/RcppExports.R: src/*.cpp
	$(R) $(RFLAGS) -e "Rcpp::compileAttributes('$(CURDIR)')"
endif

# Code coverage
coverage:
	$(R) $(RFLAGS) -e "covr::codecov(token='$(value CODECOV_$(PKG_NAME_CAPS)_TOKEN)', quiet=FALSE)"

# Plain check
check: clean.vignettes $(CHECK_RENVIRON) $(ZIPPED_PKG)
	$(R) $(RFLAGS) CMD check $(ZIPPED_PKG)

# Bioconductor check
bioc.check: clean.vignettes $(CHECK_RENVIRON) $(ZIPPED_PKG)
	$(R) $(RFLAGS) -e 'BiocCheck::BiocCheck("$(ZIPPED_PKG)"$(patsubst %,$(COMMA) `%`=TRUE,$(BIOC_CHECK_FLAGS)))'

# Bioconductor check Git clone
bioc.check.clone: clean clean.cache
	$(R) $(RFLAGS) -e 'BiocCheck::BiocCheckGitClone()'

check.all: bioc.check.clone check bioc.check

$(CHECK_RENVIRON):
	wget https://raw.githubusercontent.com/Bioconductor/packagebuilder/master/check.Renviron

# Run testthat tests
test: $(COMPILE)
ifdef VIM
	$(R) $(RFLAGS) -e "devtools::test('$(CURDIR)', filter=$(TEST_FILE), reporter=c('$(TESTTHAT_REPORTER)', 'fail'))" | sed 's!\([^/A-Za-z_-]\)\(test[^/A-Za-z][^/]\+\.R\)!\1tests/testthat/\2!'
else
	$(R) $(RFLAGS) -e "devtools::test('$(CURDIR)', filter=$(TEST_FILE), reporter=c('$(TESTTHAT_REPORTER)', 'fail'))"
endif

ifeq (,$(wildcard tests/long))
test.long:
	$(error No long tests folder tests/long defined. Please upgrade your with `make upgrade`)
else
test.long: BIODB_CACHE_DIRECTORY=$(LONG_CACHE)
test.long: install
	if test -d tests/long ; then $(R) $(RFLAGS) -e "testthat::test_dir('tests/long')" ; fi
endif

test.all: test test.long

# Launch Windows tests on server
win:
	$(R) $(RFLAGS) -e "devtools::check_win_devel('$(CURDIR)')"

# Build package zip
build: $(ZIPPED_PKG)

# Make zip
$(ZIPPED_PKG): clean.vignettes doc
	$(R) $(RFLAGS) CMD build .

NAMESPACE: # First time creation, then roxygen2 will fill it and keep it updated
	echo "# Generated by roxygen2: do not edit by hand" >$@

# Generation documentation
ifdef COMPILE
doc: install.deps NAMESPACE R/RcppExports.R
else
doc: install.deps NAMESPACE
endif
	$(R) $(RFLAGS) -e "devtools::document('$(CURDIR)')"

# Generate vignettes
vignettes: clean.vignettes
	@echo Build vignettes for already installed package, not from local soures.
	$(R) $(RFLAGS) -e "devtools::build_vignettes('$(CURDIR)')"

upgrade:
	$(R) $(RFLAGS) -e 'biodb::ExtPackage$$new(".")$$upgrade()'

# Install dependencies
install.deps:
	$(R) $(RFLAGS) -e "devtools::install_dev_deps('$(CURDIR)')"

# Install package
install: uninstall
	$(R) $(RFLAGS) -e "devtools::install_local('$(CURDIR)', dependencies = TRUE)"

# Uninstall package
uninstall:
	$(R) $(RFLAGS) -e "try(devtools::uninstall('$(CURDIR)'), silent = TRUE)"

# Clean all, included biodb cache
clean.all: clean clean.cache

# Clean
clean: clean.vignettes
ifdef COMPILE
	$(RM) src/*.o src/*.so src/*.dll
endif
	$(RM) -r tests/test.log tests/testthat/output tests/testthat/*.log
	$(RM) -r $(PKG_NAME).Rcheck
	$(RM) -r Meta
	$(RM) *.log
	$(RM) $(PKG_NAME)_*.tar.gz
	$(RM) $(CHECK_RENVIRON)

clean.all: clean clean.cache
	@echo "Clean also what is versioned but can be rebuilt."
	$(RM) -r inst/extdata/generated
	$(RM) -r man

# Clean vignettes
clean.vignettes:
	$(RM) vignettes/*.R vignettes/*.html
	$(RM) -r doc

# Clean biodb cache
clean.cache:
	$(RM) -r $(CACHE)
	$(RM) -r $(LONG_CACHE)

.PHONY: all win test build check bioc.check vignettes install uninstall clean clean.all clean.vignettes clean.cache doc coverage doxygen
