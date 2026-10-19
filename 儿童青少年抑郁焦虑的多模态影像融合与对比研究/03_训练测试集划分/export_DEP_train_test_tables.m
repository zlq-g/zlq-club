%% Export complete DEP-all rows for training and test subjects
% Input:
%   DEP_train_test_manifest.xlsx, sheet "subject_manifest"
%   DEP-all.xlsx
%
% Output:
%   train.xlsx
%   test.xlsx
%
% Matching is performed by subject ID, not by assuming that the row orders
% in the two workbooks are identical. All original columns from DEP-all.xlsx
% are retained. DEP_group, data_split, and master_row_index are appended.

clearvars;
clc;

%% -------------------------- Configuration -----------------------------
projectRoot = fileparts(mfilename('fullpath'));

manifestFile = fullfile(projectRoot, 'DEP_train_test_manifest.xlsx');
manifestSheet = 'subject_manifest';

% The first existing candidate is used. This supports both the project
% folder layout and the layout shown in the WPS screenshot.
masterCandidates = { ...
    fullfile(projectRoot, 'v2', 'DEP-all', 'DEP-all.xlsx'); ...
    fullfile(projectRoot, 'DEP-all.xlsx')};

outputTrain = fullfile(projectRoot, 'train.xlsx');
outputTest = fullfile(projectRoot, 'test.xlsx');

%% ------------------------- Locate input files -------------------------
assert(isfile(manifestFile), ...
    'Manifest workbook does not exist:\n%s', manifestFile);

masterExists = cellfun(@isfile, masterCandidates);
assert(any(masterExists), ...
    ['DEP-all.xlsx was not found. Expected either:\n%s\nor:\n%s'], ...
    masterCandidates{1}, masterCandidates{2});
masterFile = masterCandidates{find(masterExists, 1, 'first')};

%% -------------------------- Read workbooks ----------------------------
manifestOptions = detectImportOptions(manifestFile, ...
    'Sheet', manifestSheet, 'VariableNamingRule', 'preserve');
manifest = readtable(manifestFile, manifestOptions, ...
    'Sheet', manifestSheet);

masterOptions = detectImportOptions(masterFile, ...
    'VariableNamingRule', 'preserve');
master = readtable(masterFile, masterOptions);

assert(height(manifest) > 0, ...
    'The subject_manifest sheet contains no subjects.');
assert(height(master) > 0, 'DEP-all.xlsx contains no subjects.');

%% ------------------------- Identify columns ---------------------------
manifestIDColumn = findColumn(manifest, ...
    ["subject_id", "subjectid", "id", "participant_id"]);
manifestSplitColumn = findColumn(manifest, ["split", "data_split"]);
manifestGroupColumn = findColumn(manifest, ...
    ["group", "dep_group", "symptom_group"]);

masterIDColumn = findColumn(master, ...
    ["id", "subject_id", "subjectid", "participant_id"]);

manifestIDsOriginal = strip(string(manifest{:, manifestIDColumn}));
manifestIDs = normalizeIDs(manifestIDsOriginal);
masterIDsOriginal = strip(string(master{:, masterIDColumn}));
masterIDs = normalizeIDs(masterIDsOriginal);

splitLabels = lower(strip(string(manifest{:, manifestSplitColumn})));
groupLabels = strip(string(manifest{:, manifestGroupColumn}));

validManifestID = ~ismissing(manifestIDsOriginal) & ...
    manifestIDsOriginal ~= "";
assert(all(validManifestID), ...
    'The subject_manifest sheet contains blank subject IDs.');

validMasterID = ~ismissing(masterIDsOriginal) & masterIDsOriginal ~= "";
assert(all(validMasterID), 'DEP-all.xlsx contains blank subject IDs.');

assert(numel(unique(masterIDs)) == numel(masterIDs), ...
    'DEP-all.xlsx contains duplicate subject IDs.');
assert(numel(unique(manifestIDs)) == numel(manifestIDs), ...
    'The subject_manifest sheet contains duplicate subject IDs.');

unexpectedSplit = ~ismember(splitLabels, ["train", "test"]);
assert(~any(unexpectedSplit), ...
    'The manifest contains split labels other than train or test.');

%% ----------------------- Match IDs to DEP-all -------------------------
[isMatched, masterRowIndex] = ismember(manifestIDs, masterIDs);

