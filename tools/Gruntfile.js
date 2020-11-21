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
        sourceMap: true,
        separator: ';\n'
      },
      examinr: {
        src: [
          // path.join(inputDir, 'lib', 'idb-keyval', 'idb-keyval-iife.js'),
          path.join(inputDir, '_header.js'),
          path.join(inputDir, 'utils.js'),
          path.join(inputDir, 'accessibility.js'),
          path.join(inputDir, 'status.js'),
          path.join(inputDir, 'attempt.js'),
          path.join(inputDir, 'feedback.js'),
          path.join(inputDir, 'exercises.js'),
          path.join(inputDir, 'autocomplete.js'),
          path.join(inputDir, 'sections.js'),
          path.join(inputDir, 'grading.js'),
          path.join(inputDir, 'ace-monochrome.js'),
          path.join(inputDir, 'lib', 'bootstrap', 'js', 'util.js'),
          path.join(inputDir, 'lib', 'bootstrap', 'js', 'modal.js')
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
        // outputStyle: 'compact',
        sourceMap: false
      },
      examinr: {
        src: path.join(inputDir, 'examinr.scss'),
        dest: path.join(concatDir, 'examinr.css')
      }
    },

    postcss: {
      options: {
        map: false,
        processors: [
          require('autoprefixer')(),
          require('cssnano')() // minify the result
        ]
      },
      examinr: {
        src: path.join(concatDir, 'examinr.css'),
        dest: path.join(outputDir, 'exam.min.css')
      }
    },

    uglify: {
      examinr: {
        options: {
          banner:
            '/*! <%= pkg.name %> <%= pkg.version %>\n' +
            ' *! (c) 2020-<%= grunt.template.today("yyyy") %> David Kepplinger | License: <%= pkg.license %>\n' +
            ' *!\n' +
            ' *! Includes software derived from the learnr R package (https://github.com/rstudio/learnr)\n' +
            ' *!   (c) 2019 RStudio | License: Apache 2.0\n' +
            ' *! Includes the twbs/bootstrap library version 4.5.3 (https:///www.getbootstrap.com):\n' +
            ' *!   (c) 2011-2020 Twitter, Inc | License: MIT (https://github.com/twbs/bootstrap/blob/main/LICENSE)\n' +
            ' *!   (c) 2011-2020 The Bootstrap Authors (https://github.com/twbs/bootstrap/graphs/contributors) | License: MIT (https://github.com/twbs/bootstrap/blob/main/LICENSE)\n' +
            ' *! Includes the idb-keyval library version 3.2.0 (https://github.com/jakearchibald/idb-keyval):\n' +
            ' *!   (c) 2016 Jake Archibald | License: Apache 2.0 (https://github.com/jakearchibald/idb-keyval/blob/master/LICENCE)\n' +
            ' */\n',
          sourceMap: { includeSources: true },
          sourceMapIn: path.join(outputDir, 'exam.js.map'),
          wrap: 'Exam'
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
  grunt.loadNpmTasks('@lodder/grunt-postcss')

  // Configure babel only *after* grunt-concat is done
  grunt.task.registerTask('configureBabel', 'Configures babel options', function () {
    gruntConfig.babel.options.inputSourceMap = grunt.file.readJSON(path.join(concatDir, 'exam.js.map'))
  })

  grunt.initConfig(gruntConfig)

  grunt.registerTask('default', ['clean', 'concat', 'babel', 'sass', 'postcss', 'uglify'])

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
