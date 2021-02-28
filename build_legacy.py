#!/Library/Frameworks/Python.framework/Versions/3.8/bin/python3
import tempfile
import shutil
from re import sub
import os

# Clone current source.
tmpPath = tempfile.mkdtemp()
print('created dtemp at:', tmpPath)
if os.path.exists(tmpPath):
        shutil.rmtree(tmpPath)
shutil.copytree('.', tmpPath)
shutil.rmtree(tmpPath + '/.theos')

# Patch Makefile's & control
rootMakefile = open(tmpPath + '/Makefile').read()
rootMakefile = sub(r'TARGET = (\w+):clang:.*:.*', r'TARGET = \1:clang:latest:11.0', rootMakefile)
open(tmpPath + '/Makefile', 'w').write(rootMakefile)

subMakefile = open(tmpPath + '/framepreferences/Makefile').read()
open(tmpPath + '/framepreferences/Makefile', 'w').write(subMakefile)

rootControlfile = """
Package: com.zx02.frame.legacy
Name: Frame (Legacy)
Depends: ${LIBSWIFT}, mobilesubstrate,preferenceloader,firmware (>= 11.0),firmware (<= 12.1.9)
Version: 2.4.1
Architecture: iphoneos-arm
Description: (For iOS < 12.2) Bring your iDevice to life with true video wallpapers.
Maintainer: Zerui Chen
Author: Zerui Chen
Section: Wallpaper
"""
open(tmpPath + '/control', 'w').write(rootControlfile)

# Build.
import subprocess
subprocess.check_call("cd {} && rm -rf .theos && make package".format(tmpPath), shell=True)

# Copy the built package back to ./packages.
subprocess.check_call("mv {}/packages/* ./packages/".format(tmpPath), shell=True)

# Clean up.
shutil.rmtree(tmpPath)