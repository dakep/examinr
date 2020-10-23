#! /usr/bin/env Rscript

## Compile all required components of the ace editor javascript library
## into a single minified javascript file in "../inst/lib"

library(digest)
library(stringr)
library(base64enc)

source('../R/ace.R')

res <- ace_cdn_resources()

script_contents <- vapply(res$scripts, FUN.VALUE = character(1L), function (script) {
  url <- paste(res$base_href, res$version, script$src, sep = '/')
  script_contents <- readLines(url, encoding = 'UTF8', warn = FALSE)
  integrity_algo <- str_extract(script$integrity, '^[a-z0-9]+')
  computed_integrity <- base64encode(digest(script_contents, serialize = FALSE, algo = integrity_algo, raw = TRUE))
  computed_integrity <- paste(integrity_algo, computed_integrity, sep = '-')
  if (script$integrity != computed_integrity) {
    stop("Integrity of remote javascript code from ", url, " cannot be verified!\n",
         "Computed integrity\n\t", computed_integrity, "\ndoes not match expected integrity\n\t", script$integrity)
  }
  script_contents
})

ace_lib_fh <- file(file.path('..', 'inst', 'lib', sprintf('ace-%s.js', res$version)), open = 'wt')
writeLines('/*** BEGIN LICENSE BLOCK ***
Copyright (c) 2010, Ajax.org B.V.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Ajax.org B.V. nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL AJAX.ORG B.V. BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**** END LICENSE BLOCK ****/', con = ace_lib_fh)

writeLines(script_contents, con = ace_lib_fh)

close(ace_lib_fh)
