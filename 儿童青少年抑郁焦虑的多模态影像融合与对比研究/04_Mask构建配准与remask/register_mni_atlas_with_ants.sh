#!/usr/bin/env bash
set -euo pipefail

# Estimate a source-MNI-template -> target-MNI-template transform from the
# anatomical templates, then apply it to an atlas with label interpolation.
# Never estimate the transform directly from a discrete atlas label image.
#
# Usage:
#   bash register_mni_atlas_with_ants.sh \
#     source_MNI_T1.nii.gz target_MNI_T1.nii.gz source_atlas.nii.gz \
#     target_grid_reference.nii.gz output_prefix atlas_in_target_space.nii.gz

if [[ $# -ne 6 ]]; then
  echo "Usage: $0 SOURCE_T1 TARGET_T1 SOURCE_ATLAS TARGET_REFERENCE OUTPUT_PREFIX OUTPUT_ATLAS" >&2
  exit 2
fi

source_t1=$1
target_t1=$2
source_atlas=$3
target_reference=$4
output_prefix=$5
output_atlas=$6

for required_file in "$source_t1" "$target_t1" "$source_atlas" "$target_reference"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing input: $required_file" >&2
    exit 1
  fi
done

command -v antsRegistrationSyNQuick.sh >/dev/null 2>&1 || {
  echo "antsRegistrationSyNQuick.sh was not found in PATH." >&2
  exit 1
}
command -v antsApplyTransforms >/dev/null 2>&1 || {
  echo "antsApplyTransforms was not found in PATH." >&2
  exit 1
}

# Fixed image defines the target MNI template space; moving image defines
# the source MNI template space in which BN/JHU is distributed.
antsRegistrationSyNQuick.sh \
  -d 3 \
  -f "$target_t1" \
  -m "$source_t1" \
  -o "$output_prefix" \
  -t s

# GenericLabel/nearest-neighbour interpolation preserves integer atlas IDs.
# Transform order follows ANTs' source-to-target application convention.
antsApplyTransforms \
  -d 3 \
  -i "$source_atlas" \
  -r "$target_reference" \
  -o "$output_atlas" \
  -n GenericLabel \
  -t "${output_prefix}1Warp.nii.gz" \
  -t "${output_prefix}0GenericAffine.mat"

echo "Saved registered atlas: $output_atlas"
