#!/bin/bash

# do not let errors run away
set -e

export PATH=/application/tio:/usr/local/gdal-t2/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/gdal-t2/lib:$LD_LIBRARY_PATH
export GDAL_DATA=/usr/local/gdal-t2/share/gdal

# define the exit codes
SUCCESS=0
ERR_CATALOG=100
ERR_SENSOR_NOT_SUPPORTED=101

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
    $ERR_CATALOG) msg="Could not retrieve reference from catalog";;
    $ERR_SENSOR_NOT_SUPPORTED) msg="This sensor is not supported yet";;
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

# ROI
roi=$(ciop-getparam roi | tr "," " ")
ciop-log "INFO" "ROI is '$roi'"

# switch to TMPDIR
ciop-log "INFO" "Change dir to '$TMPDIR'"
cd $TMPDIR

# Fetch datasets
dates=""
while read ref; do
    if [ -z "$ref" ]; then
        continue
    fi

	# Fetch image
	ciop-log "INFO" "Process reference '$ref'"
    date=$(opensearch-client $ref startdate | cut -c 1-10 | tr -d "-")
    img_url=$(opensearch-client $ref enclosure)
    img_dl=$(ciop-copy -o $TMPDIR $img_url)
    if [ -z "$date" -o -z "$img_dl" ]; then
      exit $ERR_CATALOG;
    fi

    # What happens here: we crop/mosaic the inputs
    # into the desired frame. There may be overwrite.

    if [ -n "$(basename $img_dl | grep S2A_OPER_PRD_MSIL1C_PDMC_)" ]; then
        safedir=$(ls -d $img_dl/*.SAFE)

        # TODO: check that ROI is in product
        ciop-log "INFO" "Cropping $safedir to ROI"
        gdalwarp -q -overwrite -te $roi -te_srs 'urn:ogc:def:crs:OGC:1.3:CRS84' $safedir/GRANULE/S2A*/IMG_DATA/*_B03.jp2 ${date}.tiff
    else
        exit $ERR_SENSOR_NOT_SUPPORTED
    fi

    mean=$(gdalinfo -stats ${date}.tiff | grep 'STATISTICS_MEAN=' | cut -d= -f2)
    if [ $(echo "$mean > 0 && $mean < 2000"|bc) -eq 1 ]; then
        dates="$dates $date"
    fi

	rm -Rf $img_dl
done
dates=$(echo $dates | tr ' ' '\\n' | sort -nu | tr '\\n' ' ')
ciop-log "INFO" "Available acquisitions: $dates"

# Create correlations maps
for date1 in $dates; do
    count=0
    for date2 in $dates; do
        if [ "$date1" -ge "$date2" ]; then
            continue
        fi
        if [ $count -ge 2 ]; then
            continue
        fi

        ciop-log "INFO" "Processing $date1-$date2 pair"

        /home/mvolat/micmac/bin/mm3d MM2DPosSism ${date1}.tiff ${date2}.tiff SzW=9 Reg=0.2

        ciop-log "INFO" "Prepare publish directory for $date1-$date2 pair"
        date1_dashed="$(echo $date1|cut -c1-4)-$(echo $date1|cut -c5-6)-$(echo $date1|cut -c7-8)"
        date2_dashed="$(echo $date2|cut -c1-4)-$(echo $date2|cut -c5-6)-$(echo $date2|cut -c7-8)"
        outdir="$TMPDIR/Out_${date1_dashed}_${date1_dashed}_B03_${date2_dashed}_${date2_dashed}_B03"
        mkdir $outdir
        for f in Px1_Num6_DeZoom1_LeChantier.tif Px2_Num6_DeZoom1_LeChantier.tif; do
            /application/tio/gdalcopyproj.py ${date1}.tiff MEC/$f
            mv MEC/$f $outdir
		done

        ciop-log "INFO" "Publish $(basename $outdir)"
        ciop-publish -r $outdir

        ciop-log "INFO" "Clean after $date1-$date2 pair"
        rm -Rf MEC Pyram $outdir
        count=$(expr $count + 1)
    done
done
