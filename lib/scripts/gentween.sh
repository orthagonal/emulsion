# $2  exponent frequency (number of frames) to be generated
# $3  filepath of the start frame
# $4  filepath of the end frame
# $5  output folder
cd rife
python.exe inference_img.py --exp $2 --img $3 $4 --folderout ./temptween
cd ..
mv ./rife/temptween/* $5
