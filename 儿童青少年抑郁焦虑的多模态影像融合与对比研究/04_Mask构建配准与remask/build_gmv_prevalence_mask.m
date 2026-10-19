function summary = build_gmv_prevalence_mask(matFile, referenceNifti, ...
        outputNifti, intensityThreshold, subjectFraction, chunkSize)
%BUILD_GMV_PREVALENCE_MASK Build a group GMV mask from gmv_200.mat.
%
% A voxel is retained when:
%   1. its GMV value is greater than intensityThreshold; and
%   2. more than subjectFraction of subjects meet criterion 1.
%
% Default settings implement the requested rule:
%   GMV > 0.1 in more than 90% of subjects.
%
% The MAT file must contain a two-dimensional variable named data. One
% dimension must equal prod(reference NIfTI dimensions). The function
% automatically detects whether data is subjects x voxels or the reverse.
% Chunked access requires the MAT file to support partial loading (normally
% a -v7.3 MAT file).

if nargin < 4 || isempty(intensityThreshold)
    intensityThreshold = 0.1;
end
if nargin < 5 || isempty(subjectFraction)
    subjectFraction = 0.90;
end
if nargin < 6 || isempty(chunkSize)
    chunkSize = 50000;
end

assert(isfile(matFile), 'MAT file does not exist:\n%s', matFile);
assert(isfile(referenceNifti), ...
    'Reference NIfTI does not exist:\n%s', referenceNifti);
assert(subjectFraction > 0 && subjectFraction < 1, ...
    'subjectFraction must be between 0 and 1.');
assert(intensityThreshold >= 0, ...
    'intensityThreshold must be nonnegative.');

Vref = spm_vol(referenceNifti);
assert(numel(Vref) == 1, 'Reference NIfTI must be a single 3-D volume.');
nVoxel = prod(double(Vref.dim));

variables = whos('-file', matFile);
dataInfo = variables(strcmp({variables.name}, 'data'));
assert(~isempty(dataInfo), 'Variable data was not found in:\n%s', matFile);
assert(numel(dataInfo.size) == 2, 'Variable data must be two-dimensional.');

dataSize = double(dataInfo.size);
if dataSize(2) == nVoxel
    subjectDimension = 1;
    nSubject = dataSize(1);
elseif dataSize(1) == nVoxel
    subjectDimension = 2;
    nSubject = dataSize(2);
else
    error(['Neither dimension of data matches the reference image.\n' ...
        'data size: %s\nreference voxel count: %d'], ...
        mat2str(dataSize), nVoxel);
end

% Strictly more than 90% means at least 181 of 200 subjects.
requiredCount = floor(subjectFraction * nSubject) + 1;
presenceCount = zeros(nVoxel, 1, 'uint32');
M = matfile(matFile);

for firstVoxel = 1:chunkSize:nVoxel
    lastVoxel = min(firstVoxel + chunkSize - 1, nVoxel);

    if subjectDimension == 1
        block = M.data(:, firstVoxel:lastVoxel);
        blockCount = sum(isfinite(block) & block > intensityThreshold, 1);
        presenceCount(firstVoxel:lastVoxel) = uint32(blockCount(:));
    else
        block = M.data(firstVoxel:lastVoxel, :);
        blockCount = sum(isfinite(block) & block > intensityThreshold, 2);
        presenceCount(firstVoxel:lastVoxel) = uint32(blockCount(:));
    end
end

maskVector = presenceCount >= requiredCount;
maskVolume = reshape(maskVector, Vref.dim);

outputDirectory = fileparts(outputNifti);
if ~isempty(outputDirectory) && ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

Vout = Vref;
Vout.fname = outputNifti;
Vout.dt = [spm_type('uint8'), 0];
Vout.pinfo = [1; 0; 0];
Vout.descrip = sprintf('GMV > %.4g in > %.1f%% subjects', ...
    intensityThreshold, 100 * subjectFraction);
spm_write_vol(Vout, uint8(maskVolume));

summary = struct();
summary.mat_file = matFile;
summary.reference_nifti = referenceNifti;
summary.output_nifti = outputNifti;
summary.n_subject = nSubject;
summary.n_voxel_reference = nVoxel;
summary.intensity_threshold = intensityThreshold;
summary.subject_fraction_strictly_greater_than = subjectFraction;
summary.required_subject_count = requiredCount;
summary.n_voxel_retained = nnz(maskVector);
summary.retained_percent = 100 * nnz(maskVector) / nVoxel;

fprintf('Subjects: %d\n', nSubject);
fprintf('Required presence count: %d (> %.1f%%)\n', ...
    requiredCount, 100 * subjectFraction);
fprintf('Retained voxels: %d / %d (%.2f%%)\n', ...
    summary.n_voxel_retained, nVoxel, summary.retained_percent);
fprintf('Saved GMV mask: %s\n', outputNifti);
end
