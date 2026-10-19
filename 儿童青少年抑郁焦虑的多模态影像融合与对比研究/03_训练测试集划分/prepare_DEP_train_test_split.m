%% Match DEP subjects and create group-specific train/test splits
% This script:
%   1. Uses the ID order in v2/DEP-all/DEP-all.xlsx as the master row index.
%   2. Finds four mutually exclusive PHQ-9 symptom groups.
%   3. Combines DEP-2 and DEP-3 into the high-symptom group.
%   4. Creates reproducible group-stratified train/test memberships:
%        exactly 80 randomly selected subjects per symptom group are test;
%        all remaining subjects in that group are train.
%   5. Saves subject IDs, master indices, group labels, and split membership.

clearvars;
clc;

%% -------------------------- Configuration -----------------------------
projectRoot = fileparts(mfilename('fullpath'));

masterFile = fullfile(projectRoot, 'v2', 'DEP-all', 'DEP-all.xlsx');

groupFiles.no_or_minimal = {fullfile(projectRoot, 'v1', 'DEP-H', ...
    'DEP-h1_three_model_overlap.xlsx')};
groupFiles.mild = {fullfile(projectRoot, 'v1', 'DEP-H', ...
    'DEP-h2_three_model_overlap.xlsx')};
groupFiles.moderate = {fullfile(projectRoot, 'v1', 'DEP', ...
    'DEP-1_three_model_overlap.xlsx')};
groupFiles.high = { ...
    fullfile(projectRoot, 'v1', 'DEP', ...
        'DEP-2_three_model_overlap.xlsx'); ...
    fullfile(projectRoot, 'v1', 'DEP', ...
        'DEP-3_three_model_overlap.xlsx')};

outputMat = fullfile(projectRoot, 'DEP_train_test_split.mat');
outputXlsx = fullfile(projectRoot, 'DEP_train_test_manifest.xlsx');

groupNames = ["no_or_minimal", "mild", "moderate", "high"];
nTestPerGroup = 80;
scriptVersion = 'fixed_80_test_per_group_20261016';

% A fixed seed makes the split exactly reproducible.
randomSeed = 20261013;
rng(randomSeed, 'twister');

%% ------------------------- Load master IDs ---------------------------
[masterIDsOriginal, masterIDs] = readSubjectIDs(masterFile);

assert(numel(unique(masterIDs)) == numel(masterIDs), ...
    'DEP-all.xlsx contains duplicate subject IDs.');

%% -------------------- Read and match symptom groups -------------------
DEPsplit = struct();
allGroupIDs = strings(0, 1);
allGroupLabels = strings(0, 1);

for g = 1:numel(groupNames)
    groupName = groupNames(g);
    sourceFiles = groupFiles.(char(groupName));

    groupIDsOriginal = strings(0, 1);
    groupIDs = strings(0, 1);

    for f = 1:numel(sourceFiles)
        [idsOriginalPart, idsPart] = readSubjectIDs(sourceFiles{f});
        groupIDsOriginal = [groupIDsOriginal; idsOriginalPart]; %#ok<AGROW>
        groupIDs = [groupIDs; idsPart]; %#ok<AGROW>
    end

    % DEP-2 + DEP-3 may contain repeated IDs. Keep the first occurrence.
    [groupIDs, keep] = unique(groupIDs, 'stable');
    groupIDsOriginal = groupIDsOriginal(keep);

    [isMatched, masterIndex] = ismember(groupIDs, masterIDs);
    notFoundIDs = groupIDsOriginal(~isMatched);

    if any(~isMatched)
        warning('%s contains %d ID(s) not found in DEP-all.xlsx.', ...
            groupName, nnz(~isMatched));
    end

    masterIndex = masterIndex(isMatched);
    matchedIDs = masterIDsOriginal(masterIndex);

    G = struct();
    G.source_files = sourceFiles;
    G.n_test_requested = nTestPerGroup;
    G.n_requested = numel(groupIDs);
    G.n_matched = numel(masterIndex);
    G.not_found_ids = notFoundIDs;
    G.all.subject_ids = matchedIDs;
    G.all.master_row_index = masterIndex;

    DEPsplit.groups.(char(groupName)) = G;

    allGroupIDs = [allGroupIDs; lower(strip(matchedIDs))]; %#ok<AGROW>
    allGroupLabels = [allGroupLabels; ...
        repmat(groupName, numel(matchedIDs), 1)]; %#ok<AGROW>
end

%% ---------------------- Check group exclusivity -----------------------
[uniqueGroupIDs, ~, duplicateCode] = unique(allGroupIDs);
groupCounts = accumarray(duplicateCode, 1);
overlapIDs = uniqueGroupIDs(groupCounts > 1);

