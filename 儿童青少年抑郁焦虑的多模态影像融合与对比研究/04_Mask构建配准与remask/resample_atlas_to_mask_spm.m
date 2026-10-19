function outputAtlas = resample_atlas_to_mask_spm( ...
        referenceMask, inputAtlas, outputAtlas)
%RESAMPLE_ATLAS_TO_MASK_SPM Put an atlas on a mask grid using nearest neighbour.
%
% This function performs resampling only. It is appropriate when the atlas
% and reference mask are already expressed in the same MNI world-coordinate
% space but have different voxel sizes, dimensions, or origins.
%
% It does NOT estimate a nonlinear transform between different MNI template
% spaces. For that case, first run register_mni_atlas_with_ants.sh.

assert(isfile(referenceMask), ...
    'Reference mask does not exist:\n%s', referenceMask);
assert(isfile(inputAtlas), 'Atlas does not exist:\n%s', inputAtlas);

[~, ~, outputExtension] = fileparts(outputAtlas);
assert(strcmpi(outputExtension, '.nii'), ...
    'outputAtlas must use an uncompressed .nii extension for SPM.');

Vref = spm_vol(referenceMask);
Vatlas = spm_vol(inputAtlas);
assert(numel(Vref) == 1 && numel(Vatlas) == 1, ...
    'Reference and atlas must both be single 3-D volumes.');

outputDirectory = fileparts(outputAtlas);
if ~isempty(outputDirectory) && ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

sameDimensions = isequal(double(Vref.dim), double(Vatlas.dim));
sameAffine = max(abs(Vref.mat(:) - Vatlas.mat(:))) < 1e-5;

if sameDimensions && sameAffine
    atlasData = spm_read_vols(Vatlas);
    Vout = Vatlas;
    Vout.fname = outputAtlas;
    spm_write_vol(Vout, atlasData);
else
    temporaryDirectory = tempname;
    mkdir(temporaryDirectory);
    cleanupObject = onCleanup(@() safeRemoveDirectory(temporaryDirectory)); %#ok<NASGU>

    temporaryReference = fullfile(temporaryDirectory, 'reference.nii');
    temporaryAtlas = fullfile(temporaryDirectory, 'atlas.nii');
    copyfile(referenceMask, temporaryReference);
    copyfile(inputAtlas, temporaryAtlas);

    flags = struct();
    flags.interp = 0;       % nearest neighbour: required for labels/masks
    flags.wrap = [0 0 0];
    flags.mask = 0;
    flags.mean = 0;
    flags.which = 1;
    flags.prefix = 'r';

    spm_reslice(char(temporaryReference, temporaryAtlas), flags);
    generatedAtlas = fullfile(temporaryDirectory, 'ratlas.nii');
    assert(isfile(generatedAtlas), ...
        'SPM did not generate the expected resliced atlas.');
    copyfile(generatedAtlas, outputAtlas);
end

Vcheck = spm_vol(outputAtlas);
assert(isequal(double(Vcheck.dim), double(Vref.dim)), ...
    'Resampled atlas dimensions do not match the reference mask.');
assert(max(abs(Vcheck.mat(:) - Vref.mat(:))) < 1e-4, ...
    'Resampled atlas affine does not match the reference mask.');

fprintf('Saved nearest-neighbour atlas: %s\n', outputAtlas);
end

function safeRemoveDirectory(directoryPath)
if isfolder(directoryPath)
    rmdir(directoryPath, 's');
end
end
