function summary = run_mccar_complete(cfg)
% MCCAR workflow reconstructed from the supplied six code screenshots.
% Inputs: three subjects-by-features matrices and a single reference vector.
% Set cfg.inputFile, cfg.utilitiesDir, cfg.coreDir and cfg.fusionDir.
if nargin < 1, cfg = struct(); end
projectDir = fileparts(mfilename('fullpath'));
defaults.utilitiesDir = '';
defaults.coreDir = '';
defaults.fusionDir = '';
defaults.inputFile = fullfile(projectDir, 'inputs', 'ANI-train_input.mat');
defaults.outputDir = fullfile(projectDir, 'outputs');
defaults.referenceVar = 'x';
defaults.dataVars = {'fmri_datafalff', 'dti_datafa', 'smri_datagmv'};
defaults.modalityNames = {'fALFF', 'FA', 'GMV'};
defaults.lambdaValues = [1, 10];
defaults.componentValues = [30, 50, 70, 80, 100];
defaults.targetVariance = 80;
defaults.roundUnit = 10;
defaults.alpha = 0.05;
defaults.excludeZeroReference = true;
defaults.seed = 1;
defaults.figureDpi = 300;
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(cfg, names{k}), cfg.(names{k}) = defaults.(names{k}); end
end
if ~isempty(cfg.utilitiesDir)
    assert(isfolder(cfg.utilitiesDir), 'Utilities directory not found.');
    addpath(genpath(cfg.utilitiesDir));
end
if ~isempty(cfg.fusionDir)
    assert(isfolder(cfg.fusionDir), 'Fusion toolbox directory not found.');
    addpath(genpath(cfg.fusionDir));
end
if ~isempty(cfg.coreDir)
    assert(isfolder(cfg.coreDir), 'MCCAR core directory not found.');
    addpath(cfg.coreDir, '-begin');
end
required = {'ica_fuse_normalize_data', 'pcawhiten', 'mcca_ssqcor_R', 'corr'};
for k = 1:numel(required)
    assert(exist(required{k}, 'file') ~= 0, ...
        'Missing function: %s. Configure its toolbox path.', required{k});
end
assert(isfile(cfg.inputFile), 'Input MAT not found: %s', cfg.inputFile);
assert(isscalar(cfg.alpha) && cfg.alpha > 0 && cfg.alpha < 1, 'Invalid alpha.');
assert(isscalar(cfg.roundUnit) && cfg.roundUnit >= 1 && ...
    cfg.roundUnit == floor(cfg.roundUnit), 'roundUnit must be a positive integer.');
if ~isfolder(cfg.outputDir), mkdir(cfg.outputDir); end
rng(cfg.seed, 'twister');
S = load(cfg.inputFile);
assert(isfield(S, cfg.referenceVar), 'Reference variable not found: %s', cfg.referenceVar);
x = S.(cfg.referenceVar);
if ~isnumeric(x), x = str2double(string(x)); end
assert(isvector(x) && isreal(x), 'The supplied MCCAR solver requires one real reference vector.');
x = double(x(:));
idx = isfinite(x);
if cfg.excludeZeroReference, idx = idx & x ~= 0; end
Ref = x(idx);
assert(numel(Ref) >= 3 && std(Ref) > 0, 'Reference needs >=3 valid subjects and nonzero variance.');
nModality = numel(cfg.dataVars);
assert(nModality == 3 && numel(cfg.modalityNames) == 3, 'Expected three modalities.');
data = cell(1, nModality);
normpara = cell(1, nModality);
for k = 1:nModality
    varname = cfg.dataVars{k};
    assert(isfield(S, varname), 'Input variable not found: %s', varname);
    raw = S.(varname);
    assert(isnumeric(raw) && ismatrix(raw) && isreal(raw), '%s must be a real numeric matrix.', varname);
    assert(size(raw, 1) == numel(x), '%s: subject rows must match the reference.', varname);
    % Apply the SAME subject filter to the reference and every modality.
    raw = double(raw(idx, :));
    assert(all(isfinite(raw(:))), '%s contains NaN/Inf after filtering.', varname);
    assert(size(raw, 2) >= 2, '%s needs at least two features.', varname);
    [data{k}, normpara{k}] = ica_fuse_normalize_data(raw, 1);
    assert(isequal(size(data{k}), size(raw)) && all(isfinite(data{k}(:))), ...
        'Normalization returned invalid data for %s.', varname);
end
clear S raw;
fprintf('Retained %d of %d subjects.\n', numel(Ref), numel(x));

% PCA is diagnostic here; the fit still uses cfg.componentValues.
M80_exact = zeros(nModality, 1);
M80_round = zeros(nModality, 1);
varianceAfterRound = zeros(nModality, 1);
rankBound = zeros(nModality, 1);
cumulativeVariance = cell(nModality, 1);
for k = 1:nModality
    [M80_exact(k), cumulativeVariance{k}, rankBound(k)] = ...
        getPcaComponentNumber(data{k}, cfg.targetVariance);
    M80_round(k) = min(ceil(M80_exact(k) / cfg.roundUnit) * cfg.roundUnit, ...
        min(size(data{k}, 1) - 1, rankBound(k)));
    varianceAfterRound(k) = cumulativeVariance{k}(M80_round(k));
end
Tpca = table(cfg.modalityNames(:), M80_exact, M80_round, varianceAfterRound, ...
    'VariableNames', {'modality', 'M80_exact', 'M_rounded_up', 'variance_retained_percent'});
