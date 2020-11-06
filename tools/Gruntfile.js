module.exports = function (grunt) {
  const path = require('path')
  const fs = require('fs')
  const sass = require('sass')

  const outputDir = '../inst/www'
  const inputDir = '../srcwww'
  const concatDir = './tmp_concat'
  grunt.util.linefeed = '\n'

  const gruntConfig = {
    pkg: readPackageFile(),

    clean: {
      options: {
        force: true
      },
      src: [
        path.join(concatDir, 'exam.js'),
        path.join(outputDir, 'exam.min.css'),
        path.join(outputDir, 'exam.js'),
        path.join(outputDir, 'exam.js.map'),
        path.join(outputDir, 'exam.min.js'),
        path.join(outputDir, 'exam.min.js.map')
      ]
    },

    concat: {
      options: {
        sourceMap: true
      },
      examinr: {
        src: [
          path.join(inputDir, '_header.js'),
          path.join(inputDir, 'shim.js'),
          path.join(inputDir, 'status.js'),
          path.join(inputDir, 'questions.js'),
          path.join(inputDir, 'exercises.js'),
          path.join(inputDir, 'autocomplete.js'),
          path.join(inputDir, 'sections.js'),
          path.join(inputDir, '_footer.js')
        ],
        dest: path.join(concatDir, 'exam.js'),
        nonull: true
      }
    },

    babel: {
      options: {
        sourceMap: true,
        compact: false,
        presets: ['@babel/preset-env']
      },
      examinr: {
        src: path.join(concatDir, 'exam.js'),
        dest: path.join(outputDir, 'exam.js')
      }
    },

    sass: {
      options: {
        implementation: sass,
        outputStyle: 'compressed',
        sourceMap: false
      },
      examinr: {
        src: path.join(inputDir, 'exam.scss'),
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
          sourceMap: { includeSources: true }
        },
        src: path.join(outputDir, 'exam.js'),
        dest: path.join(outputDir, 'exam.min.js')
      }
    }
  }

  grunt.loadNpmTasks('grunt-babel')
  grunt.loadNpmTasks('grunt-contrib-clean')
  grunt.loadNpmTasks('grunt-contrib-concat')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-sass')

  // Configure babel only *after* grunt-concat is done
  grunt.task.registerTask('configureBabel', 'Configures babel options', function () {
    gruntConfig.babel.options.inputSourceMap = grunt.file.readJSON(path.join(concatDir, 'exam.js.map'))
  })

  grunt.initConfig(gruntConfig)

  grunt.registerTask('default', ['clean', 'concat', 'babel', 'sass', 'uglify'])

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
