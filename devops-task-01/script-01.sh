#!/bin/bash
mkdir anything
cd anything
touch anythingfile
ls -la
echo "This sample is for the anything file for the task" > anythingfile
date >> anythingfile
ls -ltr
cat anythingfile
alias h='history'
h
unalias h
pwd
cp anythingfile anything2
mv anything2 copied-version
cd ..
rm -rf anything
