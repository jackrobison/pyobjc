'''
Wrappers for the "PhotosUI" framework on MacOS X.

These wrappers don't include documentation, please check Apple's documention
for information on how to use this framework and PyObjC's documentation
for general tips and tricks regarding the translation between Python
and (Objective-)C frameworks
'''

from pyobjc_setup import setup, Extension
import os

VERSION="3.2a1"

setup(
    name='pyobjc-framework-PhotosUI',
    version=VERSION,
    description = "Wrappers for the framework PhotosUI on Mac OS X",
    long_description=__doc__,
    packages = [ "PhotosUI" ],
    setup_requires = [
        'pyobjc-core>=' + VERSION,
    ],
    install_requires = [
        'pyobjc-core>=' + VERSION,
        'pyobjc-framework-Cocoa>=' + VERSION,
    ],
    min_os_level="10.11",
    ext_modules = [
        Extension("PhotosUI._PhotosUI",
            [ "Modules/_PhotosUI.m" ],
            extra_link_args=["-framework", "PhotosUI"],
            depends=[
                os.path.join('Modules', fn)
                    for fn in os.listdir('Modules')
                    if fn.startswith('_PhotosUI')
            ]
        ),
    ],
)
