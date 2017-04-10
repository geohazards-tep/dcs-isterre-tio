#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys

import numpy as np

from osgeo import gdal

# Open image
ds = gdal.Open(sys.argv[1], gdal.GA_Update)
band = ds.GetRasterBand(1)

# Get data to compute median
# If image is too big, get data downsampled because we don't want to use 
# too much memory to do so.
xsize_max = 4096
ysize_max = 4096
data = None
if band.XSize <= xsize_max and band.YSize <= ysize_max:
    data = ds.ReadAsArray()
else:
    data = ds.ReadAsArray(0, 0,
                          band.XSize, band.YSize,
                          xsize_max, ysize_max)
data = data.flatten()

# Compute median
median = np.median(data)
del data

# Now, update the image
for y in range(band.YSize):
    line = band.ReadAsArray(0, y, band.XSize, 1)
    band.WriteArray(line - median, 0, y)
del ds
