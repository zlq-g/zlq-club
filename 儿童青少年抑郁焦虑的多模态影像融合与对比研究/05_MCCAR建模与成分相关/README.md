# MCCAR 建模与成分相关

本目录整理六张代码截图中的 MATLAB 工作流：模态归一化、PCA 方差诊断、mCCA-R 参数扫描、loading 相关矩阵、成分与参考变量的相关检验及空间成分重建。

## 文件

- `run_mccar_complete.m`：完整入口，含局部 PCA 辅助函数。
- `example_run_mccar.m`：运行配置示例。
- `LOADINGS_INTERPRETATION.md`：loading 相关矩阵的计算与解读。

## 依赖

需要 MATLAB 及 Statistics and Machine Learning Toolbox（`corr` 的 r/p 输出），以及现有工具箱中的：

- `ica_fuse_normalize_data.m`：Fusion 工具箱归一化函数。
- `pcawhiten.m`：截图所用 PCA 白化函数。
- `mcca_ssqcor_R.m`：现有 mCCA-R 核心实现。

核对本地代码时，`mcca_ssqcor_R.m` 位于 `Matlab_Utilities` 的上一级；`pcawhiten.m` 位于嵌套的 `Matlab_Utilities` 中；提供的 mCCA 目录未找到 `ica_fuse_normalize_data.m`。请设置 `cfg.fusionDir`，不以未经核对的归一化实现替代它。第三方工具箱、模板和个体数据均未随本目录上传。

## 输入和运行

MAT 文件默认包含以下变量，可通过 `cfg.dataVars`、`cfg.referenceVar` 改名：

| 变量 | 维度 |
| --- | --- |
| `fmri_datafalff` | 被试 × fMRI 特征 |
| `dti_datafa` | 被试 × dMRI 特征 |
| `smri_datagmv` | 被试 × sMRI 特征 |
| `x` | 被试 × 1 参考变量 |

三个模态与参考变量的被试行顺序必须一致。程序会同步剔除参考变量为 NaN/Inf 的被试；默认也剔除参考值为 0 的被试。如果 0 是有效值，设置 `cfg.excludeZeroReference = false`。

编辑 `example_run_mccar.m` 中的路径后，在 MATLAB 运行：

```matlab
run('example_run_mccar.m');
```

或直接传入配置：

```matlab
cfg = struct();
cfg.utilitiesDir = '/path/to/mCCA/Matlab_Utilities';
cfg.coreDir = '/path/to/mCCA';
cfg.fusionDir = '/path/to/fusion_toolbox';
cfg.inputFile = '/path/to/ANI-train_input.mat';
cfg.outputDir = '/path/to/mccar_results';
summary = run_mccar_complete(cfg);
```

## 保留的流程和修正

1. 使用 `ica_fuse_normalize_data(raw, 1)` 归一化三个模态。
2. 报告解释 80% 方差所需的 PCA 数量，并向上取整到十位，受数值秩和被试数约束。
3. 扫描 `lambda = [1 10]`、`M = [30 50 70 80 100]`；自动跳过超出秩或被试数界限的 M。
4. 调用现有 `pcawhiten` 和 `mcca_ssqcor_R`。
5. 计算被试 loading `A{k}`，通过 `pinv(A{k}) * data{k}` 重建空间成分。
6. 将三模态 loading 拼接，保存带符号相关矩阵，绘制其绝对值热图。
7. 对各模态 loading 与参考变量做相关检验；三个模态有同编号成分均满足 `p < 0.05` 时，记录该参数组合。

PCA 的 80% 方差结果仅作诊断，不自动替代 M 扫描。该诊断按截图对每个被试跨特征去均值，原 `pcawhiten` 仍使用自己的 SVD 实现。所有模态同步筛选被试，并逐项保存选中的 M/lambda，避免引用循环结束时的最后一组参数。

## 输出

| 文件 | 内容 |
| --- | --- |
| `pca_variance_summary.csv` | PCA 方差诊断 |
| `run_config.mat` | 配置、被试保留掩码、参考值、归一化参数 |
| `mcca_<M>_lamda<L>_results.mat` | 每组参数的 A、空间成分、带符号 loading 相关矩阵、W、目标函数轨迹、筛选结果 |
| `mcca_<M>_lamda<L>_loading_correlation.png` | 绝对 loading 相关热图 |
| `mcca_<M>_lamda<L>_A.mat` / `_ccacomp.mat` | 选中参数组的兼容导出 |
| `mcca_jica_correlations.csv/.mat` | 各成分与参考变量的 r/p 表 |
| `selected_parameters.csv` | 选中参数组的 M/lambda |
| `summary.mat` | 汇总结构 |

截图未展示 jICA 步骤；`mcca_jica_correlations` 仅沿用原输出名称。截图中加载的 SPM mask 未参与展示的拟合代码，此处不推断其用途，也未实现 NIfTI 回填。空间成分保留输入特征顺序。

## 验证状态与结果解释

已核对原 `pcawhiten`、`mcca_ssqcor_R` 函数接口。当前整理版本未完成 MATLAB 执行验证：此前本机 MATLAB 启动遇到处理器/Qt 兼容错误，且真实输入 MAT 不在本目录。首次使用请先以较小 M 检查运行。

显著性筛选沿用截图中的未校正 `p < 0.05`。参考变量参与监督拟合，且程序扫描多个参数，因此这些训练集 p 值不是独立验证结果；正式推断需要独立测试或合适的置换验证。
