#!/bin/bash

project="./project"
testFolder="./project_input_output_files/test"

echo "--------------------------------------------"
make
make clean
echo "--------------------------------------------"
echo

for file in $testFolder/*; do
    if [ -f $file ]; then
        echo "--- Testing file \"$file\". ---" 
        $project $file
        echo "--------------------------------------------"
        echo
    fi
done
