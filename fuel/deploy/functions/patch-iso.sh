#!/bin/bash
##############################################################################
# Copyright (c) 2015 Ericsson AB and others.
# stefan.k.berg@ericsson.com
# jonas.bjurel@ericsson.com
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# This is a temporary script - this should be rolled into a separate
# build target "make ci-iso" instead!

exit_handler() {
  rm -Rf $tmpnewdir
  fusermount -u $tmporigdir 2>/dev/null
  test -d $tmporigdir && mdir $tmporigdir
}

trap exit_handler exit

error_exit() {
  echo "$@"
  exit 1
}


top=$(cd `dirname $0`; pwd)
origiso=$(cd `dirname $1`; echo `pwd`/`basename $1`)
newiso=$(cd `dirname $2`; echo `pwd`/`basename $2`)
tmpdir=$3
tmporigdir=/${tmpdir}/origiso
tmpnewdir=/${tmpdir}/newiso

test -f $origiso || error_exit "Could not find origiso $origiso"
test -d $tmpdir || error_exit "Could not find tmpdir $tmpdir"


if [ "`whoami`" != "root" ]; then
  error_exit "You need be root to run this script"
fi

echo "Copying..."
rm -Rf $tmporigdir $tmpnewdir
mkdir -p $tmporigdir $tmpnewdir
fuseiso $origiso $tmporigdir || error_exit "Failed fuseiso"
cd $tmporigdir
find . | cpio -pd $tmpnewdir
cd $tmpnewdir
fusermount -u $tmporigdir
rmdir $tmporigdir
chmod -R 755 $tmpnewdir

echo "Patching..."
cd $tmpnewdir
# Patch ISO to make it suitable for automatic deployment
cat $top/ks.cfg.patch | patch -p0 || error_exit "Failed patch 1"
cat $top/isolinux.cfg.patch | patch -p0 || error_exit "Failed patch 2"
rm -rf .rr_moved

echo "Creating iso $newiso"
mkisofs -quiet -r  \
  -J -R -b isolinux/isolinux.bin \
  -no-emul-boot \
  -boot-load-size 4 -boot-info-table \
  --hide-rr-moved \
  -x "lost+found" -o $newiso . || error_exit "Failed making iso"