if ~isempty(overlapIDs)
    overlapDescription = strings(numel(overlapIDs), 1);
    for k = 1:numel(overlapIDs)
        labels = unique(allGroupLabels(allGroupIDs == overlapIDs(k)));
        overlapDescription(k) = overlapIDs(k) + " -> " + strjoin(labels, ', ');
    end
    error(['The symptom groups are not mutually exclusive. Resolve these ' ...
        'subject IDs before splitting:\n%s'], ...
        strjoin(overlapDescription, newline));
end

% Subjects present in DEP-all but absent from all four symptom files are
% retained here for auditing and are not silently assigned to either split.
isAssigned = ismember(masterIDs, allGroupIDs);
unassignedIndex = find(~isAssigned);
DEPsplit.unassigned.subject_ids = masterIDsOriginal(unassignedIndex);
DEPsplit.unassigned.master_row_index = unassignedIndex;

if ~isempty(unassignedIndex)
    warning(['%d master subject(s) are not present in any of the four ' ...
        'symptom-group files. They are stored in DEPsplit.unassigned.'], ...
        numel(unassignedIndex));
end

%% ----------------- Split independently within each group --------------
summaryGroup = strings(numel(groupNames), 1);
summaryN = zeros(numel(groupNames), 1);
summaryNTestRequested = repmat(nTestPerGroup, numel(groupNames), 1);
summaryNTrain = zeros(numel(groupNames), 1);
summaryNTest = zeros(numel(groupNames), 1);
summaryActualTrainFraction = zeros(numel(groupNames), 1);
summaryActualTestFraction = zeros(numel(groupNames), 1);

manifestSubjectID = strings(0, 1);
manifestMasterIndex = zeros(0, 1);
manifestGroup = strings(0, 1);
manifestSplit = strings(0, 1);

for g = 1:numel(groupNames)
    groupName = groupNames(g);
    G = DEPsplit.groups.(char(groupName));
    n = G.n_matched;

    assert(n > nTestPerGroup, ...
        ['%s contains only %d matched subjects. Exactly %d test subjects ' ...
         'were requested, so at least %d matched subjects are required ' ...
         'to leave one or more subjects for training.'], ...
        groupName, n, nTestPerGroup, nTestPerGroup + 1);

    randomOrder = randperm(n);

    % Sort positions only for stable output order. Membership remains random.
    testPosition = sort(randomOrder(1:nTestPerGroup));
    trainPosition = sort(randomOrder(nTestPerGroup + 1:end));

    G.train = makeSubset(G.all, trainPosition);
    G.test = makeSubset(G.all, testPosition);
    G.actual_train_fraction = numel(trainPosition) / n;
    G.actual_test_fraction = numel(testPosition) / n;

    DEPsplit.groups.(char(groupName)) = G;

    summaryGroup(g) = groupName;
    summaryN(g) = n;
    summaryNTrain(g) = numel(trainPosition);
    summaryNTest(g) = numel(testPosition);
    summaryActualTrainFraction(g) = G.actual_train_fraction;
    summaryActualTestFraction(g) = G.actual_test_fraction;

    manifestSubjectID = [manifestSubjectID; ...
        G.train.subject_ids; G.test.subject_ids]; %#ok<AGROW>
    manifestMasterIndex = [manifestMasterIndex; ...
        G.train.master_row_index; G.test.master_row_index]; %#ok<AGROW>
    manifestGroup = [manifestGroup; ...
        repmat(groupName, numel(trainPosition), 1); ...
        repmat(groupName, numel(testPosition), 1)]; %#ok<AGROW>
    manifestSplit = [manifestSplit; ...
        repmat("train", numel(trainPosition), 1); ...
        repmat("test", numel(testPosition), 1)]; %#ok<AGROW>
end

DEPsplit.summary = table(summaryGroup, summaryN, ...
    summaryNTestRequested, summaryNTrain, summaryNTest, ...
    summaryActualTrainFraction, summaryActualTestFraction, ...
    'VariableNames', {'group', 'n_total', ...
    'requested_n_test', 'n_train', 'n_test', ...
    'actual_train_fraction', 'actual_test_fraction'});

% Hard stop if a future edit accidentally changes the fixed-size test rule.
assert(all(DEPsplit.summary.n_test == nTestPerGroup), ...
    'Internal split error: every symptom group must have exactly %d test subjects.', ...
    nTestPerGroup);

DEPsplit.manifest = table(manifestSubjectID, manifestMasterIndex, ...
    manifestGroup, manifestSplit, ...
    'VariableNames', {'subject_id', 'master_row_index', 'group', 'split'});
DEPsplit.manifest = sortrows(DEPsplit.manifest, 'master_row_index');

%% ------------------- Create combined train/test sets ------------------
DEPsplit.combined.train = combineGroups( ...
    DEPsplit.groups, groupNames, 'train');
DEPsplit.combined.test = combineGroups( ...
    DEPsplit.groups, groupNames, 'test');

