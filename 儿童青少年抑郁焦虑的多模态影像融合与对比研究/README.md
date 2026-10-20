# 儿童青少年抑郁焦虑的多模态影像融合与对比研究

本目录整理了本轮分析中已经在本地形成文件的 MATLAB 与 Python 代码。为保护被试信息，仓库中不包含 Excel、MAT、NIfTI、个体数据或分析输出。

## 目录

### 01_症状分布可视化

- `make_gad_phq_barplot.py`
- `make_gad_phq_barplot_svg.py`
- `make_gad_phq_integrated_barplots.py`
- `make_gad_phq_separate_barplots.py`
- `make_gad_phq_severity_barplots.py`
- `make_gad_phq_tables.py`

用于绘制 GAD-7 与 PHQ-9 症状分层图及表格。Python 脚本主要依赖 Pillow。

### 02_MCCAR载荷分析

建议运行顺序：

1. `extract_DEP_group_loadings.m`
2. `compare_DEP_loading_groups.m`
3. `plot_DEP_loading_heatmaps.m`
4. `plot_DEP_loading_rainclouds.m`

脚本完成症状组载荷提取、相邻症状组 Welch t 检验、BH-FDR 校正及结果可视化。

### 03_训练测试集划分

建议运行顺序：

1. `prepare_DEP_train_test_split.m`
2. `plot_DEP_train_test_PHQ_pods.m`
3. `export_DEP_train_test_tables.m`

当前划分规则为：每个 PHQ-9 症状组使用固定随机种子随机抽取 **80 名被试作为 test**，其余被试作为 train。脚本会强制检查每组 test 人数是否等于 80。

### 04_Mask构建配准与remask

包含 GMV 群体 mask 构建、BN/JHU atlas 最近邻重采样、不同 MNI 模板间的 ANTs 非线性配准、BN/JHU 交集 mask 生成，以及保持原变量名的 MCCAR 数据 remask。详细流程见该目录的 `README.md`。

### 05_MCCAR建模与成分相关

- `run_mccar_complete.m`：模态归一化、PCA 方差诊断、mCCA-R 参数扫描、loading 相关矩阵及成分重建。
- `example_run_mccar.m`：工具箱与数据路径配置示例。
- `LOADINGS_INTERPRETATION.md`：模态内及跨模态 loading 相关矩阵的含义。

依赖原有 Fusion / mCCA 工具箱，详细输入、运行方式、输出和验证状态见该目录的 [README](05_MCCAR建模与成分相关/README.md)。

## 输入文件

代码默认以脚本所在目录作为项目根目录，并按脚本注释中约定的相对路径读取输入。运行前请根据实际数据目录调整输入路径，且不要将包含被试信息的数据上传到公开仓库。
