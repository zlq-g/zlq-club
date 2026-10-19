%% Extract MCCAR loadings for DEP symptom groups
% Assumptions:
%   1. A is a 1 x nModality cell array.
%   2. A{m} is nSubject x nComponent.
%   3. Row order in A{m} is identical to the ID order in DEP-all.xlsx.
%
% Output:
%   DEP_group_loadings.mat, containing one structure named DEP.

% Put this script in the project directory that contains v1 and v2, or
% replace projectRoot and aMatFile below with their absolute paths.

clearvars;
clc;

%% -------------------------- Configuration -----------------------------
projectRoot = fileparts(mfilename('fullpath'));

masterFile = fullfile(projectRoot, 'v2', 'DEP-all', 'DEP-all.xlsx');

noMinimalFile = fullfile(projectRoot, 'v1', 'DEP-H', ...
    'DEP-h1_three_model_overlap.xlsx');
mildFile = fullfile(projectRoot, 'v1', 'DEP-H', ...
    'DEP-h2_three_model_overlap.xlsx');

moderateFile = fullfile(projectRoot, 'v1', 'DEP', ...
    'DEP-1_three_model_overlap.xlsx');
highFile1 = fullfile(projectRoot, 'v1', 'DEP', ...
    'DEP-2_three_model_overlap.xlsx');
highFile2 = fullfile(projectRoot, 'v1', 'DEP', ...
    'DEP-3_three_model_overlap.xlsx');

% MAT file shown in the screenshot. Change this line if it is elsewhere.
aMatFile = fullfile(projectRoot, 'mcca_m80_lamda10_A.mat');
outputFile = fullfile(projectRoot, 'DEP_group_loadings.mat');

%% --------------------------- Read loadings -----------------------------
assert(isfile(aMatFile), 'A MAT file does not exist:\n%s', aMatFile);
S = load(aMatFile, 'A');
assert(isfield(S, 'A'), 'Variable A was not found in:\n%s', aMatFile);
A = S.A;

assert(iscell(A) && ~isempty(A), ...
    'A must be a non-empty cell array, such as a 1x3 cell array.');

nModality = numel(A);
nSubject = size(A{1}, 1);
nComponent = size(A{1}, 2);

for m = 1:nModality
    assert(isnumeric(A{m}) && ismatrix(A{m}), ...
        'A{%d} must be a numeric 2-D matrix.', m);
    assert(size(A{m}, 1) == nSubject, ...
        'A{%d} has %d rows, but A{1} has %d rows.', ...
        m, size(A{m}, 1), nSubject);
    assert(size(A{m}, 2) == nComponent, ...
        'A{%d} has %d components, but A{1} has %d components.', ...
        m, size(A{m}, 2), nComponent);
end

%% ------------------------ Build master index ---------------------------
[masterIDsOriginal, masterIDs] = readSubjectIDs(masterFile);

assert(numel(masterIDs) == nSubject, ...
    ['The number of IDs in DEP-all.xlsx (%d) does not equal the number ' ...
     'of rows in A (%d). Row correspondence cannot be guaranteed.'], ...
    numel(masterIDs), nSubject);

assert(numel(unique(masterIDs)) == numel(masterIDs), ...
    'DEP-all.xlsx contains duplicate IDs. Please resolve them first.');

%% -------------------------- Extract groups -----------------------------
DEP = struct();

DEP.metadata.created = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
DEP.metadata.master_file = masterFile;
DEP.metadata.A_file = aMatFile;
DEP.metadata.output_file = outputFile;
DEP.metadata.n_subjects = nSubject;
DEP.metadata.n_modalities = nModality;
DEP.metadata.n_components = nComponent;
DEP.metadata.row_mapping = ...
    'Rows of every A{m} were mapped using the ID order in DEP-all.xlsx.';
DEP.metadata.modality_note = ...
    'A{1}, A{2}, and A{3} retain the modality order used by the MCCAR code.';

DEP.master.original_ids = masterIDsOriginal;
DEP.master.normalized_ids = masterIDs;

DEP.groups.no_or_minimal = extractOneGroup( ...
    noMinimalFile, masterIDsOriginal, masterIDs, A);

DEP.groups.mild = extractOneGroup( ...
    mildFile, masterIDsOriginal, masterIDs, A);

