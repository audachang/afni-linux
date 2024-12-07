#!/usr/bin/tcsh -ef

#sudo chmod -R u+rw .
set comments = $1
git add .
git commit -m $comments
git push origin main

