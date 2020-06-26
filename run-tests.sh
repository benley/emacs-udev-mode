#!/bin/sh
# Based on https://github.com/purcell/package-lint/blob/master/run-tests.sh
set -e

log() {
  echo "$*" 1>&2
}

EMACS="${EMACS:=emacs}"

NEEDED_PACKAGES="package-lint"

INIT_PACKAGE_EL="(progn \
  (require 'package) \
  (push '(\"melpa\" . \"https://melpa.org/packages/\") package-archives) \
  (package-initialize) \
  (unless package-archive-contents \
     (package-refresh-contents)) \
  (dolist (pkg '(${NEEDED_PACKAGES})) \
    (unless (package-installed-p pkg) \
      (package-install pkg))))"

# Refresh package archives, because the test suite needs to see at least
# package-lint and cl-lib.
log "Refreshing package archives"
"$EMACS" -Q -batch \
         --eval "$INIT_PACKAGE_EL"

# Byte compile, failing on byte compiler errors, or on warnings unless ignored
if [ -n "${EMACS_LINT_IGNORE+x}" ]; then
    ERROR_ON_WARN=nil
else
    ERROR_ON_WARN=t
fi

log "Byte-compiling"
"$EMACS" -Q -batch \
         --eval "$INIT_PACKAGE_EL" \
         --eval "(setq byte-compile-error-on-warn ${ERROR_ON_WARN})" \
         -f batch-byte-compile \
         udev-mode.el

# Lint ourselves
# Lint failures are ignored if EMACS_LINT_IGNORE is defined, so that lint
# failures on Emacs 24.2 and below don't cause the tests to fail, as these
# versions have buggy imenu that reports (defvar foo) as a definition of foo.
log "Running package-lint"
"$EMACS" -Q -batch \
         --eval "$INIT_PACKAGE_EL" \
         -f package-lint-batch-and-exit \
         udev-mode.el || [ -n "${EMACS_LINT_IGNORE+x}" ]

# Finally, run the testsuite
log "Running ert tests"
"$EMACS" -Q -batch \
         --eval "$INIT_PACKAGE_EL" \
         -f ert-run-tests-batch-and-exit
