'''
===copyright===
Yury Ryabov
riabovvv@gmail.com
http://ssrebelious.blogspot.com
2013, 2014

The code here is provided under GPLv3 licence (http://www.gnu.org/licenses/gpl-3.0.html)
exept for the parts that are distributed under different term and conditions.
===copyright===

As usual this software provided 'AS IS' and there is no warranty
that it will work on your system, or that it will not cause any kind of damage.
Use it at your own risk.

***change log***
(21.04.2014) - multiband rasters are supported now
(02.04.2014) - resolution is now unified properly
(04.01.2014) - two raster inputs replaced with multiraster input
***change log***
'''

from osgeo import gdal
import sys
from numpy import *
import ntpath
import re
import platform
import os

replace_No_Data_value_with = 0
output_directory = "tmp"
rasters = "vel.tif;DEM.tif;slope.tif;aspect.tif"

rasters_list = rasters.split(';')
no_data = replace_No_Data_value_with

def checkFolder(path):
  '''
  checks if the folder exists
  @param path: Output path (string)
  @return:     True if path is given (boolean)
  '''
  if os.path.isdir(path):
    return True
  else:
    return False


def OutputFilePath(in_path, out_path):
  '''
  creates a path to the resulting file

  @param in_path:    Input raster path (string)
  @param out_path    Input path to the destination folder (string)
  @return full_path  Output directory + filename path (string)
  '''
  f_name = ntpath.basename(in_path)
  match = re.search(r'(.+)\.\w+', f_name)
  f_name = match.group(1) + '_unified.tif'
  delimiter = '/'
  out_path = out_path + delimiter
  full_path = ntpath.join(out_path, f_name)
  return full_path


def FindCorners(raster):
  '''
  returns min and max X and Y values of the given raster
  @param raster:               Input raster (GDALDataset)
  @return list of coordinates  Output min and max coordinates of raster (list)
  '''
  width = raster.RasterXSize
  height = raster.RasterYSize
  geo_transform = raster.GetGeoTransform()
  top_left_x = geo_transform[0]
  top_left_y = geo_transform[3]
  top_right_x = geo_transform[0] + width*geo_transform[1]
  top_right_y = geo_transform[3] + width*geo_transform[4]
  bottom_right_y = geo_transform[3] + width*geo_transform[4] + height*geo_transform[5]
  bottom_right_x = geo_transform[0] + width*geo_transform[1] + height*geo_transform[2]
  bottom_left_x =  geo_transform[0] + 1*geo_transform[1] + height*geo_transform[2]
  bottom_left_y = geo_transform[3] + height*geo_transform[5]
  x_list = [top_left_x, top_right_x, bottom_right_x, bottom_left_x]
  y_list = [top_left_y, top_right_y, bottom_left_y, bottom_right_y]
  min_x = min(x_list)
  max_x = max(x_list)
  min_y = min(y_list)
  max_y = max(y_list)
  return [min_x, min_y, max_x, max_y]

def finCoordinates(rasters_list):
  '''
  returns a list of the coordinates for the unified raster
  @param rasters_list: Lists of rasters (list)
  @return:             List of coordinates [min_x, min_y, max_x, max_y]
  '''
  fin_coordinates = []
  for raster in rasters_list:
    rast = gdal.Open(raster)
    coordinates = FindCorners(rast)
    rast = None
    if len(fin_coordinates) != 4:
      fin_coordinates = coordinates
    else:
      minx = coordinates[0]
      miny = coordinates[1]
      maxx = coordinates[2]
      maxy = coordinates[3]
      if minx < fin_coordinates[0]:
        fin_coordinates[0] = minx
      if miny < fin_coordinates[1]:
        fin_coordinates[1] = miny
      if maxx > fin_coordinates[2]:
        fin_coordinates[2] = maxx
      if maxy > fin_coordinates[3]:
        fin_coordinates[3] = maxy
  return fin_coordinates


def InvGeoTransform(gt_in):
  # Compute determinate
  det = gt_in[1] * gt_in[5] - gt_in[2] * gt_in[4]
  if( abs(det) < 0.000000000000001 ):
      return
  inv_det = 1.0 / det
  # compute adjoint, and divide by determinate
  gt_out = [0,0,0,0,0,0]
  gt_out[1] =  gt_in[5] * inv_det
  gt_out[4] = -gt_in[4] * inv_det
  gt_out[2] = -gt_in[2] * inv_det
  gt_out[5] =  gt_in[1] * inv_det
  gt_out[0] = ( gt_in[2] * gt_in[3] - gt_in[0] * gt_in[5]) * inv_det
  gt_out[3] = (-gt_in[1] * gt_in[3] + gt_in[0] * gt_in[4]) * inv_det
  return gt_out

def ApplyGeoTransform(inx,iny,gt):
  ''' Apply a geotransform
      @param  inx:       Input x coordinate (double)
      @param  iny:       Input y coordinate (double)
      @param  gt:        Input geotransform (six doubles)

      @return: outx,outy Output coordinates (two doubles)
  '''
  outx = gt[0] + inx*gt[1] + iny*gt[2]
  outy = gt[3] + inx*gt[4] + iny*gt[5]
  return (outx,outy)

