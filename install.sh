#!/usr/bin/env bash

DST=$1

rm -rf "$DST/android" "$DST/ios" "$DST/index.js"

cp -R android "$DST"
cp -R ios "$DST"
cp index.js "$DST"
