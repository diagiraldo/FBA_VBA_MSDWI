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

## Multi-channel population template

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
Then, calculate the template with [`population_template`](https://mrtrix.readthedocs.io/en/latest/reference/commands/population_template.html):
```
population_template template/wm_fodfs template/wm_fodf_template.mif template/gm template/gm_template.mif template/csf template/csf_template.mif -mask_dir template/masks -voxel_size 1.25
```
The template is composed of a WM-like fODF (`template/wm_fodf_template.mif`) along with the voxel-wise templates containing the tissue-like contributions for GM (`template/gm_template.mif`) and CSF (`template/csf_template.mif`).
<img src="figures/mc_template.png?raw=True" width="600px" style="margin:0px 0px"/>

Then, you can extract the voxel-wise template for WM-like contribution from the WM-like fODF as the l=0 term of the spherical harmonic expansion:
```
mrconvert -coord 3 0 template/wm_fodf_template.mif template/wm_template.mif
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