if any(~isMatched)
    missingIDs = manifestIDsOriginal(~isMatched);
    previewCount = min(20, numel(missingIDs));
    error(['%d manifest subject(s) were not found in DEP-all.xlsx. ' ...
        'First unmatched IDs:\n%s'], ...
        nnz(~isMatched), strjoin(missingIDs(1:previewCount), newline));
end

% If the manifest contains the previous master index, verify it but still
% use ID matching as the authoritative lookup.
manifestMasterIndexColumn = findOptionalColumn(manifest, ...
    ["master_row_index", "masterrowindex"]);
if ~isempty(manifestMasterIndexColumn)
    recordedIndex = toNumeric(manifest{:, manifestMasterIndexColumn});
    mismatch = isfinite(recordedIndex) & recordedIndex ~= masterRowIndex;
    if any(mismatch)
        warning(['%d recorded master_row_index value(s) differ from the ' ...
            'current ID match. The ID-based match is being used.'], ...
            nnz(mismatch));
    end
end

trainMask = splitLabels == "train";
testMask = splitLabels == "test";

assert(~any(trainMask & testMask), ...
    'A subject cannot simultaneously belong to train and test.');

%% --------------------- Build the two output tables --------------------
trainTable = buildOutputTable(master, masterRowIndex(trainMask), ...
    groupLabels(trainMask), splitLabels(trainMask));
testTable = buildOutputTable(master, masterRowIndex(testMask), ...
    groupLabels(testMask), splitLabels(testMask));

% Stable master-row order makes the output easy to audit against DEP-all.
trainTable = sortrows(trainTable, 'master_row_index');
testTable = sortrows(testTable, 'master_row_index');

trainOutputIDs = normalizeIDs(trainTable{:, masterIDColumn});
testOutputIDs = normalizeIDs(testTable{:, masterIDColumn});
overlapIDs = intersect(trainOutputIDs, testOutputIDs);
assert(isempty(overlapIDs), ...
    'The generated train and test tables share %d subject IDs.', ...
    numel(overlapIDs));

assert(height(trainTable) == nnz(trainMask), ...
    'The number of exported training rows is incorrect.');
assert(height(testTable) == nnz(testMask), ...
    'The number of exported test rows is incorrect.');

%% ---------------------------- Write files -----------------------------
writetable(trainTable, outputTrain, 'Sheet', 'train');
writetable(testTable, outputTest, 'Sheet', 'test');

fprintf('Master workbook: %s\n', masterFile);
fprintf('Training subjects exported: %d\n', height(trainTable));
fprintf('Test subjects exported: %d\n', height(testTable));
fprintf('Saved training workbook: %s\n', outputTrain);
fprintf('Saved test workbook: %s\n', outputTest);

fprintf('\nCounts by symptom group:\n');
allGroups = unique(groupLabels, 'stable');
for g = 1:numel(allGroups)
    nGroupTrain = nnz(trainMask & groupLabels == allGroups(g));
    nGroupTest = nnz(testMask & groupLabels == allGroups(g));
    fprintf('  %-16s train=%4d  test=%4d\n', ...
        allGroups(g), nGroupTrain, nGroupTest);
end

%% --------------------------- Local functions --------------------------
function output = buildOutputTable(master, rowIndex, groupLabels, splitLabels)
    output = master(rowIndex, :);
    output.DEP_group = groupLabels;
    output.data_split = splitLabels;
    output.master_row_index = rowIndex;
end

function columnIndex = findColumn(T, candidates)
    columnIndex = findOptionalColumn(T, candidates);
    assert(~isempty(columnIndex), ...
        'Required column not found. Available columns: %s', ...
        strjoin(string(T.Properties.VariableNames), ', '));
end

function columnIndex = findOptionalColumn(T, candidates)
    names = string(T.Properties.VariableNames);
    normalizedNames = normalizeColumnNames(names);
    normalizedCandidates = normalizeColumnNames(candidates);
    columnIndex = find(ismember(normalizedNames, normalizedCandidates), 1);
end

function normalized = normalizeColumnNames(values)
    normalized = lower(regexprep(string(values), '[^a-zA-Z0-9]', ''));
end

function normalized = normalizeIDs(values)
    normalized = lower(strip(string(values)));
end

function numericValues = toNumeric(values)
    if isnumeric(values) || islogical(values)
        numericValues = double(values);
    else
        numericValues = str2double(strip(string(values)));
    end
    numericValues = numericValues(:);
end
