#!/bin/sh
# CI archive step only. Usage: script CHECKOUT_ROOT ENVIRONMENT_PLIST ARCHIVE_DSYMS
set -eu
if [ "$#" -ne 3 ]; then echo 'Expected Firebase checkout, environment plist, archive dSYMs' >&2; exit 2; fi
uploader="$1/Crashlytics/upload-symbols"
[ -x "$uploader" ] && [ -f "$2" ] && [ -d "$3" ] || { echo 'Missing Crashlytics symbol upload input' >&2; exit 2; }
"$uploader" -gsp "$2" -p ios "$3"
