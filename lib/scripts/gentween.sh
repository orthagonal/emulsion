cd rife
echo "running rife"
echo $2 $3 $4
python.exe inference_img.py --exp $2 --img $3 $4 --folderout ./temptween
cd ..
mv ./rife/temptween/* $5
