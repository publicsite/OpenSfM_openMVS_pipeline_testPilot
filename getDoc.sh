#!/bin/sh
OLD_UMASK="$(umask)"
umask 0022

git clone https://github.com/cdcseacave/openMVS.wiki.git

umask "${OLD_UMASK}"
