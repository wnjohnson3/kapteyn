from kapteyn import maputils, tabarray
from matplotlib import pyplot as plt
import numpy

f = maputils.FITSimage("m101.fits")
fig = plt.figure()
frame = fig.add_subplot(1,1,1)
annim = f.Annotatedimage(frame, cmap="binary")
annim.Image()
grat = annim.Graticule()
#annim.Marker(pos="210.80 deg 54.34 deg", marker='o', color='b')
annim.Marker(pos="pc", marker='o', markersize=10, color='r')
annim.Marker(pos="14h03m30 54d20m", marker='o', color='y')
annim.Marker(pos="ga 102.035415152 ga 59.772512522", marker='+', 
             markersize=20, markeredgewidth=2, color='m')
annim.Marker(pos="{ecl,fk4,J2000} 174.367462651 {} 59.796173724", 
             marker='x', markersize=20, markeredgewidth=2, color='g')
annim.Marker(pos="{eq,fk4-no-e,B1950,F24/04/55} 210.360200881 {} 54.587072397", 
             marker='o', markersize=25, markeredgewidth=2, color='c', 
             alpha=0.4)

# Use pos= keyword argument to enter sequence of
# positions in pixel coordinates. The syntax is described
# in the module positions.py
pos = "200+20*sin([100:199]/20), range(100,200)"

annim.Marker(pos=pos, marker='o', color='r')

# Use x= and y= keyword arguments to enter sequence of
# positions in pixel coordinates. Note that this is not parsed by
# module positions.py. Here we need list comprehension to
# get the same effect.
xp = [400+20*numpy.sin(x/20.0) for x in range(100,200)]
yp = list(range(100,200))
annim.Marker(x=xp, y=yp, mode='pixels', marker='o', color='g')

xp = yp = 150
annim.Marker(x=xp, y=yp, mode='pixels', marker='+', color='b')

annim.plot()
annim.interact_imagecolors()
annim.interact_toolbarinfo()
plt.show()