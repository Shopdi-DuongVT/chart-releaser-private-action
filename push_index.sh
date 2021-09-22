#!/usr/bin/env bash

index_file_path="../.cr-index/index.yaml"

cd publicRepo

if [ -f $index_file_path ]; then
    echo "Pushing updated index to public repo..."

    mv $index_file_path .
    git add index.yaml
    git commit -m "Update index.yaml"
    git push -u origin gh-pages
fi
