#!/bin/bash

export PATH=/application/tio:/usr/local/gdal-t2/bin:$PATH
export PATH=$PATH:/home/mvolat
export LD_LIBRARY_PATH=/usr/local/gdal-t2/lib:$LD_LIBRARY_PATH
export GDAL_DATA=/usr/local/gdal-t2/share/gdal

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
    $ERR_INVERS_PIXEL) msg="Program invers_pixel failed";;
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

direction=$(ciop-getparam direction)
if [ "x$direction" = "xEW" ]; then
    direction_micmac="Px1"
else
    direction_micmac="Px2"
fi

ciop-log "INFO" "Begining $direction processing"

# switch to TMPDIR
ciop-log "INFO" "Change dir to '$TMPDIR'"
cd $TMPDIR

# link inputs in TMPDIR
ciop-log "INFO" "Reformat input dataset"
mkdir LN_DATA
cd LN_DATA
inputdir=/data/test_colca
for f in $inputdir/Out_*/Px1_*_corrected.tif; do
    date1=$(basename $(dirname $f) | tr -d - | cut -d_ -f2)
    date2=$(basename $(dirname $f) | tr -d - | cut -d_ -f5)
    gdal_translate -q -of envi -ot Float32 -srcwin 0 3000 2000 2000 $f ${date1}-${date2}.r4
    info=$(gdalinfo -nomd -norat -noct ${date1}-${date2}.r4)
    xsize=$(printf "$info" | grep "^Size is " | tr -d , | cut -d' ' -f3)
    ysize=$(printf "$info" | grep "^Size is " | tr -d , | cut -d' ' -f4)
    xmax=$(echo "scale=0; $xsize-1" | bc)
    ymax=$(echo "scale=0; $ysize-1" | bc)
    cat > ${date1}-${date2}.r4.rsc << EOF
WIDTH                 $xsize
FILE_LENGTH           $ysize
XMIN                  0
XMAX                  $xmax
YMIN                  0
YMAX                  $ymax
EOF
done
cd ..

# Create input files
ciop-log "INFO" "Create invers_pixel input files"

