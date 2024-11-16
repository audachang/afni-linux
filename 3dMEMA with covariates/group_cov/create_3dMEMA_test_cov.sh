#!/usr/bin/tcsh -xef

if ( $#argv != 4 ) then
	echo "usage: create_3dMEMA_test.sh <model> <contrast> <subfn> <covfn>"
	echo "example: create_3dMEMA_test.sh BLOCK words subject_list.txt "
    echo "model: "
    echo "condstr: "
    echo "subfn: file containing list of sub-<????> to be included in the group analysis"
    echo "covfn: covariate file containing subject ID and the de-meaned covariates"
	exit 0
endif


cat $3 | grep "^[^#]" > tmp

set model = $1
set condstr = $2
set sublist = (`cat tmp`)

#these relative path needs to be changed if moved to other directories
set ddir = ../../afni
set output_dir = ../../afni/derivatives/group_glm

set covfn = $4
set cov = `echo $covfn:r`
rm tmp
foreach sub ($sublist)
  	echo $ddir/{$sub}.results/stats.${sub}_REML+tlrc.HEAD >> tmp
end


set nv = (`cat tmp | wc -l`)

set mask_dset = $output_dir/mask_intersection_up2date+tlrc
set beta_A = `3dinfo -label2index "${condstr}#0_Coef" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
set tstat_A = `3dinfo -label2index "${condstr}#0_Tstat" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`

set mean_psyrats = `awk '{sum += $2; count++} END {if (count > 0) print int((sum / count) + 0.5)}' $covfn`
echo mean psyrats = $mean_psyrats

set results_dir = $output_dir/test.${model}.3dMEMA_N=$nv.${condstr}.${cov}.results
echo $results_dir

if ( ! -d $results_dir ) then
   mkdir $results_dir
else
   rm -R $results_dir
endif


set fn = (`cat tmp`)

uber_ttest.py -no_gui -save_script cmd.$model.MEMA.${condstr}.$cov	\
	-program 3dMEMA     			                        \
	-mask $mask_dset                                 		\
	-set_name_A $condstr                                		\
	-dsets_A $fn 							\
	-beta_A $beta_A -tstat_A $tstat_A                            	\
	-results_dir $results_dir 					\
	-sids_A $sublist						\
	-MM_options -jobs 20						\
		-max_zeros 0.25 					\
		-covariates $covfn					\
		-covariates_center psyrats = ${mean_psyrats}		\
		-covariates_model center=different slope=same
