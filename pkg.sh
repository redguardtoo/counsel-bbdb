#!/bin/bash
name=counsel-bbdb
version=0.0.4
pkg=$name-$version
mkdir $pkg
cp *.el $pkg
cat << EOF > $pkg/$name-pkg.el
(define-package "$name" "$version" "Quick search&input email from BBDB")
EOF
if [[ `uname -s` == *Darwin* ]]; then
   COPYFILE_DISABLE="" tar cvf $pkg.tar $pkg/
else
   tar cvf $pkg.tar $pkg/
fi
rm -rf $pkg/
