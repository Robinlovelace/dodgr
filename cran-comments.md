# CRAN notes for osmdata_0.0.3 submission

* Previous failure on solaris rectified (a C++ implicit type conversion)
* Previous failure on Windows oldrel rectified (it was just a test failure).

## Test environments

This submission generates NO notes on:
* Linux (via Travis-ci): R-release, R-devl
* OSX (via Travis-ci): R-release
* Windows Visual Studio 2015 x64 (via appveyor)
* win-builder: R-oldrelease, R-release, R-devel

Package also checked using both local memory sanitzer and `rocker/r-devel-san`
with clean results. 