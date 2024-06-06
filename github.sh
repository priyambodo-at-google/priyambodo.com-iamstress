#/bin/bash
git config --global user.name "Doddi Priyambodo"
git config --global user.email "doddi@bicarait.com"
git add .
git commit -a -m "Doddi Priyambodo is committing at $(date +"%Y-%m-%d %H:%M:%S")"
git push

#'----------------------------------'
echo "# priyambodo.com-iamstress" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/priyambodo-at-google/priyambodo.com-iamstress.git
git push -u origin main

#'----------------------------------'
git remote add origin https://github.com/priyambodo-at-google/priyambodo.com-iamstress.git
git branch -M main
git push -u origin main
