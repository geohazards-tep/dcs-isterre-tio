#!/bin/bash

# do not let errors run away
set -e

# define the exit codes
SUCCESS=0
ERR_INVERS_PIXEL=101

# source the ciop functions (e.g. ciop-log)
source $ciop_job_include

# add a trap to exit gracefully
clean_exit()
{
    local retval=$?
    local msg=""

    # Create return message
    case "$retval" in
    $SUCCESS) msg="Processing successfully concluded";;
	$ERR_INVERS_PIXEL) msg="invers_pixel failed";;
    *) msg="Unknown error";;
    esac

    if [ "$retval" != "0" ]; then
        ciop-log "ERROR" "Error $retval - $msg, processing aborted"
	else
		ciop-log "INFO" "$msg"
    fi

    exit $retval
}
trap clean_exit EXIT

# switch to TMPDIR
ciop-log "INFO" "change dir to '$TMPDIR'"
cd $TMPDIR

# link inputs in TMPDIR
ciop-log "INFO" "create links to input datasets"
mkdir LN_DATA
for f in /data/test/*; do
    ln -s $f LN_DATA/$(basename $f)
done

# Create input files
ciop-log "INFO" "create invers_pixel input files"

couples=$(ls -1 LN_DATA/*.r4 | sed 's/\.r4//' | xargs -L1 basename)
dates=$(echo "$couples" | tr - \\n | sort -u)

# create liste_image_inv file
date0=$(echo $dates | head -n1)
date0_float=$(echo "scale=6; $(echo $date0|cut -c1-4) + ($(echo $date0|cut -c5-6)-1)/12 + ($(echo $date0|cut -c7-8)-1)/365" | bc)
for date in $dates; do
	date_float=$(echo "scale=6; $(echo $date|cut -c1-4) + ($(echo $date|cut -c5-6)-1)/12 + ($(echo $date|cut -c7-8)-1)/365" | bc)
	date_diff=$(echo "scale=6; $date_float - $date0_float" | bc)
	printf '%d %f %f %d\n' $date $date_float $date_diff 0 >> liste_image_inv
done

# create liste_couple file
cat > liste_couple << EOF
20160818 20160907 0.99436 
20160818 20160917 0.98713 
20160818 20160927 0.97708 
20160818 20161106 0.91199 
20160818 20161116 0.89035 
20160818 20161126 0.86704 
20160818 20161206 0.84126 
20160818 20161216 0.81531 
20160907 20160818 0.99436 
20160907 20160917 0.9985 
20160907 20160927 0.99402 
20160907 20161106 0.94835 
20160907 20161116 0.93062 
20160907 20161126 0.91077 
20160907 20161206 0.88809 
20160907 20161216 0.86463 
20160917 20160818 0.98713 
20160917 20160907 0.9985 
20160917 20160927 0.9985 
20160917 20161106 0.96374 
20160917 20161116 0.94835 
20160917 20161126 0.93062 
20160917 20161206 0.9099 
20160917 20161216 0.88809 
20160927 20160818 0.97708 
20160927 20160907 0.99402 
20160927 20160917 0.9985 
20160927 20161106 0.9766 
20160927 20161116 0.96374 
20160927 20161126 0.94835 
20160927 20161206 0.92984 
20160927 20161216 0.9099 
20161106 20160818 0.91199 
20161106 20160907 0.94835 
20161106 20160917 0.96374 
20161106 20160927 0.9766 
20161106 20161116 0.9985 
20161106 20161126 0.99402 
20161106 20161206 0.98625 
20161106 20161216 0.97592 
20161116 20160818 0.89035 
20161116 20160907 0.93062 
20161116 20160917 0.94835 
20161116 20160927 0.96374 
20161116 20161106 0.9985 
20161116 20161126 0.9985 
20161116 20161206 0.99377 
20161116 20161216 0.98625 
20161126 20160818 0.86704 
20161126 20160907 0.91077 
20161126 20160917 0.93062 
20161126 20160927 0.94835 
20161126 20161106 0.99402 
20161126 20161116 0.9985 
20161126 20161206 0.99837 
20161126 20161216 0.99377 
20161206 20160818 0.84126 
20161206 20160907 0.88809 
20161206 20160917 0.9099 
20161206 20160927 0.92984 
20161206 20161106 0.98625 
20161206 20161116 0.99377 
20161206 20161126 0.99837 
20161206 20161216 0.9985 
20161216 20160818 0.81531 
20161216 20160907 0.86463 
20161216 20160917 0.88809 
20161216 20160927 0.9099 
20161216 20161106 0.97592 
20161216 20161116 0.98625 
20161216 20161126 0.99377 
20161216 20161206 0.9985 
EOF

# create invers_pixel_param file
cat > invers_pixel_param << EOF
$(ciop-getparam smoothing_coefficient)  %  temporal smoothing weight, gamma liss **2 (if <0.0001, no smoothing)
1   %   mask pixels with large RMS misclosure  (y=0;n=1)
$(ciop-getparam rms_misclosure_threshold) %  threshold for the mask on RMS misclosure (in same unit as input files)
1  % range and azimuth downsampling (every n pixel)
1 % iterations to correct unwrapping errors (y:nb_of_iterations,n:0)
1 % iterations to weight pixels of interferograms with large residual? (y:nb_of_iterations,n:0)
$(ciop-getparam weighting_res_scaling_val) % Scaling value for weighting residuals (1/(res**2+value**2)) (in same unit as input files) (Must be approximately equal to standard deviation on measurement noise)
$(ciop-getparam mask_large_residuals) % iterations to mask (tiny weight) pixels of interferograms with large residual? (y:nb_of_iterations,n:0)
5 % threshold on residual, defining clearly wrong values (in same unit as input files)
1    %   outliers elimination by the median (only if nsamp>1) ? (y=0,n=1)
liste_image_inv
0    % sort by date (0) ou by another variable (1) ?
liste_couple
1   % interferogram format (RMG : 0; R4 :1) (date1-date2_pre_inv.unw or date1-date2.r4)
3100.   %  include interferograms with bperp lower than maximal baseline
1   %   minimal number of interferams using each image
1     % interferograms weighting so that the weight per image is the same (y=0;n=1)
0.7 % maximum fraction of discarded interferograms
0 %  Would you like to restrict the area of inversion ?(y=1,n=0)
1 735 1500 1585  %Give four corners, lower, left, top, right in file pixel coord
1  %    referencing of interferograms by bands (1) or corners (2) ? (More or less obsolete)
5  %     band NW -SW(1), band SW- SE (2), band NW-NE (3), or average of three bands (4) or no referencement (5) ?
1   %   Weigthing by image quality (y:0,n:1) ? (then read quality in the list of input images)
0   %  Weigthing by interferogram variance (y:0,n:1) or user given weight (2)?
1    % use of covariance (y:0,n:1) ? (Obsolete)
0   % include a baseline term in inversion ? (y:1;n:0) Require to use smoothing option (smoothing coefficient) !
1   % smoothing by Laplacian, computed with a scheme at 3pts (0) or 5pts (1) ?
2   % weigthed smoothing by the average time step (y :0 ; n : 1, int : 2) ?
1    % put the first derivative to zero (y :0 ; n : 1)?
EOF

# run invers_pixel
ciop-log "INFO" "calling invers_pixel"
/home/mvolat/timeseries/invers_pixel invers_pixel_param || exit $ERR_INVERS_PIXEL

# run lect_depl_cumule_lin
ciop-log "INFO" "calling lect_depl_cumule_lin"
depl_cumule_info=$(gdalinfo -nomd -norat -noct depl_cumule)
/home/mvolat/timeseries/lect_depl_cumule_lin \
	$(echo $depl_cumule_info | grep "^Size is " |tr -d , | cut -d' ' -f3) \
	$(echo $depl_cumule_info | grep "^Size is " |tr -d , | cut -d' ' -f4) \
	$(echo $depl_cumule_info | grep "^Band " | wc -l) \
    1 \
    1

# compress output
gdal_translate -co "INTERLEAVE=BAND" -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" depl_cumule depl_cumule.tiff
rm depl_cumule depl_cumule.hdr
gdal_translate -co "INTERLEAVE=BAND" -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" depl_cumule_liss depl_cumule_liss.tiff
rm depl_cumule_liss depl_cumule_liss.hdr

# clean
rm -Rf LN_DATA

tar -C $(dirname $TMPDIR) -cJf /tmp/foobar/workdir.tar.xz $(basename $TMPDIR)

exit 0
