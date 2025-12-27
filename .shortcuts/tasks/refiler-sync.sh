#!/data/data/com.termux/files/usr/bin/env bash

cd ~/storage/orgfiles || termux-toast "Dir not found"

git pull --ff-only || termux-toast "Conflicts: pull failed"

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "from phone $(date '+%Y-%m-%d %H:%M:%S %z')"
  git push origin master || termux-toast "Conflicts: push failed"
  termux-toast "OK: pushed"
else
  termux-toast "OK: nothing to do"
fi
