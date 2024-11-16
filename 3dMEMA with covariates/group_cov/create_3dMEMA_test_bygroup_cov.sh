#!/usr/bin/tcsh -ef

if ( $#argv != 5 ) then
	echo "usage: $0 <model> <contrast> <subfn1> <subfn2> <covfn>"
	echo "example: $0 BLOCK words subject_list.txt "
    echo "model: the HRF model used for this analysis"
    echo "condstr: the condition or contrast of this analysis"
    echo "subfn1: file containing list of sub-<????> to be included in the group1"
    echo "subfn2: file containing list of sub-<????> to be included in the group2"
    echo "covfn: covariate file"
	exit 0
endif



set model = $1
set condstr = $2
set sublistA = (`cat $3`)
set sublistB = (`cat $4`)
set ddir = ../../afni
set output_dir = ../../afni/derivatives/group_glm
set covfn = $5

set cov = `echo $covfn:r`

set gA = `echo $3 | sed 's/participants_\(.*\)\.txt/\1/'`
set gB = `echo $4 | sed 's/participants_\(.*\)\.txt/\1/'`

echo $gA $gB

if (-f tmpA) then
	rm tmpA 
endif
if (-f tmpB) then
	rm tmpB
endif


echo "listing $gA"
foreach sub ($sublistA)
  	echo $ddir/{$sub}.results/stats.${sub}_REML+tlrc.HEAD >> tmpA
end
echo "listing $gB"
foreach sub ($sublistB)
  	echo $ddir/{$sub}.results/stats.${sub}_REML+tlrc.HEAD >> tmpB
end


set nvA = (`cat tmpA | wc -l`)
set nvB = (`cat tmpB | wc -l`)
@ nvtotal = $nvA + $nvB

echo $nvA, $nvB
echo $nvtotal

set mask_dset = $output_dir/mask_intersection_up2date+tlrc
set beta_A = `3dinfo -label2index "${condstr}#0_Coef" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
set tstat_A = `3dinfo -label2index "${condstr}#0_Tstat" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
set beta_B = `3dinfo -label2index "${condstr}#0_Coef" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
set tstat_B = `3dinfo -label2index "${condstr}#0_Tstat" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`

echo $beta_A $tstat_A
echo $beta_B $tstat_B

set results_dir = $output_dir/test.${model}.3dMEMA_N=${nvtotal}.${condstr}.$gB-$gA.$cov.results
echo $results_dir

if ( ! -d $results_dir ) then
   mkdir $results_dir
else
   rm -R $results_dir
endif


set fnA = (`cat tmpA`)
set fnB = (`cat tmpB`)


# Calculate mean age and iq for sublistA, ignoring 'n/a' values
set ageA = `awk 'NR==FNR{a[$1]; next} ($1 in a) && ($2 != "n/a") {sum += $2; count++} END {if (count > 0) print sum/count; else print "n/a"}' $3 $covfn`
set iqA = `awk 'NR==FNR{a[$1]; next} ($1 in a) && ($3 != "n/a") {sum += $3; count++} END {if (count > 0) print sum/count; else print "n/a"}' $3 $covfn`

# Calculate mean age and iq for sublistB, ignoring 'n/a' values
set ageB = `awk 'NR==FNR{a[$1]; next} ($1 in a) && ($2 != "n/a") {sum += $2; count++} END {if (count > 0) print sum/count; else print "n/a"}' $4 $covfn`
set iqB = `awk 'NR==FNR{a[$1]; next} ($1 in a) && ($3 != "n/a") {sum += $3; count++} END {if (count > 0) print sum/count; else print "n/a"}' $4 $covfn`





echo "Mean age for group A: $ageA"
echo "Mean IQ for group A: $iqA"
echo "Mean age for group B: $ageB"
echo "Mean IQ for group B: $iqB"



uber_ttest.py -no_gui -save_script cmd.$model.MEMA.${condstr}.$cov.$gB-$gA   \
	-program 3dMEMA                                 		\
	-mask $mask_dset                                 		\
	-set_name_A $gA				         		\
	-dsets_A $fnA 							\
	-beta_A $beta_A -tstat_A $tstat_A                            	\
	-sids_A $sublistA						\
	-set_name_B $gB                                			\
	-dsets_B $fnB 							\
	-beta_B $beta_A -tstat_B $tstat_A                            	\
	-sids_B $sublistB						\
	-results_dir $results_dir 					\
	-MM_options  -jobs 20 						\
		  -max_zeros 0.25					\
		-covariates $covfn					\
		-covariates_center age = $ageA $ageB iq	= $iqA $iqB	\
		-covariates_model center=different slope=same



#Two-sample type (one regression coefficient or general linear
#contrast from each subject in two groups with the contrast being the 2nd group 
#subtracing the 1st one)

# use this to recall valid options for uber_ttest.py
#uber_ttest.py -show_valid_opts