DEP.groups.moderate = extractOneGroup( ...
    moderateFile, masterIDsOriginal, masterIDs, A);

% High symptom level = DEP-2 plus DEP-3. Duplicates are removed while the
% first-occurrence order is preserved.
[highIDsOriginal1, highIDs1] = readSubjectIDs(highFile1);
[highIDsOriginal2, highIDs2] = readSubjectIDs(highFile2);
highOriginalCombined = [highIDsOriginal1; highIDsOriginal2];
highNormalizedCombined = [highIDs1; highIDs2];
[highNormalizedUnique, keep] = unique(highNormalizedCombined, 'stable');
highOriginalUnique = highOriginalCombined(keep);

DEP.groups.high = extractFromIDs( ...
    highOriginalUnique, highNormalizedUnique, masterIDsOriginal, ...
    masterIDs, A, {highFile1; highFile2});
DEP.groups.high.n_before_deduplication = numel(highNormalizedCombined);
DEP.groups.high.n_duplicates_removed = ...
    numel(highNormalizedCombined) - numel(highNormalizedUnique);

%% -------------------------- Summary and save ---------------------------
groupNames = {'no_or_minimal'; 'mild'; 'moderate'; 'high'};
nRequested = zeros(numel(groupNames), 1);
nMatched = zeros(numel(groupNames), 1);
nNotFound = zeros(numel(groupNames), 1);

for g = 1:numel(groupNames)
    G = DEP.groups.(groupNames{g});
    nRequested(g) = G.n_requested;
    nMatched(g) = G.n_matched;
    nNotFound(g) = G.n_not_found;
end

DEP.summary = table(string(groupNames), nRequested, nMatched, nNotFound, ...
    'VariableNames', {'group', 'n_requested', 'n_matched', 'n_not_found'});

save(outputFile, 'DEP', '-v7.3');

disp(DEP.summary);
fprintf('\nSaved all matched loadings to:\n%s\n', outputFile);

%% --------------------------- Local functions ---------------------------
function G = extractOneGroup(groupFile, masterIDsOriginal, masterIDs, A)
    [groupIDsOriginal, groupIDs] = readSubjectIDs(groupFile);

    % Remove repeated IDs inside a group without changing their order.
    [groupIDs, keep] = unique(groupIDs, 'stable');
    groupIDsOriginal = groupIDsOriginal(keep);

    G = extractFromIDs(groupIDsOriginal, groupIDs, ...
        masterIDsOriginal, masterIDs, A, {groupFile});
end

function G = extractFromIDs(groupIDsOriginal, groupIDs, ...
        masterIDsOriginal, masterIDs, A, sourceFiles)

    [isMatched, masterIndex] = ismember(groupIDs, masterIDs);
    matchedIndex = masterIndex(isMatched);

    G = struct();
    G.source_files = sourceFiles;
    G.n_requested = numel(groupIDs);
    G.n_matched = nnz(isMatched);
    G.n_not_found = nnz(~isMatched);

    G.requested_ids = groupIDsOriginal;
    G.matched_ids = masterIDsOriginal(matchedIndex);
    G.master_row_index = matchedIndex;
    G.not_found_ids = groupIDsOriginal(~isMatched);

    % loadings{m}: matched subjects x all components for modality m.
    G.loadings = cell(size(A));
    for m = 1:numel(A)
        G.loadings{m} = A{m}(matchedIndex, :);
    end
end

function [idsOriginal, idsNormalized] = readSubjectIDs(xlsxFile)
    assert(isfile(xlsxFile), 'Excel file does not exist:\n%s', xlsxFile);

    opts = detectImportOptions(xlsxFile, 'VariableNamingRule', 'preserve');
    T = readtable(xlsxFile, opts);
    assert(width(T) >= 1, 'No columns were found in:\n%s', xlsxFile);

    variableNames = string(T.Properties.VariableNames);
    candidates = ["id", "subject_id", "subjectid", "participant_id", ...
        "participantid", "subject", "name"];

    normalizedNames = lower(regexprep(variableNames, '[^a-zA-Z0-9]', ''));
    normalizedCandidates = lower(regexprep(candidates, '[^a-zA-Z0-9]', ''));
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

    % Matching is case-insensitive and ignores leading/trailing spaces.
    idsNormalized = lower(strip(idsOriginal));
end
