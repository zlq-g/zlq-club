# Atlas 来源、校验与使用说明

本目录只保存标准离散标签 atlas 的压缩副本和标签表，不包含被试数据、统计结果或派生 mask。

## Brainnetome Atlas 246

- 文件：`Brainnetome/BNA_MPM_thr25_1.25mm.nii.gz`
- 内容：Brainnetome 最大概率图，246 个分区（210 个皮层、36 个皮层下分区）
- 网格：145 × 173 × 145，1.25 mm 等体素
- 标签：整数 0–246；非零标签共 246 个
- SHA-256：`b4121dbb366edd26ac682d12c1c248c18285dc93050258aa1b1209e3e6eb2a90`
- 标签表：`Brainnetome/BN_Atlas_246_LUT.txt`
- 官方资源：https://github.com/BrainnetomeAtlas/HUMAN-BRAINNETOME-ATLAS
- 论文：Fan L, et al. *The Human Brainnetome Atlas: A New Brain Atlas Based on Connectional Architecture*. Cerebral Cortex, 2016. DOI: 10.1093/cercor/bhw157

请按官方资源页当前条款使用并引用。目录中的 `README_upstream.txt` 保留了上游文件说明。

## JHU ICBM-DTI-81 White-Matter Labels 1 mm

- 文件：`JHU/JHU-WhiteMatter-labels-1mm.nii.gz`
- 内容：JHU 白质标签 atlas
- 网格：182 × 218 × 182，1 mm 等体素
- 标签：整数 0–48；非零标签共 48 个
- SHA-256：`742dab207124b12faf1922194c16a63f2d73c5bb0b7dee04ac1b521af91e0d5c`
- 标签说明：`JHU/JHU-WhiteMatter-labels-1mm.nii.txt`
- 显示色表：`JHU/JHU-WhiteMatter-labels-1mm.nii.lut`
- FSL atlas 说明：https://fsl.fmrib.ox.ac.uk/fsl/docs/other/datasets.html
- FSL 使用许可：https://pages.fmrib.ox.ac.uk/fsldocs-4c7e2c/license.html

JHU atlas 按 FSL 页面所列许可使用；该许可包含非商业使用限制。使用者应核对官方最新条款并引用相应 atlas 论文。

## 重要说明

- `rBNA_MPM_thr25_1.25mm.nii` 未收录。检查发现该文件包含大量非整数值，说明离散标签曾被线性插值，不适合作为 atlas 标签图。
- 对标签 atlas 配准或重采样时必须使用最近邻/`GenericLabel` 插值。
- 若目标数据属于不同的 MNI 模板空间，不能只靠调整体素分辨率；应先完成模板间配准，再把变换应用到 atlas。
- 可用 `shasum -a 256 <file>` 校验下载文件。
