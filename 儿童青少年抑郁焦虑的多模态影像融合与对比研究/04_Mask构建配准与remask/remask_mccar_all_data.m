%% Remask existing MCCAR feature matrices without changing variable names
% This script subsets the existing feature columns using new masks.
% It cannot create values for voxels that were absent from the old mask.
%
% Required variables in ANI_mccar_all_Data.mat:
%   f_mask_falff, s_mask_gmv, d_mask_fa, V_f, V_s, V_d
%
% Output keeps the same variable names and preserves unrelated variables.
% The script stops if dimensions/affines differ or if a new mask contains
% voxels outside its old mask. These failures usually indicate an incorrect
% resampling/registration step and must not be silently ignored.

clearvars;
clc;

%% -------------------------- Configuration -----------------------------
% Configure paths through environment variables rather than embedding a
% server username or project location in this public script.
spmDirectory = getenv('SPM12_DIR');
if ~isempty(spmDirectory) && isfolder(spmDirectory)
    addpath(spmDirectory);
end
assert(exist('spm_vol', 'file') == 2, 'SPM12 was not found on the path.');

dataFile = getenv('MCCAR_DATA_MAT');
outputFile = getenv('MCCAR_REMASK_OUTPUT');
templateDirectory = getenv('BRAIN_TEMPLATE_DIR');
dtiDirectory = getenv('DTI_DIR');

assert(~isempty(dataFile), 'Set the MCCAR_DATA_MAT environment variable.');
assert(~isempty(outputFile), ...
    'Set the MCCAR_REMASK_OUTPUT environment variable.');
assert(~isempty(templateDirectory), ...
    'Set the BRAIN_TEMPLATE_DIR environment variable.');
assert(~isempty(dtiDirectory), 'Set the DTI_DIR environment variable.');

jobs = struct([]);

jobs(1).label = 'fALFF';
jobs(1).data_field = 'f_mask_falff';
jobs(1).header_field = 'V_f';
jobs(1).old_mask = fullfile(templateDirectory, 'falff_gmv_mask_raw.nii');
jobs(1).new_mask = fullfile(templateDirectory, ...
    'falff_Brainnetome_intersection_mask.nii');

jobs(2).label = 'GMV';
jobs(2).data_field = 's_mask_gmv';
jobs(2).header_field = 'V_s';
jobs(2).old_mask = fullfile(templateDirectory, ...
    'GMV_mask_gt0p1_present_gt90pct.nii');
jobs(2).new_mask = fullfile(templateDirectory, ...
    'gmv_Brainnetome_intersection_mask.nii');

jobs(3).label = 'FA';
jobs(3).data_field = 'd_mask_fa';
jobs(3).header_field = 'V_d';
jobs(3).old_mask = fullfile(dtiDirectory, 'fa_mask_3000.nii');
jobs(3).new_mask = fullfile(dtiDirectory, ...
    'fa_JHU_intersection_mask.nii');

maskThreshold = 0.9;
affineTolerance = 1e-4;

%% -------------------------- Load and remask ---------------------------
assert(isfile(dataFile), 'Input MAT file does not exist:\n%s', dataFile);
S = load(dataFile);
remaskInfo = struct();

for j = 1:numel(jobs)
    job = jobs(j);
    assert(isfield(S, job.data_field), ...
        'Variable %s was not found in %s.', job.data_field, dataFile);
    assert(isnumeric(S.(job.data_field)) && ...
        ismatrix(S.(job.data_field)), ...
        '%s must be a numeric 2-D matrix.', job.data_field);

    nExistingFeature = size(S.(job.data_field), 2);
    [selector, info, newHeader] = makeSelector(job.old_mask, ...
        job.new_mask, nExistingFeature, maskThreshold, ...
        affineTolerance, job.label);

    S.(job.data_field) = S.(job.data_field)(:, selector);
    S.(job.header_field) = newHeader;
    remaskInfo.(lower(job.label)) = info;

    fprintf('%s: %d -> %d features (%.2f%% retained)\n', ...
        job.label, info.n_old_voxel, info.n_new_voxel, ...
        info.retained_percent);
end

remaskInfo.created = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
remaskInfo.source_mat = dataFile;
remaskInfo.rule = ['Existing matrix columns were subset with new(old). ' ...
    'No out-of-old-mask voxel was fabricated.'];
S.remask_info = remaskInfo;

outputDirectory = fileparts(outputFile);
if ~isempty(outputDirectory) && ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end
save(outputFile, '-struct', 'S', '-v7.3');
fprintf('Saved remasked MAT file:\n%s\n', outputFile);

%% --------------------------- Local function ---------------------------
function [selector, info, Vnew] = makeSelector(oldMaskFile, newMaskFile, ...
        nExistingFeature, maskThreshold, affineTolerance, label)
    assert(isfile(oldMaskFile), '%s old mask not found:\n%s', ...
        label, oldMaskFile);
    assert(isfile(newMaskFile), '%s new mask not found:\n%s', ...
        label, newMaskFile);

    Vold = spm_vol(oldMaskFile);
    Vnew = spm_vol(newMaskFile);
    assert(numel(Vold) == 1 && numel(Vnew) == 1, ...
        '%s masks must be single 3-D volumes.', label);
    assert(isequal(double(Vold.dim), double(Vnew.dim)), ...
        ['%s mask dimensions differ. Resample the atlas/new mask to the ' ...
         'old-mask grid before remasking.'], label);

    affineDifference = max(abs(Vold.mat(:) - Vnew.mat(:)));
    assert(affineDifference <= affineTolerance, ...
        ['%s mask affine matrices differ (max difference %.6g). ' ...
         'Do not remask until the spaces are aligned.'], ...
        label, affineDifference);

    oldMask = spm_read_vols(Vold) > maskThreshold;
    newMask = spm_read_vols(Vnew) > maskThreshold;
    nOldVoxel = nnz(oldMask);
    nNewVoxel = nnz(newMask);
    nOutsideOld = nnz(newMask & ~oldMask);

    assert(nExistingFeature == nOldVoxel, ...
        ['%s data contains %d feature columns, but its old mask contains ' ...
         '%d voxels. Column-to-voxel correspondence is not valid.'], ...
        label, nExistingFeature, nOldVoxel);
    assert(nOutsideOld == 0, ...
        ['%s new mask contains %d voxels outside the old mask. Existing ' ...
         'feature data have no values for these voxels. Rebuild the new ' ...
         'mask as old_mask AND atlas, or re-extract from subject NIfTI.'], ...
        label, nOutsideOld);

    % MATLAB column-major mask order matches data originally extracted by
    % data(:, oldMask(:)). selector has one entry per old-mask feature.
    selector = newMask(oldMask);
    assert(nnz(selector) == nNewVoxel, ...
        '%s internal selector count is inconsistent.', label);

    info = struct();
    info.old_mask = oldMaskFile;
    info.new_mask = newMaskFile;
    info.n_old_voxel = nOldVoxel;
    info.n_new_voxel = nNewVoxel;
    info.n_new_outside_old = nOutsideOld;
    info.retained_percent = 100 * nNewVoxel / nOldVoxel;
    info.affine_max_abs_difference = affineDifference;
end
