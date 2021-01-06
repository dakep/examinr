/*
 * Some parts of this file are dervied from the learnr project, which is licensed under the Apache 2.0 license.
 * Original work Copyright 2019 RStudio
 * Derived work Copyright 2020 David Kepplinger
 */
exports.exercises = (function () {
  'use strict'

  const kMinLines = 5
  const kMaxDefaultLines = 20
  const kThemeMonochrome = 'ace/theme/monochrome'
  const kThemeDefault = 'ace/theme/textmate'
  const kRetryUpdateHeightDelay = 250

  let currentTheme = kThemeMonochrome
  let exerciseRunButtonEnabled = true

  function attachAceEditor (id, code) {
    const editor = ace.edit(id)
    editor.setHighlightActiveLine(false)
    editor.setShowPrintMargin(false)
    editor.setShowFoldWidgets(false)
    editor.setBehavioursEnabled(true)
    editor.renderer.setDisplayIndentGuides(false)
    editor.setTheme(currentTheme)
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

    exports.utils.toggleShim(outputContainer, running)
    exerciseRunButtonEnabled = (running === false)
    $('.examinr-run-button').prop('disabled', !exerciseRunButtonEnabled)
  }

  function initializeExerciseEditor () {
    const exercise = $(this)
    const exerciseOptions = JSON.parse(exercise.children('script[type="application/json"]').detach().text() || '{}')
    let code = ''
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
    const pointsLabel = exerciseOptions.points
      ? '<span class="examinr-points badge badge-secondary">' + exerciseOptions.points + '</span>'
      : ''

    const messageStrings = exports.status.getMessage('exercise') || {}

    const exercisePanel = $('<div class="card">' +
      '<h6 class="card-header">' + (exerciseOptions.title || '') + pointsLabel + '</h6>' +
      '<div class="card-body">' +
        '<div id="' + editorId + '" class="examinr-exercise-editor" role="textbox" contenteditable="true" ' +
            'aria-multiline="true" tabindex=0 ></div>' +
      '</div>' +
      '<div class="card-footer text-muted">' +
        '<button type="button" class="btn btn-secondary btn-sm examinr-run-button float-right">' +
          '<span class="icon"><svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-play-fill" fill="currentColor" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M11.596 8.697l-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 0 1 0 1.393z"/></svg></span>' +
          exerciseOptions.buttonLabel +
        '</button>' +
        '<div class="examinr-exercise-status">' + messageStrings.notYetRun + '</div>' +
      '</div>' +
    '</div>')

    const outputContainer = $('<div class="examinr-exercise-output card bg-light">' +
      (messageStrings.outputTitle
        ? ('<div class="card-header text-muted small">' + messageStrings.outputTitle + '</div>')
        : '') +
      '<div class="card-body p-3" role="status"></div>' +
    '</div>')
    const exerciseEditor = exercise.find('#' + editorId)

    exercise.append(exercisePanel).append(outputContainer)

    // make exercise more accessible
    exports.accessibility.ariaLabelledBy(exercise, exercisePanel.find('.card-header'))
    exports.accessibility.ariaAssociate('controls', exercisePanel.find('.examinr-run-button'), outputContainer.find('.card-body'))
    exerciseEditor.attr('aria-label', exerciseOptions.inputLabel)
    exerciseEditor.children().attr('aria-hidden', 'true')

    if (!messageStrings.notYetRun) {
      exercise.find('.examinr-exercise-status').hide()
    } else {
      exports.accessibility.ariaDescribedBy(exercisePanel, exercise.find('.examinr-exercise-status'))
    }
    exercise.find('.examinr-exercise-output').hide()

    const runCodeButton = exercise.find('.examinr-run-button')

    // Proxy a "run code" event through the button to also trigger shiny input events.
    const triggerClick = function () {
      runCodeButton.click()
    }

    const editor = attachAceEditor(editorId, code)
    editor.setFontSize(0.8125 * parseFloat(exercise.find('.card-body').css('font-size')))
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

    runCodeButton.click(function () {
      editor.focus()
    })

    exercise.data({
      editor: editor,
      options: exerciseOptions
    })

    exercise.parents('section').on('shown', exports.utils.autoRetry(function () {
      // window.console.debug('Resize editor ' + exerciseOptions.inputId + ' after section is shown.')
      updateAceHeight()
      editor.resize(true)
      return $(editor.container).height() > 0
    }, kRetryUpdateHeightDelay, true))
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
          const outputContainer = exercise.find('.examinr-exercise-output').show().find('.card-body')
          outputContainer.html(data.result)
          outputContainer.find('.kable-table table').addClass('table table-striped table-sm')
        } else {
          exercise.find('.examinr-exercise-output').hide()
        }
        if (data.status) {
          const footerClass = (data.status_class && data.status_class !== 'info')
            ? ('alert-' + data.status_class) : 'text-muted'

          exercise.find('.card-footer')
            .removeClass('text-muted')
            .removeClass('alert-success')
            .removeClass('alert-warning')
            .removeClass('alert-danger')
            .addClass(footerClass)
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
    $('.examinr-exercise').each(initializeExerciseEditor)
    initializeEditorBindings()
  })

  return {
    highContrastTheme: function (enabled) {
      currentTheme = enabled ? kThemeMonochrome : kThemeDefault
      $('.examinr-exercise').each(function () {
        const editor = $(this).data('editor')
        if (editor) {
          editor.setTheme(currentTheme)
        }
      })
    }
  }
}())
