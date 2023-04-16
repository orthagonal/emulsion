# folder, # of frames, ffmpeg parameters, outPath
ffmpeg  -start_number 1 -i $1 -frames:v $2 $3 $4
#echo "ffmpeg  -start_number 1 -i $1 -frames:v $2 $3 $4"
