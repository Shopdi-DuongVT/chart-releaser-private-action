#!/usr/bin/env bash

# Copyright 2021 Miguel Araujo

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

index_file_path="../.cr-index/index.yaml"

cd publicRepo

if [ -f $index_file_path ]; then
    echo "Pushing updated index to public repo..."

    mv $index_file_path .
    git add index.yaml
    git commit -m "Update index.yaml"
    git push -u origin gh-pages
fi
