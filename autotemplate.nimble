# Package

version       = "0.1.0"
author        = "PMunch"
description   = "Simple test of auto-template generation"
license       = "MIT"
srcDir        = "src"
bin           = @["./server"]


# Dependencies

requires "nim >= 1.6.0"
requires "jester"
requires "with >= 0.4.0"
requires "templates"
