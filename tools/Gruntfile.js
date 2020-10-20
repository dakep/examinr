module.exports = function (grunt) {
  const path = require('path')
  const fs = require('fs')
  const outputDir = '../inst/www'
  const inputDir = '../srcwww'
  grunt.util.linefeed = '\n'

  const gruntConfig = {
    pkg: readPackageFile(),

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
            '/*! <%= pkg.name %> <%= pkg.version %>\n' +
            ' *! Original work (c) 2019 RStudio | License: Apache 2.0\n' +
            ' *! Modified work (c) 2020-<%= grunt.template.today("yyyy") %> David Kepplinger | ' +
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

  grunt.registerTask('default', ['babel', 'cssmin', 'uglify'])

  function readPackageFile () {
    var pkg = grunt.file.readJSON('package.json')
    pkg.name = getFromDescriptionFile('Package')
    pkg.version = getFromDescriptionFile('Version')
    pkg.license = getFromDescriptionFile('License')
    return pkg
  }

  function getFromDescriptionFile (key) {
    const lines = fs.readFileSync('../DESCRIPTION', 'utf8').split(/\r?\n/)
    const dcfKeyValuePattern = new RegExp('^' + key + ':')
    const matchingLines = lines.filter(function (line) {
      return dcfKeyValuePattern.test(line)
    })
    return matchingLines[0].replace(new RegExp(key + ': *'), '')
  }
}
