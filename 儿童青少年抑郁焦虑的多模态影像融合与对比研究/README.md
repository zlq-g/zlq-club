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

## 输入文件

代码默认以脚本所在目录作为项目根目录，并按脚本注释中约定的相对路径读取输入。运行前请根据实际数据目录调整输入路径，且不要将包含被试信息的数据上传到公开仓库。

## 尚未收录

本轮对话中讨论过 `remask_mccar_all_data.m`、GMV mask 构建及 BN/JHU atlas 交集代码，但当前电脑未检索到对应的本地源文件，因此本次首次打包未包含这些文件。找到源文件后可继续补充。