def MapToPixel(mx,my,gt):
  ''' Convert map to pixel coordinates
      @param  mx:    Input map x coordinate (double)
      @param  my:    Input map y coordinate (double)
      @param  gt:    Input geotransform (six doubles)
      @return: px,py Output coordinates (two ints)

      @change: changed int(p[x,y]+0.5) to int(p[x,y]) as per http://lists.osgeo.org/pipermail/gdal-dev/2010-June/024956.html
      @change: return floats
      @note:   0,0 is UL corner of UL pixel, 0.5,0.5 is centre of UL pixel
  '''
  if gt[2]+gt[4]==0: #Simple calc, no inversion required
      px = (mx - gt[0]) / gt[1]
      py = (my - gt[3]) / gt[5]
  else:
      px,py=ApplyGeoTransform(mx,my,InvGeoTransform(gt))
  #return int(px),int(py)
  return px,py

def PixelToMap(px,py,gt):
  ''' Convert pixel to map coordinates
      @param  px:    Input pixel x coordinate (double)
      @param  py:    Input pixel y coordinate (double)
      @param  gt:    Input geotransform (six doubles)
      @return: mx,my Output coordinates (two doubles)

      @note:   0,0 is UL corner of UL pixel, 0.5,0.5 is centre of UL pixel
  '''
  mx,my=ApplyGeoTransform(px,py,gt)
  return mx,my

def ExtendRaster(raster, xy_list, output, main_geo_transform, proj, no_data):
  '''
  Extends canvas of the given raster to the extent provided by xy_list in
  [minx, miny, maxx, maxy] format

  @param raster   Input raster to be processed (GDALDataset)
  @param xy_list  Input list of min and max XY coordinates of resulting raster
                  (list)
  @param output   Input full path to the resulting raster
  @param main_geo_transform: Main parameters of geotransformation (gdal.GetGeoTransform())
  @param proj:    Projection of the raster (gdal.GetProjection())
  @param no_data: a value to be set as 'No Data' value
  @returm         Output indicates that function ended successfully (only True)
  '''
  # check xy_list
  if len(xy_list) != 4:
    sys.exit('xy_list must contain 4 values!')
  minx = xy_list[0]
  miny = xy_list[1]
  maxx = xy_list[2]
  maxy = xy_list[3]
  band = raster.GetRasterBand(1)
  NA = band.GetNoDataValue()
  data_type = band.DataType
  # set number of columns and rows for raster
  geo_transform = raster.GetGeoTransform()
  columns = (maxx - minx) / main_geo_transform[1]
  columns = int(abs(columns))
  rows = (maxy - miny) / main_geo_transform[5]
  rows = int(abs(rows))
  bands = raster.RasterCount
  # create raster
  r_format = "GTiff"
  driver = gdal.GetDriverByName(r_format)
  metadata = driver.GetMetadata()
  outData = driver.Create(output, columns, rows, bands, data_type)
  outData.SetProjection(proj)
  # we don't want rotated raster in output
  new_geo_transform = [minx, main_geo_transform[1], 0.0,
    maxy, 0.0, main_geo_transform[5]]
  outData.SetGeoTransform(new_geo_transform)
  for i in range(1, (bands +1) ):
    band = raster.GetRasterBand(i)
    band = band.ReadAsArray()
    # we create array here to write into it created raster
    new_raster = zeros( (rows, columns) )
    # populate array with the values from original raster
    for col in range(columns):
      for row in range(rows):
        # convert array value location to XY-coordinates
        x,y = PixelToMap(col, row, new_geo_transform)
        # convert coordinates to pixel location at the original raster
        px,py = MapToPixel(x, y, geo_transform)
        # extract pixel value
        try:
          if px < 0 or py < 0:
            pix_value = no_data
          else:
            pix_value = band[py, px]
            if pix_value == NA:
              pix_value = no_data
        except:
          pix_value = no_data
        # assign extracted value to array
        new_raster[row, col] = pix_value
    outData.GetRasterBand(i).WriteArray(new_raster)
  # close dataset
  outData = None
  return True

def processingList(rasters_list, out_dir):
  '''
  creates lists for processing purposes
  '''
  processing_list = [] # [(raster_1, output_1), (raster_2, output_2)]
  for raster in rasters_list:
    output = OutputFilePath(raster, out_dir)
    processing_list.append( (raster, output) )
  return processing_list

def main(rasters_list, no_data):
  if not checkFolder(output_directory):
    return None
  # get coordinates of corners for the final raster
  fin_coordinates = finCoordinates(rasters_list)
  # processing rasters
  processing_list = processingList(rasters_list, output_directory)
  raster_1 = rasters_list[0]
  raster_1 = gdal.Open(raster_1)
  main_geo_transform = raster_1.GetGeoTransform() # geo transfrormation of the etalon raster
  proj = raster_1.GetProjection()
  if not no_data:
    no_data = raster_1.GetRasterBand(1).GetNoDataValue()
    if not no_data:
      no_data = -9999
  for tupl in processing_list:
    raster = gdal.Open(tupl[0])
    output = ExtendRaster(raster, fin_coordinates, tupl[1], main_geo_transform, proj, no_data)
    raster = None
    if output != True:
      return None

main(rasters_list, no_data)
