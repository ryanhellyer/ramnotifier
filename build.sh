#!/usr/bin/env bash
chmod u+x ramnotifier
mkdir ramnotifier-1
cp ramnotifier ramnotifier-1/
cd ramnotifier-1/
dh_make -s --createorig
grep -v makefile debian/rules > debian/rules.new
mv debian/rules.new debian/rules
echo ramnotifier usr/bin > debian/install
echo "1.0" > debian/source/format
rm debian/*.ex
debuild -us -uc
cd ..
mv ramnotifier_1-1_amd64.deb ramnotifier_v1.deb
rm ramnotifier-1 -R
rm ramnotifier_1* -R
