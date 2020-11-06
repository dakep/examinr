/*
 * Some parts of this file are dervied from the learnr project, which is licensed under the Apache 2.0 license.
 * Original work Copyright 2019 RStudio
 * Derived work Copyright 2020 David Kepplinger
 */
exports.exercises = (function () {
  'use strict'

  const kMinLines = 5
  const kMaxDefaultLines = 20

  var exerciseRunButtonEnabled = true

  function attachAceEditor (id, code) {
    var editor = ace.edit(id)
    editor.setHighlightActiveLine(false)
    editor.setShowPrintMargin(false)
    editor.setShowFoldWidgets(false)
    editor.setBehavioursEnabled(true)
    editor.renderer.setDisplayIndentGuides(false)
    editor.setTheme('ace/theme/textmate')
    editor.$blockScrolling = Infinity
    editor.session.setMode('ace/mode/r')
    editor.session.getSelection().clearSelection()
    editor.setValue(code, -1)
    return editor
  }

  function exerciseRunning (outputContainer, running) {
    if (typeof running === 'undefined') {
      running = !exerciseRunButtonEnabled
    }

    exports.shim.toggle(outputContainer, running)
    exerciseRunButtonEnabled = (running === false)
    $('.examinr-run-button').prop('disabled', !exerciseRunButtonEnabled)
  }

  function initializeExerciseEditors () {
    $('.examinr-exercise').each(function () {
      const exercise = $(this)
      const exerciseOptions = JSON.parse(exercise.children('script[type="application/json"]').detach().text() || '{}')
      var code = ''
      exercise.children('pre').each(function () {
        code += $(this).children('code').text() + '\n'
      }).remove()

      const codeLines = code.split(/\r?\n/).length

      const lines = (exerciseOptions.lines ? Math.max(1, exerciseOptions.lines)
        : Math.min(Math.max(kMinLines, codeLines), kMaxDefaultLines))

      if (codeLines < lines) {
        code += '\n'.repeat(lines - codeLines)
      }

      const editorId = exerciseOptions.inputId + '-editor'
      const pointsLabel = exerciseOptions.points ? '<span class="label ' + (exerciseOptions.labelClass || '') + '">' +
        exerciseOptions.points + '</span>' : ''

      const messageStrings = exports.status.getMessage('exercise') || {}

      const exercisePanel = $('<div class="panel ' + (exerciseOptions.panelClass || '') + '">' +
        '<div class="panel-heading">' +
          '<button type="button" class="btn ' + (exerciseOptions.buttonClass || '') + ' btn-xs examinr-run-button pull-right">' +
            '<span class="glyphicon glyphicon-play" aria-hidden="true"></span>' + exerciseOptions.buttonLabel +
          '</button>' +
          '<h5 class="panel-title">' + (exerciseOptions.title || '') + pointsLabel + '</h5>' +
        '</div>' +
        '<div class="panel-body">' +
          '<div id="' + editorId + '" class="examinr-exercise-editor" role="textbox" contenteditable="true" ' +
              'aria-multiline="true" tabindex=0 ></div>' +
        '</div>' +
        '<div class="panel-footer">' +
          '<div class="small alert alert-warning examinr-exercise-status" role="log">' +
            messageStrings.notYetRun +
          '</div>' +
        '</div>' +
      '</div>')

      const outputContainer = $('<div class="examinr-exercise-output well" role="status"></div>')
      const exerciseEditor = exercise.find('#' + editorId)

      exercise.append(exercisePanel).append(outputContainer)

      // make exercise more accessible
      exports.aria.labelledBy(exercise, exercisePanel.find('.panel-title'))
      exports.aria.associate('controls', exercisePanel.find('.examinr-run-button'), outputContainer)
      exerciseEditor.attr('aria-label', exerciseOptions.inputLabel)
      exerciseEditor.children().attr('aria-hidden', 'true')

      if (!messageStrings.notYetRun) {
        exercise.find('.examinr-exercise-status').hide()
      } else {
        exports.aria.describedBy(exercisePanel, exercise.find('.examinr-exercise-status'))
      }
      exercise.find('.examinr-exercise-output').hide()

      const runCodeButton = exercise.find('.examinr-run-button')

      // Proxy a "run code" event through the button to also trigger shiny input events.
      const triggerClick = function () {
        runCodeButton.click()
      }

      const editor = attachAceEditor(editorId, code)
      editor.setFontSize(0.8125 * parseFloat(exercise.find('.panel-body').css('font-size')))
      editor.commands.addCommand({
        name: 'run_rcode',
        bindKey: { win: 'Ctrl+Enter', mac: 'Command+Enter' },
        exec: triggerClick
      })
      editor.commands.addCommand({
        name: 'run_rcode-shift',
        bindKey: { win: 'Ctrl+Shift+Enter', mac: 'Command+Shift+Enter' },
        exec: triggerClick
      })

      const updateAceHeight = function () {
        editor.setOptions({
          minLines: lines,
          maxLines: lines
        })
      }
      updateAceHeight()
      editor.getSession().on('change', updateAceHeight)

      runCodeButton.click(function () {
        editor.focus()
      })

      exercise.data({
        editor: editor,
        options: exerciseOptions
      })

      exercise.parents('section').on('shown', function () {
        editor.resize(true)
      })
    })
  }

  function initializeEditorBindings () {
    const inputBindings = new Shiny.InputBinding()
    $.extend(inputBindings, {
      find: function (scope) {
        return $(scope).find('.examinr-exercise')
      },
      getId: function (exercise) {
        return $(exercise).data('options').inputId
      },
      subscribe: function (exercise, callback) {
        exercise = $(exercise)
        exercise.find('.examinr-run-button').on('click.examinrExerciseInputBinding', function () {
          if (exerciseRunButtonEnabled) {
            exercise.data('sendData', true)
            exerciseRunning(exercise.find('.examinr-exercise-output'), true)
            callback(true)
          }
        })
      },
      unsubscribe: function (exercise) {
        $(exercise).find('.examinr-run-button').off('.examinrExerciseInputBinding')
      },
      getValue: function (exercise) {
        exercise = $(exercise)
        if (exercise.data('sendData') !== true) {
          return null
        }
        exercise.data('sendData', false)
        return {
          label: exercise.data('options').label,
          code: exercise.data('editor').getSession().getValue(),
          timestamp: new Date().getTime()
        }
      },
      setValue: function (exercise, value) {
        $(exercise).data('editor').getSession().setValue(value)
      }
    })
    Shiny.inputBindings.register(inputBindings, 'examinr.exerciseInputBinding')

    const outputBindings = new Shiny.OutputBinding()
    $.extend(outputBindings, {
      find: function (scope) {
        return $(scope).find('.examinr-exercise')
      },
      getId: function (exercise) {
        return $(exercise).data('options').outputId
      },
      renderValue: function (exercise, data) {
        exercise = $(exercise)
        if (data.result) {
          exercise.find('.examinr-exercise-output').show().html(data.result)
        } else {
          exercise.find('.examinr-exercise-output').hide().html('')
        }
        if (data.status) {
          exercise.find('.examinr-exercise-status')
            .removeClass('alert-success')
            .removeClass('alert-info')
            .removeClass('alert-warning')
            .removeClass('alert-danger')
            .addClass('alert-' + (data.status_class || 'info'))
          exercise.find('.examinr-exercise-status').show().html(data.status)
        } else {
          exercise.find('.examinr-exercise-status').hide().html('')
        }
        exerciseRunning(exercise.find('.examinr-exercise-output'), false)
      },
      renderError: function (exercise, error) {
        exercise = $(exercise)
        exerciseRunning(exercise.find('.examinr-exercise-output'), false)
        exercise.find('.examinr-exercise-output').hide()
        exercise.find('.examinr-exercise-status').show().text(error.message)
      },
      clearError: function (exercise) {
        exercise = $(exercise)
        exerciseRunning(exercise.find('.examinr-exercise-output'), false)
        exercise.find('.examinr-exercise-output').hide()
        exercise.find('.examinr-exercise-status').hide()
      }
    })
    Shiny.outputBindings.register(outputBindings, 'examinr.exerciseOutputBinding')
  }

  $(function () {
    initializeExerciseEditors()
    initializeEditorBindings()
  })

  return {}
}())
