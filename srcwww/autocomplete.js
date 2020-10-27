/*
 * Some parts of this file are dervied from the learnr project, which is licensed under the Apache 2.0 license.
 * Original work Copyright 2019 RStudio
 * Derived work Copyright 2020 David Kepplinger
 */
exports.autocomplete = (function () {
  'use strict'

  const kModifierKeyNone = 0
  const kModifierKeyCtrl = 1
  const kModifierKeyAlt = 2
  const kModifierKeyShift = 4
  const kModifierKeyMeta = 8
  const kKeycodeTab = 9
  const kKeycodeSpace = 32
  var autocompleteTimerId
  var aceAutocompleteCallback = function () {}

  function modifierCombination (event) {
    return kModifierKeyNone |
        (event.ctrlKey ? kModifierKeyCtrl : 0) |
        (event.altKey ? kModifierKeyAlt : 0) |
        (event.metaKey ? kModifierKeyMeta : 0) |
        (event.shiftKey ? kModifierKeyShift : 0)
  }

  const customRCompleter = {
    insertMatch: function (editor, data) {
      // remove prefix
      const ranges = editor.selection.getAllRanges()
      const filterLength = editor.completer.completions.filterText.length
      for (var i = 0; i < ranges.length; i++) {
        ranges[i].start.column -= filterLength
        editor.session.remove(ranges[i])
      }

      // insert completion term (add parentheses for functions)
      editor.execCommand('insertstring', data.caption)

      // move cursor backwards for functions
      if (data.is_function) {
        editor.navigateLeft(1)
      }
    }
  }

  // this message handler is called when new autocomplete results are available.
  Shiny.addCustomMessageHandler('__.examinr.__-autocomplete', function (suggestions) {
    const completions = suggestions.map(function (item) {
      // Items are an array of the form [namespace (str), symbol (str), is_function (bool)]
      if (!item || !item[1]) {
        return null
      }
      return {
        caption: item[1] + (item[2] ? '()' : ''),
        value: item[1],
        score: 0,
        meta: item[0] ? ('{' + item[0] + '}') : '',
        is_function: item[2],
        completer: customRCompleter
      }
    }).filter(x => x)
    aceAutocompleteCallback(null, completions)
  })

  function isPopupOpen (editor) {
    return editor.completer && editor.completer.popup && editor.completer.popup.isOpen
  }

  function getCompletions (editor, session, position, _, callback) {
    // send autocompletion request with all the code up to cursor position
    // (done to enable multi-line autocompletions)
    const code = session.getTextRange({
      start: { row: 0, column: 0 },
      end: position
    })

    // If the popup is not open, force a Shiny input event, otherwise only if the code changed.
    const priority = isPopupOpen(editor) ? 'value' : 'event'

    // this will be called when the Shiny message is received
    aceAutocompleteCallback = callback
    // update the input value for the autocomplete input
    Shiny.setInputValue('__.examinr.__-autocomplete', {
      code: code,
      label: editor.exerciseLabel
    }, { priority: priority })
  }

  // Initialize autocomplete for the exercise.
  // Return false if the exercise does not need autocomplete, true otherwise.
  function initializeExerciseAutocomplete () {
    const exercise = $(this)
    if (exercise.data('options').autocomplete !== true) {
      return
    }

    // Initialize the editor for autocomplete

    const editor = exercise.data('editor')
    const exerciseOptions = exercise.data('options')

    const startAutocomplete = function () {
      editor.execCommand('startAutocomplete')
    }

    const onChangeCallback = function (data) {
      // use only a single autocompleter at a time!
      clearTimeout(autocompleteTimerId)

      data = data || {}
      if (data.action !== 'insert' || !data.lines || !data.lines.length || data.lines.length > 1) {
        return
      }
      // NOTE: Ace has already updated the document line at this point
      // so we can just look at the state of that line
      const pos = editor.getCursorPosition()
      const line = editor.session.getLine(pos.row)

      // NOTE: we allow new autocompletion sessions following a
      // ':' insertion just to enable cases where the user is
      // typing e.g. 'stats::rnorm()' while the popup is visible
      if (isPopupOpen(editor) && !/::$/.test(line)) {
        return
      }

      // figure out appropriate delay -- want to autocomplete
      // immediately after a '$' or '@' insertion, but need to
      // execute on timeout to allow Ace to finish processing
      // events (if any)
      const delayMs = /[$@]$|::$/.test(line) ? 10 : 300
      autocompleteTimerId = setTimeout(startAutocomplete, delayMs)
    }

    editor.on('change', onChangeCallback)
    editor.on('destroy', function () {
      editor.off(onChangeCallback)
    })

    editor.exerciseLabel = exerciseOptions.label

    editor.completers = editor.completers || []
    editor.completers.push({ getCompletions: getCompletions })
    editor.setOptions({
      enableBasicAutocompletion: true,
      enableLiveAutocompletion: false
    })
    editor.keyBinding.addKeyboardHandler({ handleKeyboard: autocompleteKeyboardHandler })
  }

  function autocompleteKeyboardHandler (data, hash, keyString, keyCode, event) {
    if (hash !== -1 && data.editor) {
      const modifierCombo = modifierCombination(event)
      if ((keyCode === kKeycodeSpace && modifierCombo === kModifierKeyCtrl) ||
          (keyCode === kKeycodeTab && modifierCombo === kModifierKeyNone &&
            (!data.editor.completer || !data.editor.completer.activated))) {
        // cancel any pending autocomplete
        clearTimeout(autocompleteTimerId)
        if (isPopupOpen(data.editor)) {
          data.editor.completer.popup.hide()
          return { command: 'null' }
        } else {
          return { command: 'startAutocomplete' }
        }
      }
    }
  }

  function initializeAutocomplete () {
    $('.examinr-exercise').each(initializeExerciseAutocomplete)
  }

  $(document).ready(function () {
    initializeAutocomplete()
  })

  return {}
}())
