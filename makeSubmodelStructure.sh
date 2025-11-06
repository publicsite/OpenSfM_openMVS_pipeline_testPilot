#!/bin/sh

OLD_UMASK="$(umask)"
umask 0022

if ! [ -d "$1" ]; then
printf "Argument 1: Dataset \"$1\" does not exist.\n"
exit
fi

if [ -z "$2" ]; then
printf "Argument 2: Image prefix.\n"
exit
fi

if [ -z "$3" ]; then
printf "Argument 3: Four digit submodel number.\n"
printf "Reminder: Integers are indexed from 0000\n"
exit
fi

mkdir -p "$1/submodels/submodel_$3"
cd "$1/submodels/submodel_$3"

if [ -f "../../config.yaml" ]; then
	cp -a ../../config.yaml .
fi

if [ -d "../../images" ]; then
	ln -s "../../images"
fi

if [ -d "../../exif" ]; then
	ln -s "../../exif"
fi

if [ -d "../../features" ]; then
	ln -s "../../features"
fi

if [ -d "../../matches" ]; then
	ln -s "../../matches"
fi

if [ -f "../../camera_models.json" ]; then
	ln -s ../../camera_models.json
fi

if [ -f "../../camera_models.json" ]; then
	ln -s ../../reference_lla.json
fi

cd ../../images

find . -name "${2}*" | cut -c 3- > ../submodels/submodel_$3/image_list.txt

umask "${OLD_UMASK}"

