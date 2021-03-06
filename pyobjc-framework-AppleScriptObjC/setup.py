'''
Wrappers for framework 'AppleScriptObjC' on MacOSX 10.6. This framework is
not useful for most users, it provides additional functionality for AppleScript
based application bundles.

These wrappers don't include documentation, please check Apple's documention
for information on how to use this framework and PyObjC's documentation
for general tips and tricks regarding the translation between Python
and (Objective-)C frameworks
'''

from pyobjc_setup import setup

VERSION="3.2a1"

setup(
    min_os_level='10.6',
    name='pyobjc-framework-AppleScriptObjC',
    version=VERSION,
    description = "Wrappers for the framework AppleScriptObjC on Mac OS X",
    long_description=__doc__,
    packages = [ "AppleScriptObjC" ],
    setup_requires = [
        'pyobjc-core>=' + VERSION,
    ],
    install_requires = [
        'pyobjc-core>=' + VERSION,
        'pyobjc-framework-Cocoa>=' + VERSION,
    ],
)
