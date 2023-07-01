# cut out a subclip from a video file
# args: $1 = input path, $2 = start frame, $3 = # of frames after that, $4 = output file
# echo "ffmpeg -framerate 23.976 -start_number $2 -f image2 -i $1/img_%04d.png -c:v vp9 -format yva420p -r $3 -minrate 5200k -maxrate 15200k -b:v 5200k $4 -hide_banner "
# ffmpeg -framerate 23.976 -start_number $2 -f image2 -i $1/img_%04d.png -c:v vp9 -format yva420p -r $3 -minrate 5200k -maxrate 15200k -b:v 5200k $4 -hide_banner 
# ffmpeg -framerate 23.976 -start_number $2 -f image2 -i $1/img_%04d.png -c:v vp9 -format rgba -r $3 -minrate 5200k -maxrate 15200k -b:v 5200k $4 -hide_banner 
ffmpeg -framerate 23.976 -start_number $2 -f image2 -i $1/img_%04d.png -frames:v $3 -c:v vp9 -format yva420p -minrate 5200k -maxrate 15200k -b:v 5200k $4 -hide_banner 

# ffmpeg -start_number $2 -i $1/img%d.png -frames:v $3 -c:v vp9 -s 1920x1080 $4
#  "1920x1080", "-pix_fmt", "yuva420p