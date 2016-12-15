import ogr

import sys



lon = float(sys.argv[1])

lat = float(sys.argv[2])

shpfile = str(sys.argv[3])



# load the shape file as a layer

drv = ogr.GetDriverByName('ESRI Shapefile')

ds_in = drv.Open(shpfile)

lyr_in = ds_in.GetLayer(0)



# field index for which i want the data extracted

idx_reg = lyr_in.GetLayerDefn().GetFieldIndex("Id")



# create point geometry

pt = ogr.Geometry(ogr.wkbPoint)

pt.AddPoint(lon, lat)



#Set up a spatial filter such that the only features we see when we

#loop through "lyr_in" are those which overlap the point defined above

lyr_in.SetSpatialFilter(pt)





#Loop through the overlapped features and display the field of interest

for feat_in in lyr_in:
    print(1)
