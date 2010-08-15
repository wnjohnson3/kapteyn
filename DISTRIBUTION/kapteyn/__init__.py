"""Kapteyn package.

"""

from os import path

package_dir = path.abspath(path.dirname(__file__))

__all__=['celestial', 'wcs', 'wcsgrat', 'tabarray', 'maputils',
         'mplutil', 'positions', 'shapes', 'rulers', 'filters',
         'interpolation']

__version__='2.0.2b1'
