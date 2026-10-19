%% Build atlas-constrained fALFF, GMV, and FA masks
% The operation is INTERSECTION, never union:
%   fALFF new mask = fALFF old mask AND Brainnetome coverage
%   GMV new mask   = GMV old mask   AND Brainnetome coverage
%   FA new mask    = FA old mask    AND JHU white-matter coverage
%
% SPM resampling uses nearest-neighbour interpolation. This script assumes
% that each atlas and its target mask are already in the same MNI world
% space. If they belong to different MNI templates, first use the ANTs
% registration script supplied in this directory.

clearvars;
clc;

scriptDirectory = fileparts(mfilename('fullpath'));
addpath(scriptDirectory);

%% -------------------------- Configuration -----------------------------
% Configure paths through environment variables, for example:
%   export SPM12_DIR=/path/to/spm12
%   export BRAIN_TEMPLATE_DIR=/path/to/Brain_templates
%   export DTI_DIR=/path/to/Datasets/dti
spmDirectory = getenv('SPM12_DIR');
if ~isempty(spmDirectory) && isfolder(spmDirectory)
    addpath(spmDirectory);
end
assert(exist('spm_vol', 'file') == 2, 'SPM12 was not found on the path.');

templateDirectory = getenv('BRAIN_TEMPLATE_DIR');
dtiDirectory = getenv('DTI_DIR');
assert(~isempty(templateDirectory), ...
    'Set the BRAIN_TEMPLATE_DIR environment variable.');
assert(~isempty(dtiDirectory), 'Set the DTI_DIR environment variable.');

brainnetomeAtlas = fullfile(templateDirectory, 'BN_Atlas_246_1mm.nii');
jhuAtlas = fullfile(dtiDirectory, 'JHU-WhiteMatter-labels-1mm.nii');

% Replace these paths when the masks are stored elsewhere.
oldFalffMask = fullfile(templateDirectory, 'falff_gmv_mask_raw.nii');
oldGmvMask = fullfile(templateDirectory, ...
    'GMV_mask_gt0p1_present_gt90pct.nii');
oldFaMask = fullfile(dtiDirectory, 'fa_mask_3000.nii');

resampledBnFalff = fullfile(templateDirectory, ...
    'rBN_Atlas_246_on_fALFF_grid.nii');
resampledBnGmv = fullfile(templateDirectory, ...
    'rBN_Atlas_246_on_GMV_grid.nii');
resampledJhuFa = fullfile(dtiDirectory, ...
    'rJHU_WhiteMatter_on_FA_grid.nii');

newFalffMask = fullfile(templateDirectory, ...
    'falff_Brainnetome_intersection_mask.nii');
newGmvMask = fullfile(templateDirectory, ...
    'gmv_Brainnetome_intersection_mask.nii');
newFaMask = fullfile(dtiDirectory, 'fa_JHU_intersection_mask.nii');

maskThreshold = 0.9;

%% -------------------- Resample atlases to mask grids ------------------
resample_atlas_to_mask_spm(oldFalffMask, brainnetomeAtlas, ...
    resampledBnFalff);
resample_atlas_to_mask_spm(oldGmvMask, brainnetomeAtlas, ...
    resampledBnGmv);
resample_atlas_to_mask_spm(oldFaMask, jhuAtlas, resampledJhuFa);

%% ------------------------- Take intersections -------------------------
falffInfo = writeIntersection(oldFalffMask, resampledBnFalff, ...
    newFalffMask, maskThreshold, 'fALFF x Brainnetome');
gmvInfo = writeIntersection(oldGmvMask, resampledBnGmv, ...
    newGmvMask, maskThreshold, 'GMV x Brainnetome');
faInfo = writeIntersection(oldFaMask, resampledJhuFa, ...
    newFaMask, maskThreshold, 'FA x JHU');

summaryTable = struct2table([falffInfo; gmvInfo; faInfo]);
disp(summaryTable);

%% --------------------------- Local function ---------------------------
function info = writeIntersection(oldMaskFile, atlasFile, outputFile, ...
        maskThreshold, label)
    Vold = spm_vol(oldMaskFile);
    Vatlas = spm_vol(atlasFile);
    assert(numel(Vold) == 1 && numel(Vatlas) == 1, ...
        '%s inputs must be single 3-D volumes.', label);
    assert(isequal(double(Vold.dim), double(Vatlas.dim)), ...
        '%s dimensions do not match after resampling.', label);
    assert(max(abs(Vold.mat(:) - Vatlas.mat(:))) < 1e-4, ...
        '%s affine matrices do not match after resampling.', label);

    oldMask = spm_read_vols(Vold) > maskThreshold;
    atlasCoverage = spm_read_vols(Vatlas) > 0;
    intersectionMask = oldMask & atlasCoverage;

    Vout = Vold;
    Vout.fname = outputFile;
    Vout.dt = [spm_type('uint8'), 0];
    Vout.pinfo = [1; 0; 0];
    Vout.descrip = [label, ' intersection mask'];
    spm_write_vol(Vout, uint8(intersectionMask));

    info = struct();
    info.modality = string(label);
    info.old_mask_voxels = nnz(oldMask);
    info.atlas_coverage_voxels = nnz(atlasCoverage);
    info.intersection_voxels = nnz(intersectionMask);
    info.retained_percent = 100 * nnz(intersectionMask) / nnz(oldMask);
    info.output_file = string(outputFile);

    fprintf('%s: retained %d/%d voxels (%.2f%%)\n', label, ...
        info.intersection_voxels, info.old_mask_voxels, ...
        info.retained_percent);
end
