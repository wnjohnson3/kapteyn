from kapteyn import maputils
import numpy
from service import *

fignum = 21
fig = plt.figure(figsize=figsize)
frame = fig.add_axes(plotbox)
theta_a = -45
t1 = -20.0; t2 = -70.0
eta = abs(t1-t2)/2.0
title = r"""Conic equal area projection (COE) with:
$\theta_a=-45^\circ$, $\theta_1=-20^\circ$ and $\theta_2=-70^\circ$. (Cal. fig.25)"""
header = {'NAXIS'  : 2, 'NAXIS1': 100, 'NAXIS2': 80,
          'CTYPE1' : 'RA---COE',
          'CRVAL1' : 0.0, 'CRPIX1' : 50, 'CUNIT1' : 'deg', 'CDELT1' : -4.0,
          'CTYPE2' : 'DEC--COE',
          'CRVAL2' : theta_a, 'CRPIX2' : 40, 'CUNIT2' : 'deg', 'CDELT2' : 4.0,
          'PV2_1'  : theta_a, 'PV2_2' : eta
         }
X = cylrange()
Y = numpy.arange(-90,91,30.0); Y[-1] = dec0
f = maputils.FITSimage(externalheader=header)
annim = f.Annotatedimage(frame)
grat = annim.Graticule(axnum= (1,2), wylim=(-90,90.0), wxlim=(0,360),
                       startx=X, starty=Y)
grat.setp_lineswcs0(0, lw=2)
grat.setp_lineswcs1(0, lw=2)
lon_world = list(range(0,360,30))
lon_world.append(180+epsilon)
lat_constval = 10
lat_world = [-60,-30,0,30,60]
addangle0 = -90.0
labkwargs0 = {'color':'r', 'va':'center', 'ha':'center'}
labkwargs1 = {'color':'b', 'va':'bottom', 'ha':'right'}
doplot(frame, fignum, annim, grat, title,
       lon_world=lon_world, lat_world=lat_world, 
       lat_constval=lat_constval,
       labkwargs0=labkwargs0, labkwargs1=labkwargs1,
       addangle0=addangle0, markerpos=markerpos)
