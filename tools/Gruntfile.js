module.exports = function (grunt) {
  const path = require('path')
  const outputDir = '../inst/www'
  const inputDir = '../srcwww'
  // Make sure all plattforms to use `\n` as eol char: https://stackoverflow.com/questions/29817511/grunt-issue-with-line-endings
  grunt.util.linefeed = '\n'

  const gruntConfig = {
    pkg: pkgInfo(),

    babel: {
      options: {
        sourceMap: true,
        compact: false,
        presets: ['@babel/preset-env']
      },
      examinr: {
        src: path.join(inputDir, 'exam.js'),
        dest: path.join(outputDir, 'exam.js')
      }
    },

    cssmin: {
      options: {
        mergeIntoShorthands: false,
        roundingPrecision: -1
      },
      examinr: {
        src: path.join(inputDir, 'exam.css'),
        dest: path.join(outputDir, 'exam.min.css')
      }
    },

    uglify: {
      examinr: {
        options: {
          banner:
            '/*! <%= pkg.name %> <%= pkg.version %> | ' +
            '(c) 2020-<%= grunt.template.today("yyyy") %> David Kepplinger | ' +
            'License: <%= pkg.license %> */\n',
          sourceMap: {
            includeSources: true
          }
        },
        src: path.join(outputDir, 'exam.js'),
        dest: path.join(outputDir, 'exam.min.js')
      }
    }
  }

  grunt.loadNpmTasks('grunt-babel')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-cssmin')
  grunt.initConfig(gruntConfig)

  grunt.registerTask('default', [
    'babel',
    'cssmin',
    'uglify'
  ])

  /*
  * The following utility functions pkgInfo() and descKeyValue() are based on the source code in
  * https://github.com/rstudio/shiny/blob/46852e2051875b7241d9675fcba507b53f07ab2d/tools/Gruntfile.js
  * Copyright (c) 2020 RStudio Inc
  * Distributed under GPL-3 (GNU GENERAL PUBLIC LICENSE version 3).
  */
  function pkgInfo () {
    var pkg = grunt.file.readJSON('package.json')

    pkg.name = descKeyValue('Package')
    pkg.version = descKeyValue('Version')
    pkg.license = descKeyValue('License')

    return pkg
  }

  // From the DESCRIPTION file, get the value of a key. This presently only
  // works if the value is on one line, the same line as the key.
  function descKeyValue (key) {
    var lines = require('fs').readFileSync('../DESCRIPTION', 'utf8').split(/\r?\n/)

    var pattern = new RegExp('^' + key + ':')
    var txt = lines.filter(function (line) {
      return pattern.test(line)
    })

    txt = txt[0]

    pattern = new RegExp(key + ': *')
    txt = txt.replace(pattern, '')

    return txt
  }
}
