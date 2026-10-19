# Mask 构建、MNI 配准与 remask

该模块将“生成群体 mask—atlas 对齐—取交集—重新筛选 MCCAR 特征矩阵”拆成可核查的步骤。所有代码都不会手动删除脑外像素，也不会使用并集扩大已有特征空间。

## 核心原则

1. BN/JHU 与原 mask 已在同一个 MNI 世界坐标空间、仅分辨率或网格不同：使用最近邻重采样。
2. BN/JHU 与数据属于不同 MNI 模板空间：先基于源、目标 T1 模板估计非线性变换，再将变换用于 atlas。
3. 标签图只能使用 `NearestNeighbour`/`GenericLabel` 插值，不能使用线性或三次插值。
4. 新 mask 使用交集：`new_mask = old_mask & (atlas > 0)`。
5. 现有特征矩阵只能删除旧 mask 内的列，不能补出旧 mask 外的体素。

## 文件

- `build_gmv_prevalence_mask.m`：从 `gmv_200.mat` 的 `data` 构建 GMV 群体 mask。默认规则为 GMV 大于 0.1，且严格超过 90% 的被试在该体素有值；200 人时至少需要 181 人。
- `resample_atlas_to_mask_spm.m`：BN/JHU 已在相同 MNI 空间时，使用 SPM 最近邻重采样到原 mask 网格。
- `register_mni_atlas_with_ants.sh`：源、目标 MNI 模板不同时，使用 ANTs 从两幅 T1 模板估计非线性变换，并用 `GenericLabel` 将 atlas 变换到目标空间。
- `build_BN_JHU_intersection_masks.m`：生成 fALFF×BN、GMV×BN、FA×JHU 三个交集 mask，并报告保留比例。
- `remask_mccar_all_data.m`：按照新 mask 筛选 `ANI_mccar_all_Data.mat`，保持 `f_mask_falff`、`s_mask_gmv`、`d_mask_fa`、`V_f`、`V_s`、`V_d` 命名不变。

## 推荐顺序

### 1. 构建 GMV 群体 mask

```matlab
summary = build_gmv_prevalence_mask( ...
    '/path/to/Datasets/smri/gmv_200.mat', ...
    '/path/to/Datasets/smri/modulate.nii', ...
    '/path/to/Brain_templates/GMV_mask_gt0p1_present_gt90pct.nii', ...
    0.1, 0.90, 50000);
```

其余 MATLAB 脚本从环境变量读取路径，避免把服务器用户名写进公开仓库：

```bash
export SPM12_DIR=/path/to/spm12
export BRAIN_TEMPLATE_DIR=/path/to/Brain_templates
export DTI_DIR=/path/to/Datasets/dti
export BRAINNETOME_ATLAS=/path/to/BNA_MPM_thr25_1.25mm.nii.gz
export JHU_ATLAS=/path/to/JHU-WhiteMatter-labels-1mm.nii.gz
export MCCAR_DATA_MAT=/path/to/ANI_mccar_all_Data.mat
export MCCAR_REMASK_OUTPUT=/path/to/ANI_mccar_all_Data_remasked.mat
```

Brainnetome 应使用原始整数标签文件，例如 `BNA_MPM_thr25_1.25mm.nii.gz`。不要直接使用经过线性插值后出现大量小数标签的 `rBNA_*.nii`；代码会从原始 atlas 重新进行最近邻重采样。

### 2. 判断是“重采样”还是“真正配准”

同一 MNI 模板空间只需运行 `resample_atlas_to_mask_spm.m`。不同模板空间，例如常规 MNI152 与 `MNI152NLin2009cAsym`，应运行：

```bash
bash register_mni_atlas_with_ants.sh \
  source_MNI_T1.nii.gz \
  target_MNI152NLin2009cAsym_T1.nii.gz \
  BN_or_JHU_atlas.nii.gz \
  target_analysis_mask.nii.gz \
  transforms/source_to_2009c_ \
  atlas_in_MNI152NLin2009cAsym.nii.gz
```

正式分析前应在 MRIcroGL/MRIcron 中将变换后的 atlas 叠加到目标 T1 模板检查边界。

### 3. 构建 BN/JHU 交集 mask

编辑 `build_BN_JHU_intersection_masks.m` 顶部路径并运行。输出满足：

```text
fALFF新mask = fALFF旧mask ∩ Brainnetome
GMV新mask   = GMV旧mask   ∩ Brainnetome
FA新mask    = FA旧mask    ∩ JHU白质atlas
```

### 4. remask 特征矩阵

编辑并运行 `remask_mccar_all_data.m`。代码会检查：

- 新旧 mask 的维度和 affine 是否一致；
- 旧 mask 的体素数是否等于原特征矩阵列数；
- 新 mask 是否完全位于旧 mask 内；
- remask 前后的体素数量和保留比例。

如果出现“新 mask 位于旧 mask 外”的错误，不能通过静默删除解决。应先修正配准/重采样；如果确实需要这些新体素，则必须从每个被试原始 NIfTI 重新提取，已有特征矩阵无法补出这些值。
