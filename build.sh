#!/usr/bin/env bash
set -eou pipefail
cd "$(dirname "$0")"

# build thir (generated and final files will created here)
b=build
# media dir (original recorded files)
m=media
# main generated video
main_video=${main_video:-$(basename $PWD).mkv}

# TEMPORARY code:
rm -rf $b

# Update $m/links.sh if it is outdated
if [ links.sh -nt $m/links.sh ]
then
  echo 'Updating $m/links.sh ...'
  cp links.sh $m/
  chmod +x $m/links.sh
fi

# Recreate the links inside $m
$m/links.sh

# Create the build directory
mkdir -p $b

convert-from-mp4-to-mkv() {
  local mkv=${1##*/}
  local mkv=$b/${mkv%.mp4}.mkv
  echo -e "Converting $1 to $mkv ..."
  ffmpeg -i $1 -vcodec copy -acodec copy $mkv &> ffmpeg.log
}

# Generate break*.mkv from break*.png
for f in $m/*break*.png
do
  mp4=${f##*/}
  mp4=$b/${mp4%.png}.mp4
  echo -e "Generating $mp4 from $f ..."
  rm -f $mp4
  ffmpeg -r 1/5 -i $f -c:v libx264 -vf fps=25 -pix_fmt yuv420p $mp4 &> ffmpeg.log
  ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -i $mp4 -c:v copy -c:a aac -shortest $b/silent.mp4 &> ffmpeg.log
  mv $b/silent.mp4 $mp4
  convert-from-mp4-to-mkv $mp4
  rm -f $mp4
done

# Convert all mp4 videos to mkv
for f in $m/*.mp4
do
  convert-from-mp4-to-mkv $f
done

# Make a list of the ordered files
ordered_files=(`cat ordered_files.txt`)

convert-audio-from-mono-to-stereo() {
  if [ -f "$m/$f.m4a" ] && ! [ -f "$b/$f.m4a" ]
  then
    echo -e "Converting audio $m/$f.m4a to $b/$f.m4a ..."
    ffmpeg -i "$m/$f.m4a" -ac 2 "$b/$f.m4a" &> ffmpeg.log
  fi
}

add-audio-to-video() {
  if [ -f "$b/$f.m4a" ] && [ -f "$m/$f.mkv" ] && ! [ -f "$b/$f.mkv" ]
  then
    echo -e "Adding audio $m/$f.m4a to $b/$f.mkv ..."
    mkvmerge -o $b/$f.mkv -A $m/$f.mkv $b/$f.m4a &> mkvmerge.log
  fi
}

# Make the command line that will be passed to mkvmerge
first_file=true
for f in ${ordered_files[@]}
do
  convert-audio-from-mono-to-stereo
  add-audio-to-video
  d=$m
  ! [ -f "$b/$f.mkv" ] || d=$b
  if $first_file
  then
    mkvmerge_cmdline="-o $b/$main_video $d/$f.mkv"
    first_file=false
  else
    mkvmerge_cmdline="$mkvmerge_cmdline +$d/$f.mkv"
  fi
done

# Build the main video
echo -e "\nBuilding $b/$main_video ..."
mkvmerge $mkvmerge_cmdline &> mkvmerge.log
