# Fixel- and voxel-based analysis with multi-shell diffusion-weighted MRI
Guide for investigating tissue-specific effects with multi-shell DW-MRI. These are the steps we followed in our paper ["Investigating Tissue-Specific Abnormalities in Alzheimer's Disease with Multi-Shell Diffusion MRI"](https://content.iospress.com/articles/journal-of-alzheimers-disease/jad220551).

<img src="figures/pipeline.png?raw=True" width="800px" style="margin:0px 0px"/>

We performed all steps using [MRtrix3](https://www.mrtrix.org/) (version 3.0.2).

## Pre-processing

We followed the [MRtrix3 documentation for DW-MRI pre-processing](https://mrtrix.readthedocs.io/en/latest/fixel_based_analysis/mt_fibre_density_cross-section.html#pre-processsing-steps) including:
- Denoising
- Suppression of Gibbs-ringing artifacts
- Correction for head motion and eddy current-induced distortions
- Bias-field correction

## Multi-tissue decomposition

## Population template

First, create folders with data (symbolic links) to be used for template construction: 
```
mkdir template template/wm_fodfs template/gm template/csf template/masks

while read -r i
do
    ln -sr wm_fodf_mt/${i}.mif template/wm_fodfs/${i}.mif
    ln -sr gm_mt/${i}.mif template/gm/${i}.mif
    ln -sr csf_mt/${i}.mif template/csf/${i}.mif
    ln -sr mask4fods/${i}.mif template/masks/${i}.mif
done < list_of_imgID_for_template.txt
```
Then, calculate the multi-channel template with [`population_template`](https://mrtrix.readthedocs.io/en/latest/reference/commands/population_template.html):
```
population_template template/wm_fodfs template/wm_fodf_template.mif template/gm template/gm_template.mif template/csf template/csf_template.mif -mask_dir template/masks -voxel_size 1.25
```
The template is composed of a WM-like fODF (`template/wm_fodf_template.mif`) along with the voxel-wise templates containing the tissue-like contributions for GM (`template/gm_template.mif`) and CSF (`template/csf_template.mif`):
<img src="figures/mc_template.png?raw=True" width="800px" style="margin:0px 0px"/>

You can extract the voxel-wise template for WM-like contribution from the WM-like fODF as the l=0 term of the spherical harmonic expansion, and use it to create a WM voxel mask:
```
mrconvert -coord 3 0 -axes 0,1,2 template/wm_fodf_template.mif template/wm_template.mif

mrthreshold template/wm_template.mif template/wm_voxel_mask.mif
```

Then, generate a WM fixel-mask with [`fod2fixel`](https://mrtrix.readthedocs.io/en/latest/reference/commands/fod2fixel.html):
```
fod2fixel -mask template/wm_voxel_mask.mif -fmls_peak_value 0.06 template/wm_fodf_template.mif template/wm_fixel_mask
```

### Generate template tractogram

From the WM fODF template, generate a tractogram using the iFOD2 algorithm, the default option in [`tckgen`](https://mrtrix.readthedocs.io/en/latest/reference/commands/tckgen.html), and then use [`tcksift`](https://mrtrix.readthedocs.io/en/latest/reference/commands/tcksift.html) to reduce density biases in the tractogram:

```
tckgen -angle 22.5 -maxlen 250 -minlen 10 -power 1.0 -cutoff 0.06 template/wm_fodf_template.mif -seed_dynamic template/wm_fodf_template.mif -mask template/wm_voxel_mask.mif -select 10000000 template/tracto_10_million.tck

tcksift template/tracto_10_million.tck template/wm_fodf_template.mif template/tracto_sift_2_million.tck -term_number 2000000
```

A tractogram with fewer streamlines might be useful for visualization purposes:
```
tckedit template/tracto_sift_2_million.tck -number 200000 template/tracto_sift_200k.tck
```

## Diffusion-derived measures

### Fixel-wise measures

### Voxel-wise measures

## Statistical Analyses

***

## Citation

If you follow this guide, please consider citing our paper:

```
@article{Giraldo2022,
  doi = {10.3233/jad-220551},
  url = {https://doi.org/10.3233/jad-220551},
  year = {2022},
  month = oct,
  publisher = {{IOS} Press},
  pages = {1--21},
  author = {Diana L. Giraldo and Robert E. Smith and Hanne Struyfs and Ellis Niemantsverdriet and Ellen De Roeck and Maria Bjerke and Sebastiaan Engelborghs and Eduardo Romero and Jan Sijbers and Ben Jeurissen},
  editor = {Konstantinos Arfanakis},
  title = {Investigating Tissue-Specific Abnormalities in {A}lzheimer's Disease with Multi-Shell Diffusion {MRI}},
  journal = {Journal of Alzheimer's Disease}
}
```

## Contact

Diana L. Giraldo Franco [@diagiraldo](https://github.com/diagiraldo)