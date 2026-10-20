% Edit paths before running. Do not put subject data in the public repository.
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
cfg = struct();
cfg.utilitiesDir = '/path/to/mCCA/Matlab_Utilities';
cfg.coreDir = '/path/to/mCCA';
cfg.fusionDir = '/path/to/fusion_toolbox';
cfg.inputFile = '/path/to/ANI-train_input.mat';
cfg.outputDir = '/path/to/mccar_results';
cfg.dataVars = {'fmri_datafalff', 'dti_datafa', 'smri_datagmv'};
cfg.referenceVar = 'x';
cfg.modalityNames = {'fALFF', 'FA', 'GMV'};
cfg.componentValues = [30, 50, 70, 80, 100];
cfg.lambdaValues = [1, 10];
cfg.targetVariance = 80;
cfg.roundUnit = 10;
cfg.alpha = 0.05;
cfg.excludeZeroReference = true; % Set false if zero is valid.
cfg.seed = 1;
cfg.figureDpi = 300;
summary = run_mccar_complete(cfg);
