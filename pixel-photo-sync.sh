#!/bin/bash

## Initialize folders
mkdir -p /files/PhotosSynced/
mkdir -p /files/PhotosPending/

shopt -s globstar

while true; do
  date
  timeout $(($RANDOM % 15))m inotifywait -e modify,create,delete -r /files/Photos 
  echo "Waiting for 1m ..."
  sleep 1m
  
  ## construct files that are already synced to skip.
  find /files/PhotosSynced/ -type f | xargs -n 1 -d '\n' basename > /files/alreadySynced.txt
  find /PhotosArchive/ -type f | xargs -n 1 -d '\n' basename >> /files/alreadySynced.txt
  echo '*.part' >> /files/alreadySynced.txt
  cp /files/alreadySynced.txt /files/PhotosPending/.stignore

  ## remove files already synced from Pending.
  while read -r file ; do rm -f "/files/PhotosPending/$file" ; done < /files/alreadySynced.txt

  ## sync files from source; ignore those already synced.
  nice rsync -avXAh --progress --delete --delete-excluded --bwlimit=15000 --exclude-from /files/alreadySynced.txt /files/Photos/**/*.* /files/PhotosPending/

  ## Some Live photo mov files having problems,
  ## re-encode those older than 1 days and less than 10MB
  mkdir -p /files/PhotosPending-mov-fix

  OIFS="$IFS"
  IFS=$'\n'
  for file in `find /files/PhotosPending/ -mtime +1 -size -10M -type f -name "*.mov"` ;
  do
    echo "Fixing: ${file}" ;
    cp -p "$file" /files/PhotosPending-mov-fix/in.mov ;
    ffmpeg -hide_banner -loglevel warning -i /files/PhotosPending-mov-fix/in.mov -c copy -map_metadata 0 -map_metadata:s:v 0:s:v -map_metadata:s:a 0:s:a -movflags use_metadata_tags -y /files/PhotosPending-mov-fix/out.mov ;
    chown --reference=/files/PhotosPending-mov-fix/in.mov /files/PhotosPending-mov-fix/out.mov ;
    chmod --reference=/files/PhotosPending-mov-fix/in.mov /files/PhotosPending-mov-fix/out.mov ;
    touch --reference=/files/PhotosPending-mov-fix/in.mov /files/PhotosPending-mov-fix/out.mov ;
    mv /files/PhotosPending-mov-fix/out.mov "$file" ;
    rm /files/PhotosPending-mov-fix/in.mov ;
  done
  IFS="$OIFS"

  find /files/PhotosSynced/ -type f | xargs -n 1 -d '\n' basename > /files/PhotosSynced.txt
  find /PhotosArchive/ -type f | xargs -n 1 -d '\n' basename >> /files/PhotosSynced.txt

  find /files/PhotosPending/ -type f | xargs -n 1 -d '\n' basename > /files/PhotosPending.txt
  find /files/Photos/ -type f | xargs -n 1 -d '\n' basename > /files/Photos.txt

  sort /files/PhotosSynced.txt > /files/PhotosSynced.txt.sort
  sort /files/PhotosPending.txt > /files/PhotosPending.txt.sort
  sort /files/Photos.txt > /files/Photos.txt.sort

  comm -13 <(sort /files/Photos.txt.sort) <(sort /files/PhotosSynced.txt.sort) > /files/lostFiles.txt
  comm -23 <(sort /files/Photos.txt.sort) <(sort /files/PhotosSynced.txt.sort) > /files/missingFiles.txt

  wc /files/Photos.txt.sort
  wc /files/PhotosPending.txt.sort
  wc /files/PhotosSynced.txt.sort

  wc /files/alreadySynced.txt
  wc /files/PhotosPending/.stignore

  set -x

  wc /files/lostFiles.txt
  head /files/lostFiles.txt
  tail /files/lostFiles.txt

  wc /files/missingFiles.txt
  head /files/missingFiles.txt
  tail /files/missingFiles.txt

  set +x

  ## Move files older than 7 days from Synced to Archive
  find /files/PhotosSynced/ -mtime +7 | cut -f4- -d/ |sort > /files/moveToArchive.txt
  rsync -avXAh --progress --remove-source-files --files-from /files/moveToArchive.txt /files/PhotosSynced/ /PhotosArchive/ 

  ## doing the same from Photos to Archive
  cat /files/alreadySynced.txt | xargs -n 1 -d '\n' find /files/Photos/ -mtime +7 -name |  cut -f4- -d/ | sort > /files/photosMoveToArchive.txt
  rsync -avXAh --progress --remove-source-files --files-from /files/photosMoveToArchive.txt /files/Photos/ /PhotosArchive/

  set -x

  wc /files/lostFiles.txt

  wc /files/missingFiles.txt
  head /files/missingFiles.txt
  tail /files/missingFiles.txt

  set +x

done
  
