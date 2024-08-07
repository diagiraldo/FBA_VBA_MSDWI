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

Do multi-tissue intensity normalization with [`mtnormalise`](https://mrtrix.readthedocs.io/en/latest/reference/commands/mtnormalise.html):
```
mkdir wm_fodf_mt gm_mt csf_mt

for_each wm_fodf/*.mif : mtnormalise IN wm_fodf_mt/NAME gm/NAME gm_mt/NAME csf/NAME csf_mt/NAME -mask mask4fods/NAME 
```

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

At this step, you can already generate a WM fixel-mask with [`fod2fixel`](https://mrtrix.readthedocs.io/en/latest/reference/commands/fod2fixel.html):
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

## Spatial normalisation

Estimate a warp that aligns each set of `wm_fodf_mt`, `gm_mt`, and `csf_mt` to population template with [`mrregister`](https://mrtrix.readthedocs.io/en/latest/reference/commands/mrregister.html):
```
mkdir warp_sub2temp warp_temp2sub

for_each wm_fodf_mt/*.mif : mrregister IN template/wm_fodf_template.mif gm_mt/NAME template/gm_template.mif csf_mt/NAME template/csf_template.mif -mask1 mask4fods/NAME -nl_warp warp_sub2temp/NAME warp_temp2sub/NAME
```

Then, use the estimated warp from subject to template to spatially normalise each map (in this step we DO NOT reorient fODFs because it is not a trivial calculation, instead we reorient fixel maps later on):
```
mkdir wm_fodf_intemplate gm_intemplate csf_intemplate

for_each wm_fodf_mt/*.mif : mrtransform IN -warp warp_sub2temp/NAME -reorient_fod no wm_fodf_intemplate/NAME
for_each gm_mt/*.mif : mrtransform IN -warp warp_sub2temp/NAME gm_intemplate/NAME
for_each csf_mt/*.mif : mrtransform IN -warp warp_sub2temp/NAME csf_intemplate/NAME
```

## Diffusion-derived measures

### Fixel-wise measures

```
mkdir fixels_intemplate
``` 

Calculate Apparent Fiber Density (AFD) with [`fod2fixel`](https://mrtrix.readthedocs.io/en/latest/reference/commands/fod2fixel.html):
```
for_each wm_fodf_template/*.mif : fod2fixel IN -mask template/wm_voxel_mask.mif fixels_intemplate/PRE -afd afd.mif -fmls_peak_value 0.06
```

Reorient fixels according to the warp from subject to template using [`fixelreorient`](https://mrtrix.readthedocs.io/en/latest/reference/commands/fixelreorient.html):
```
for_each fixels_intemplate/* : fixelreorient IN warp_sub2temp/NAME.mif fixels_intemplate/NAME -force
```

Correspondence between fixels in template space for each subject/image and the template fixel mask (`template/wm_fixel_mask`):
```
for_each fixels_intemplate/* : fixelcorrespondence -angle 30 IN/afd.mif template/wm_fixel_mask template/afd PRE.mif
```

Calculate Fiber Cross-section (FC) and log(FC):
```
for_each warp_sub2temp/* : warp2metric IN -fc template/wm_fixel_mask template/fc NAME

mkdir template/log_fc
cp template/wm_fixel_mask/* template/log_fc/

for_each template/fc/*.mif : mrcalc IN -log template/log_fc/NAME
```

### Voxel-wise measures

```
mkdir jdet_sub2temp log_jdet_sub2temp

for_each warp_sub2temp/* : warp2metric IN -jdet jdet_sub2temp/NAME 
for_each jdet_sub2temp/*.mif : mrcalc IN -log log_jdet_sub2temp/NAME
```

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