pairs=$(ls -1 LN_DATA/*.r4 | sed 's/\.r4//' | xargs -L1 basename)
dates=$(echo "$pairs" | tr - \\n | sort -u)

# create liste_image_inv file
date0=$(echo $dates | head -n1)
date0_float=$(echo "scale=6; $(echo $date0|cut -c1-4) + ($(echo $date0|cut -c5-6)-1)/12 + ($(echo $date0|cut -c7-8)-1)/365" | bc)
for date in $dates; do
    date_float=$(echo "scale=6; $(echo $date|cut -c1-4) + ($(echo $date|cut -c5-6)-1)/12 + ($(echo $date|cut -c7-8)-1)/365" | bc)
    date_diff=$(echo "scale=6; $date_float - $date0_float" | bc)
    printf '%d %f %f %d\n' $date $date_float $date_diff 0 >> liste_image_inv
done

# create liste_pair file
for pair in $pairs; do
    date1=$(echo $pair|cut -d- -f1)
    date2=$(echo $pair|cut -d- -f2)
    date1_float=$(echo "scale=6; $(echo $date1|cut -c1-4) + ($(echo $date1|cut -c5-6)-1)/12 + ($(echo $date1|cut -c7-8)-1)/365" | bc)
    date2_float=$(echo "scale=6; $(echo $date2|cut -c1-4) + ($(echo $date2|cut -c5-6)-1)/12 + ($(echo $date2|cut -c7-8)-1)/365" | bc)
    coeff=$(echo "scale=6; 1 / (1 + ($date2_float-$date1_float)^2)^2" | bc)
    printf '%s %s %f\n' $date1 $date2 $coeff >> liste_pair
done

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
liste_pair
1   % interferogram format (RMG : 0; R4 :1) (date1-date2_pre_inv.unw or date1-date2.r4)
3100.   %  include interferograms with bperp lower than maximal baseline
1   %Weight input interferograms by coherence or correlation maps ? (y:0,n:1)
1   %coherence file format (RMG : 0; R4 :1) (date1-date2.cor or date1-date2-CC.r4)
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
ciop-log "INFO" "Calling invers_pixel"
time /home/mvolat/nsbas-invers_optic/bin/invers_pixel invers_pixel_param || exit $ERR_INVERS_PIXEL

# copy georeferencing from one input, generate aux.xml files
gdalcopyproj.py LN_DATA/$(printf $pairs|head -n1).r4 depl_cumule
printf "data ignore value = 9999" >> depl_cumule.hdr
gdalinfo -stats depl_cumule &>/dev/null

# make some space for that is following
ciop-log "INFO" "Clean up LN_DATA"
rm -Rf LN_DATA

# Get output information
depl_cumule_info=$(gdalinfo -nomd -norat -noct depl_cumule)
depl_cumule_xsize=$(printf "$depl_cumule_info" | grep "^Size is " | tr -d , | cut -d' ' -f3)
depl_cumule_ysize=$(printf "$depl_cumule_info" | grep "^Size is " | tr -d , | cut -d' ' -f4)
depl_cumule_bands=$(printf "$depl_cumule_info" | grep "^Band " | wc -l)

# reformat output into tiff

# depl_cumule files, easy
ciop-log "INFO" "Reformat output: convert depl_cumule to tiff"
gdal_translate -q \
        -co "INTERLEAVE=BAND" -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" \
        depl_cumule \
        depl_cumule_${direction}.tiff
cp depl_cumule.aux.xml depl_cumule_${direction}.tiff.aux.xml

# create vrt for RMSpixel files per date
ciop-log "INFO" "Reformat output: create VRT file for RMSpixel per date"
cat > RMSpixel_dates.vrt << EOF
<VRTDataset rasterXSize="$depl_cumule_xsize" rasterYSize="$depl_cumule_ysize">
EOF
for date in $dates; do
    f=RMSpixel_$date
    cat > ${f}.hdr << EOF
ENVI
samples = $depl_cumule_xsize
lines = $depl_cumule_ysize
bands = 1
header offset = 0
data type = 4
interleave = bip
byte order = 0
EOF
    cat >> RMSpixel_dates.vrt << EOF
  <VRTRasterBand dataType="Float32">
    <SimpleSource>
      <SourceFilename relativeToVRT="1">$f</SourceFilename>
      <SourceBand>1</SourceBand>
      <SourceProperties RasterXSize="$depl_cumule_xsize" RasterYSize="$depl_cumule_ysize" DataType="Float32" BlockXSize="$depl_cumule_xsize" BlockYSize="1" />
      <SrcRect xOff="0" yOff="0" xSize="$depl_cumule_xsize" ySize="$depl_cumule_ysize" />
      <DstRect xOff="0" yOff="0" xSize="$depl_cumule_xsize" ySize="$depl_cumule_ysize" />
      <Description>$date</Description>
    </SimpleSource>
  </VRTRasterBand>
EOF
done
cat >> RMSpixel_dates.vrt << EOF
</VRTDataset>
EOF
# pack all RMSpixel files per date into a single tiff
ciop-log "INFO" "Reformat output: merge RMSpixel per date files into tiff"
gdal_translate -q \
        -co "INTERLEAVE=BAND" -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" \
        RMSpixel_dates.vrt \
        RMSpixel_dates_${direction}.tiff

# create vrt for RMSpixel files per pair
ciop-log "INFO" "Reformat output: create VRT file for RMSpixel per pair"
cat > RMSpixel_pairs.vrt << EOF
<VRTDataset rasterXSize="$depl_cumule_xsize" rasterYSize="$depl_cumule_ysize">
EOF
for pair in $pairs; do
    date1=$(echo $pair|cut -d- -f1)
    date2=$(echo $pair|cut -d- -f2)
    f=RMSpixel_${date1}_${date2}
    cat > ${f}.hdr << EOF
ENVI
samples = $depl_cumule_xsize
lines = $depl_cumule_ysize
bands = 1
header offset = 0
data type = 4
interleave = bip
byte order = 0
EOF
    cat >> RMSpixel_pairs.vrt << EOF
  <VRTRasterBand dataType="Float32">
    <SimpleSource>
      <SourceFilename relativeToVRT="1">$f</SourceFilename>
      <SourceBand>1</SourceBand>
      <SourceProperties RasterXSize="$depl_cumule_xsize" RasterYSize="$depl_cumule_ysize" DataType="Float32" BlockXSize="$depl_cumule_xsize" BlockYSize="1" />
      <SrcRect xOff="0" yOff="0" xSize="$depl_cumule_xsize" ySize="$depl_cumule_ysize" />
      <DstRect xOff="0" yOff="0" xSize="$depl_cumule_xsize" ySize="$depl_cumule_ysize" />
      <Description>${date1}-${date2}</Description>
    </SimpleSource>
  </VRTRasterBand>
EOF
done
cat >> RMSpixel_pairs.vrt << EOF
</VRTDataset>
EOF
# pack all RMSpixel files per date into a single tiff
ciop-log "INFO" "Reformat output: merge RMSpixel per pair files into tiff"
gdal_translate -q \
        -co "INTERLEAVE=BAND" -co "COMPRESS=DEFLATE" -co "PREDICTOR=3" \
        RMSpixel_pairs.vrt \
        RMSpixel_pairs_${direction}.tiff

# quicklook
ciop-log "INFO" "Create quicklooks"
# image must be reprojected in wgs84 (even if display will be webmercator)
gdalwarp -q -t_srs "+proj=longlat +ellps=WGS84" -r cubic \
        depl_cumule_${direction}.tiff \
        quicklook_depl_cumule_${direction}.tiff
cp depl_cumule_${direction}.tiff.aux.xml quicklook_depl_cumule_${direction}.tiff.aux.xml
# create animation
ts2apng.py quicklook_depl_cumule_${direction}.tiff quicklook_depl_cumule_${direction}.png
rm quicklook_depl_cumule_${direction}.tiff quicklook_depl_cumule_${direction}.tiff.aux.xml

# clean
#ciop-log "INFO" "Clean directory before archiving"
#rm -Rf LN_DATA
#rm depl_cumule depl_cumule.hdr depl_cumule.aux.xml
#rm depl_cumule_liss depl_cumule_liss.hdr depl_cumule_liss.aux.xml
#rm RMSpixel*
#tar -C $(dirname $TMPDIR) -cf /tmp/foobar/workdir_${direction}.tar $(basename $TMPDIR)
#exit 0

# Push results
ciop-log "INFO" "Publishing png files"
#ciop-publish -m $TMPDIR/quicklook_depl_cumule_${direction}.png
#ciop-publish -m $TMPDIR/quicklook_depl_cumule_${direction}.pngw

exit 0
