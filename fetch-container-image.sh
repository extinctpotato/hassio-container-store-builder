#!/usr/bin/env bash
#
# This script was originally taken from the Home Assistant Operating System repository.
# Commit: https://github.com/home-assistant/operating-system/commit/2114dd328f89886ce27e4e572d4fda036a3d85a1
#
# Original authors: Home Assistant Operating System Contributors
#
# This script has been modified for custom use.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

set -e
set -u
set -o pipefail

arch=$1
machine=$2
version_json=$3
dl_dir=$4
container=$5

__version_json() {
    jq '.core = "landingpage"' "$version_json"
}

__fetch_container_image() {
    local image_json_name image_name image_tag full_image_name image_digest image_file_name image_file_path

    image_json_name=$1
    image_name=$(jq -e -r --arg image_json_name "${image_json_name}" \
        --arg arch "${arch}" --arg machine "${machine}" \
        '.images[$image_json_name] | sub("{arch}"; $arch) | sub("{machine}"; $machine)' \
        <<< "$(__version_json)")
    image_tag=$(jq -e -r --arg image_json_name "${image_json_name}" \
        '.[$image_json_name]' <<< "$(__version_json)")
    full_image_name="${image_name}:${image_tag}"

    image_digest=$(skopeo inspect --retry-times=5 "docker://${full_image_name}" | jq -r '.Digest')

    # Cleanup image name file name use
    image_file_name="${full_image_name//[:\/]/_}@${image_digest//[:\/]/_}"
    image_file_path="${dl_dir}/${image_file_name}.tar"
    final_image_file_path="${dl_dir}/${container}.tar"

    (
        # Use file locking to avoid race condition
        flock --verbose 3
        if [ ! -f "${final_image_file_path}" ]
        then
            echo "Fetching image: ${full_image_name} (digest ${image_digest})"
            skopeo copy "docker://${image_name}@${image_digest}" "docker-archive:${image_file_path}:${full_image_name}"
            mv "${image_file_path}" "${dl_dir}/${container}.tar"
        else
            echo "Skipping download of existing image: ${full_image_name} (digest ${image_digest})"
        fi
    ) 3>"${image_file_path}.lock"
}

set -x

__fetch_container_image "$container"
