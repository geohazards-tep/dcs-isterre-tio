#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import os, sys, struct, subprocess, warnings, zlib
warnings.simplefilter("ignore", category=RuntimeWarning)

import numpy as np
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
from osgeo import gdal

# Open the time serie dataset
ds = gdal.Open(sys.argv[1], gdal.GA_ReadOnly)
if ds == None:
    exit(1)
if ds.GetDriver().ShortName == "ENVI":   # NSBAS time serie (most likely)
    pass
elif ds.GetDriver().ShortName == "HDF5": # GiANT time serie (most likely)
    del ds
    ds = gdal.Open("HDF5:\""+sys.argv[1]+"\"://recons", gdal.GA_ReadOnly)

# Get min/maxes over the dates
dsmin, dsmax = float("inf"), -float("inf")
for i in range(ds.RasterCount):
    band = ds.GetRasterBand(i+1)
    # Get stats
    bmin, bmax, bmean, bstddev = band.GetStatistics(0, 1)
    # Update dsmin/dsmax
    dsmin, dsmax = min(dsmin, bmin), max(dsmax, bmax)

# Create the png files
downscale = 0.25
# TODO: would be cool to generate extra images to smoothe transitions
# Use a matplotlib figure to colorize
for i in range(ds.RasterCount):
    fig = plt.figure(frameon=False)
    fig.set_size_inches(ds.RasterXSize*downscale/72,
                        ds.RasterYSize*downscale/72)
    ax = plt.Axes(fig, [0., 0., 1., 1.])
    ax.set_axis_off()
    fig.add_axes(ax)
    band = ds.GetRasterBand(i+1)
    band_name = ds.GetMetadata()["Band_%d"%(i+1)]
    data = band.ReadAsArray(0, 0,
                            ds.RasterXSize, ds.RasterYSize,
                            ds.RasterXSize*downscale, ds.RasterYSize*downscale)
    data[data == band.GetNoDataValue()] = np.nan
    ax.imshow(data, cmap="jet", interpolation="bilinear", vmin=dsmin, vmax=dsmax)
    ax.text(0.99, 0.01,
            band_name,
            verticalalignment='bottom', horizontalalignment='right',
            transform=ax.transAxes,
            fontsize=28)
    fig.savefig("quicklook_tmp_%03d.png" % i, dpi=72)

# Convert to APNG
status = subprocess.call("ffmpeg -y -loglevel panic -framerate 4 -i 'quicklook_tmp_%%03d.png' -f apng -c:v apng %s" % sys.argv[2], shell=True)

# ffmpeg do not allow (yet) to set APNG loop attribute like it does with GIF...
# so do it the hard way: hack into the file :)
apngf = open(sys.argv[2], "r+b")
apngf.read(8)
while(True):
    chunk_len = struct.unpack(">I", apngf.read(4))[0]
    chunk_type = apngf.read(4)
    if chunk_type == b"acTL":
        break
    apngf.seek(chunk_len+4, 1)
num_frames = apngf.read(4)
apngf.seek(apngf.tell()) # do not ask why...
apngf.write(struct.pack(">II", 0, zlib.crc32(num_frames+b"\0\0\0\0")&0xffffffff))
apngf.close()

# Clean files
for i in range(ds.RasterCount):
    os.unlink("quicklook_tmp_%03d.png" % i)

# World file, if possible
gt = ds.GetGeoTransform()
if gt is not None and gt != (0,1,0,0,0,1):
    # Apply downscale
    gt = list(gt)
    for i in [1, 2, 4, 5]:
        gt[i] = gt[i] / downscale
    gt = tuple(gt)
    # Open and write world file
    apngwf = open(sys.argv[2]+"w", "w")
    apngwf.write("%f\n%f\n%f\n%f\n%f\n%f\n" % (gt[1], gt[2], gt[4], gt[5], gt[0], gt[3]))
    apngwf.close()