%% --------------------------- Metadata ---------------------------------
DEPsplit.metadata.created = char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss'));
DEPsplit.metadata.random_seed = randomSeed;
DEPsplit.metadata.n_test_per_group = nTestPerGroup;
DEPsplit.metadata.master_file = masterFile;
DEPsplit.metadata.script_version = scriptVersion;
DEPsplit.metadata.script_file = mfilename('fullpath');
DEPsplit.metadata.split_rule = ...
    'Exactly 80 random test subjects per symptom group; all others are train.';

%% ----------------------------- Save -----------------------------------
% Remove outputs from the previous proportional-split version so a stale
% workbook cannot be mistaken for the new fixed-80 result.
if isfile(outputMat)
    delete(outputMat);
end
if isfile(outputXlsx)
    delete(outputXlsx);
end

save(outputMat, 'DEPsplit', '-v7.3');

writetable(DEPsplit.summary, outputXlsx, ...
    'Sheet', 'summary', 'WriteMode', 'overwritesheet');
writetable(DEPsplit.manifest, outputXlsx, ...
    'Sheet', 'subject_manifest', 'WriteMode', 'overwritesheet');

for g = 1:numel(groupNames)
    groupName = groupNames(g);
    for splitName = ["train", "test"]
        subset = DEPsplit.groups.(char(groupName)).(char(splitName));
        splitTable = table(subset.subject_ids, subset.master_row_index, ...
            'VariableNames', {'subject_id', 'master_row_index'});
        sheetName = char(groupName + "_" + splitName);
        writetable(splitTable, outputXlsx, ...
            'Sheet', sheetName, 'WriteMode', 'overwritesheet');
    end
end

if ~isempty(DEPsplit.unassigned.master_row_index)
    unassignedTable = table(DEPsplit.unassigned.subject_ids, ...
        DEPsplit.unassigned.master_row_index, ...
        'VariableNames', {'subject_id', 'master_row_index'});
    writetable(unassignedTable, outputXlsx, ...
        'Sheet', 'unassigned', 'WriteMode', 'overwritesheet');
end

disp(DEPsplit.summary);
fprintf('\nScript version: %s\n', scriptVersion);
fprintf('Script file: %s\n', mfilename('fullpath'));
fprintf('\nSaved MAT output:\n%s\n', outputMat);
fprintf('\nSaved subject manifest:\n%s\n', outputXlsx);

%% --------------------------- Local functions --------------------------
function subset = makeSubset(allData, positions)
    subset = struct();
    subset.subject_ids = allData.subject_ids(positions);
    subset.master_row_index = allData.master_row_index(positions);
end

function combined = combineGroups(groups, groupNames, splitName)
    subjectIDs = strings(0, 1);
    masterIndex = zeros(0, 1);
    labels = strings(0, 1);

    for g = 1:numel(groupNames)
        groupName = groupNames(g);
        subset = groups.(char(groupName)).(splitName);
        subjectIDs = [subjectIDs; subset.subject_ids]; %#ok<AGROW>
        masterIndex = [masterIndex; subset.master_row_index]; %#ok<AGROW>
        labels = [labels; repmat(groupName, ...
            numel(subset.subject_ids), 1)]; %#ok<AGROW>
    end

    [masterIndex, order] = sort(masterIndex);
    combined.subject_ids = subjectIDs(order);
    combined.master_row_index = masterIndex;
    combined.group = labels(order);
end

function [idsOriginal, idsNormalized] = readSubjectIDs(xlsxFile)
    assert(isfile(xlsxFile), 'Excel file does not exist:\n%s', xlsxFile);

    opts = detectImportOptions(xlsxFile, 'VariableNamingRule', 'preserve');
    T = readtable(xlsxFile, opts);
    assert(width(T) >= 1, 'No columns were found in:\n%s', xlsxFile);

    variableNames = string(T.Properties.VariableNames);
    candidates = ["id", "subject_id", "subjectid", "participant_id", ...
        "participantid", "subject", "name"];

    normalizedNames = lower(regexprep(variableNames, ...
        '[^a-zA-Z0-9]', ''));
    normalizedCandidates = lower(regexprep(candidates, ...
        '[^a-zA-Z0-9]', ''));
    idColumn = find(ismember(normalizedNames, normalizedCandidates), 1);

    if isempty(idColumn)
        idColumn = 1;
        warning('No named ID column found in %s; using the first column.', ...
            xlsxFile);
    end

    idsOriginal = string(T{:, idColumn});
    idsOriginal = strip(idsOriginal);
    valid = ~ismissing(idsOriginal) & idsOriginal ~= "";
    idsOriginal = idsOriginal(valid);

    % Matching ignores letter case and leading/trailing spaces.
    idsNormalized = lower(strip(idsOriginal));
end
