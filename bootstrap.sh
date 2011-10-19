#!/bin/bash

pushd out/target/product/galaxysl/root/
find . | cpio -o -H newc | gzip > ../bootstrap/ramdisk.cpio.gz
popd

pushd out/target/product/galaxysl/recovery/root/
find . | cpio -o -H newc | gzip > ../../bootstrap/ramdisk-recovery.cpio.gz
popd

pushd out/target/product/galaxysl/bootstrap/
find . | cpio -o -H newc | gzip > ../bootstrap.cpio.gz
popd

exit 0