disp(Tpca);
writetable(Tpca, fullfile(cfg.outputDir, 'pca_variance_summary.csv'));
maxM = min([numel(Ref) - 1; rankBound]);
MValues = cfg.componentValues(:)';
assert(all(isfinite(MValues) & MValues >= 1 & MValues == floor(MValues)), 'Invalid component counts.');
skippedM = MValues(MValues > maxM);
MValues = MValues(MValues <= maxM);
if ~isempty(skippedM)
    warning('Skipping M above rank/sample bound %d: %s', maxM, mat2str(skippedM));
end
assert(~isempty(MValues), 'No valid component count (maximum %d).', maxM);
assert(~isempty(cfg.lambdaValues) && all(isfinite(cfg.lambdaValues(:)) & ...
    cfg.lambdaValues(:) >= 0), 'Lambda values must be finite and nonnegative.');
feature_names = cfg.modalityNames;
save(fullfile(cfg.outputDir, 'run_config.mat'), 'cfg', 'idx', 'Ref', ...
    'normpara', 'Tpca', 'feature_names', 'skippedM', '-v7.3');

corr_rows = zeros(0, 8);
selected_rows = zeros(0, 2);
for lamda = cfg.lambdaValues(:)'
    for M = MValues
        fprintf('\nRunning lambda=%g, M=%d\n', lamda, M);
        [pcasig, ~] = pcawhiten(data, M);
        whiteig = zeros(M, numel(Ref), nModality);
        for k = 1:nModality, whiteig(:, :, k) = pcasig{k}; end
        [W, costfunction, cf11, cf22] = mcca_ssqcor_R(whiteig, M, Ref, lamda);
        A = cell(1, nModality);
        ccacomp = cell(1, nModality);
        mod = cell(1, nModality);
        for k = 1:nModality
            % A: subjects x components; ccacomp: components x features.
            A{k} = (W(:, :, k) * whiteig(:, :, k))';
            assert(isreal(A{k}) && all(isfinite(A{k}(:))), ...
                'Invalid loadings: lambda=%g, M=%d, modality=%d.', lamda, M, k);
            ccacomp{k} = pinv(A{k}) * data{k};
            [r, p] = corr(A{k}, Ref, 'rows', 'complete');
            nComp = size(r, 1);
            corr_rows = [corr_rows; repmat(lamda, nComp, 1), ...
                repmat(M, nComp, 1), repmat(k, nComp, 1), ...
                (1:nComp)', ones(nComp, 1), r(:), p(:), double(p(:) < cfg.alpha)]; %#ok<AGROW>
            mod{k} = find(p < cfg.alpha);
        end
        common_components = intersect(intersect(mod{1}, mod{2}), mod{3});
        selected = ~isempty(common_components);
        if selected, selected_rows(end + 1, :) = [M, lamda]; end %#ok<AGROW>
        Am = cat(2, A{:});
        loading_corr = corr(Am, Am, 'rows', 'complete');
        tag = sprintf('mcca_%d_lamda%g', M, lamda);
        save(fullfile(cfg.outputDir, [tag '_results.mat']), 'A', 'ccacomp', ...
            'loading_corr', 'W', 'costfunction', 'cf11', 'cf22', ...
            'mod', 'common_components', 'selected', 'M', 'lamda', ...
            'Ref', 'idx', 'feature_names', '-v7.3');
        fig = figure('Visible', 'off', 'Color', 'w');
        imagesc(abs(loading_corr), [0, 1]);
        axis image; colormap(fig, parula(256)); colorbar;
        print(fig, fullfile(cfg.outputDir, [tag '_loading_correlation.png']), ...
            '-dpng', sprintf('-r%d', cfg.figureDpi));
        close(fig);
        if selected
            save(fullfile(cfg.outputDir, [tag '_A.mat']), 'A', '-v7.3');
            save(fullfile(cfg.outputDir, [tag '_ccacomp.mat']), 'ccacomp', '-v7.3');
        end
        clear pcasig whiteig W A ccacomp Am loading_corr;
    end
end
corr_tbl = array2table(corr_rows, 'VariableNames', ...
    {'lamda', 'M', 'modality', 'component', 'ref_col', 'r', 'p', 'is_sig'});
writetable(corr_tbl, fullfile(cfg.outputDir, 'mcca_jica_correlations.csv'));
save(fullfile(cfg.outputDir, 'mcca_jica_correlations.mat'), 'corr_tbl');
selected_parameters = array2table(selected_rows, 'VariableNames', {'M', 'lamda'});
writetable(selected_parameters, fullfile(cfg.outputDir, 'selected_parameters.csv'));
summary = struct('cfg', cfg, 'Tpca', Tpca, 'selected_parameters', selected_parameters);
save(fullfile(cfg.outputDir, 'summary.mat'), 'summary');
fprintf('\nFinished. Results saved to %s\n', cfg.outputDir);
end

function [Mtarget, cumulativeVariance, numericalRank] = getPcaComponentNumber(G, targetVariance)
% Screenshot diagnostic: center each subject across features, then use G*G'.
assert(targetVariance > 0 && targetVariance <= 100, 'Variance target must be in (0,100].');
Gcentered = G - mean(G, 2);
C = Gcentered * Gcentered';
C = (C + C') / 2;
eigenvalues = sort(real(eig(C)), 'descend');
eigenvalues(eigenvalues < 0) = 0;
tol = max(eigenvalues) * 1e-12;
eigenvalues = eigenvalues(eigenvalues > tol);
assert(~isempty(eigenvalues), 'PCA has zero usable variance.');
numericalRank = numel(eigenvalues);
cumulativeVariance = cumsum(100 * eigenvalues / sum(eigenvalues));
cumulativeVariance(end) = 100;
Mtarget = find(cumulativeVariance >= targetVariance, 1, 'first');
end
