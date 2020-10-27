"use strict";

window.Exam = function () {
  'use strict';

  var exports = {};

  exports.shim = function () {
    'use strict';

    return {
      /**
       * Toggle a "working" shim over the given element.
       * @param {jQuery} el jquery element which should be covered by the shim.
       * @param {boolean} show force the shim to be shown/hidden, regardless of the current state.
       */
      toggle: function toggle(el, show) {
        if (!el) {
          // Overlay over entire document
          el = $('body');
        } else {
          el = $(el);
        }

        var spinOverlay = el.children('.examinr-recompute-overlay'); // If `show` is missing, show the overlay if it's not present at the moment

        if (typeof show === 'undefined') {
          show = spinOverlay.length === 0;
        }

        if (show === false) {
          spinOverlay.remove();
          el.removeClass('examinr-recompute-outer');
        } else {
          spinOverlay = $('<div class="examinr-recompute-overlay"><div class="examinr-recompute"></div></div>');
          el.prepend(spinOverlay);
          var op = spinOverlay.offsetParent();

          if (op.length > 0 && op.get(0) !== el.get(0)) {
            el.addClass('examinr-recompute-outer');
          }

          el.show();
        }
      }
    };
  }();
  /*
   * Some parts of this file are dervied from the learnr project, which is licensed under the Apache 2.0 license.
   * Original work Copyright 2019 RStudio
   * Derived work Copyright 2020 David Kepplinger
   */


  exports.exercises = function () {
    'use strict';

    var kMinLines = 5;
    var kMaxDefaultLines = 20;
    var exerciseRunButtonEnabled = true;

    function attachAceEditor(id, code) {
      var editor = ace.edit(id);
      editor.setHighlightActiveLine(false);
      editor.setShowPrintMargin(false);
      editor.setShowFoldWidgets(false);
      editor.setBehavioursEnabled(true);
      editor.renderer.setDisplayIndentGuides(false);
      editor.setTheme('ace/theme/textmate');
      editor.$blockScrolling = Infinity;
      editor.session.setMode('ace/mode/r');
      editor.session.getSelection().clearSelection();
      editor.setValue(code, -1);
      return editor;
    }

    function exerciseRunning(outputContainer, running) {
      if (typeof running === 'undefined') {
        running = !exerciseRunButtonEnabled;
      }

      exports.shim.toggle(outputContainer, running);
      exerciseRunButtonEnabled = running === false;
      $('.examinr-run-button').prop('disabled', !exerciseRunButtonEnabled);
    }

    function initializeExerciseEditors() {
      $('.examinr-exercise').each(function () {
        var exercise = $(this);
        var exerciseOptions = JSON.parse(exercise.children('script[type="application/json"]').detach().text() || '{}');
        var code = '';
        exercise.children('pre').each(function () {
          code += $(this).children('code').text() + '\n';
        }).remove();
        var codeLines = code.split(/\r?\n/).length;
        var lines = exerciseOptions.lines ? Math.max(1, exerciseOptions.lines) : Math.min(Math.max(kMinLines, codeLines), kMaxDefaultLines);

        if (codeLines < lines) {
          code += '\n'.repeat(lines - codeLines);
        }

        var editorId = exerciseOptions.input_id + '-editor';
        var pointsLabel = exerciseOptions.points ? '<span class="label ' + (exerciseOptions.label_class || '') + '">' + exerciseOptions.points + '</span>' : '';
        exercise.append('<div class="panel ' + (exerciseOptions.panel_class || '') + '">' + '<div class="panel-heading">' + '<button type="button" class="btn ' + (exerciseOptions.button_class || '') + ' btn-xs examinr-run-button pull-right"><span class="glyphicon glyphicon-play"></span>' + (exerciseOptions.button || '') + '</button>' + '<h5 class="panel-title">' + (exerciseOptions.title || '') + pointsLabel + '</h5>' + '</div>' + '<div class="panel-body">' + '<div id="' + editorId + '" class="examinr-exercise-editor"></div>' + '</div>' + '<div class="panel-footer">' + '<div class="small alert alert-warning examinr-exercise-status">' + (exerciseOptions.status_messages.notrun || '') + '</div>' + '</div>' + '</div><div class="examinr-exercise-output well"></div>');

        if (!exerciseOptions.status_messages.notrun) {
          exercise.find('.examinr-exercise-status').hide();
        }

        exercise.find('.examinr-exercise-output').hide();
        var runCodeButton = exercise.find('.examinr-run-button'); // Proxy a "run code" event through the button to also trigger shiny input events.

        var triggerClick = function triggerClick() {
          runCodeButton.click();
        };

        var editor = attachAceEditor(editorId, code);
        editor.setFontSize(0.8125 * parseFloat(exercise.find('.panel-body').css('font-size')));
        editor.commands.addCommand({
          name: 'run_rcode',
          bindKey: {
            win: 'Ctrl+Enter',
            mac: 'Command+Enter'
          },
          exec: triggerClick
        });
        editor.commands.addCommand({
          name: 'run_rcode-shift',
          bindKey: {
            win: 'Ctrl+Shift+Enter',
            mac: 'Command+Shift+Enter'
          },
          exec: triggerClick
        });

        var updateAceHeight = function updateAceHeight() {
          editor.setOptions({
            minLines: lines,
            maxLines: lines
          });
        };

        updateAceHeight();
        editor.getSession().on('change', updateAceHeight);
        runCodeButton.click(function () {
          editor.focus();
        });
        exercise.data({
          editor: editor,
          options: exerciseOptions
        });
        exercise.parents('section').on('shown', function () {
          editor.resize(true);
        });
      });
    }

    function initializeEditorBindings() {
      var inputBindings = new Shiny.InputBinding();
      $.extend(inputBindings, {
        find: function find(scope) {
          return $(scope).find('.examinr-exercise');
        },
        getId: function getId(exercise) {
          return $(exercise).data('options').input_id;
        },
        subscribe: function subscribe(exercise, callback) {
          exercise = $(exercise);
          exercise.find('.examinr-run-button').on('click.examinrExerciseInputBinding', function () {
            if (exerciseRunButtonEnabled) {
              exercise.data('sendData', true);
              exerciseRunning(exercise.find('.examinr-exercise-output'), true);
              callback(true);
            }
          });
        },
        unsubscribe: function unsubscribe(exercise) {
          $(exercise).find('.examinr-run-button').off('.examinrExerciseInputBinding');
        },
        getValue: function getValue(exercise) {
          exercise = $(exercise);

          if (exercise.data('sendData') !== true) {
            return null;
          }

          exercise.data('sendData', false);
          return {
            label: exercise.data('options').label,
            output_id: exercise.data('options').output_id,
            code: exercise.data('editor').getSession().getValue(),
            timestamp: new Date().getTime()
          };
        },
        setValue: function setValue(exercise, value) {
          $(exercise).data('editor').getSession().setValue(value);
        }
      });
      Shiny.inputBindings.register(inputBindings, 'examinr.exerciseInputBinding');
      var outputBindings = new Shiny.OutputBinding();
      $.extend(outputBindings, {
        find: function find(scope) {
          return $(scope).find('.examinr-exercise');
        },
        getId: function getId(exercise) {
          return $(exercise).data('options').output_id;
        },
        renderValue: function renderValue(exercise, data) {
          exercise = $(exercise);

          if (data.result) {
            exercise.find('.examinr-exercise-output').show().html(data.result);
          } else {
            exercise.find('.examinr-exercise-output').hide().html('');
          }

          if (data.status) {
            exercise.find('.examinr-exercise-status').removeClass('alert-success').removeClass('alert-info').removeClass('alert-warning').removeClass('alert-danger').addClass('alert-' + (data.status_class || 'info'));
            exercise.find('.examinr-exercise-status').show().html(data.status);
          } else {
            exercise.find('.examinr-exercise-status').hide().html('');
          }

          exerciseRunning(exercise.find('.examinr-exercise-output'), false);
        },
        renderError: function renderError(exercise, error) {
          exercise = $(exercise);
          exerciseRunning(exercise.find('.examinr-exercise-output'), false);
          exercise.find('.examinr-exercise-output').hide();
          exercise.find('.examinr-exercise-status').show().text(error.message);
        },
        clearError: function clearError(exercise) {
          exercise = $(exercise);
          exerciseRunning(exercise.find('.examinr-exercise-output'), false);
          exercise.find('.examinr-exercise-output').hide();
          exercise.find('.examinr-exercise-status').hide();
        }
      });
      Shiny.outputBindings.register(outputBindings, 'examinr.exerciseOutputBinding');
    }

    $(document).ready(function () {
      initializeExerciseEditors();
      initializeEditorBindings();
    });
    return {};
  }();
  /*
   * Some parts of this file are dervied from the learnr project, which is licensed under the Apache 2.0 license.
   * Original work Copyright 2019 RStudio
   * Derived work Copyright 2020 David Kepplinger
   */


  exports.autocomplete = function () {
    'use strict';

    var kModifierKeyNone = 0;
    var kModifierKeyCtrl = 1;
    var kModifierKeyAlt = 2;
    var kModifierKeyShift = 4;
    var kModifierKeyMeta = 8;
    var kKeycodeTab = 9;
    var kKeycodeSpace = 32;
    var autocompleteTimerId;

    var aceAutocompleteCallback = function aceAutocompleteCallback() {};

    function modifierCombination(event) {
      return kModifierKeyNone | (event.ctrlKey ? kModifierKeyCtrl : 0) | (event.altKey ? kModifierKeyAlt : 0) | (event.metaKey ? kModifierKeyMeta : 0) | (event.shiftKey ? kModifierKeyShift : 0);
    }

    var customRCompleter = {
      insertMatch: function insertMatch(editor, data) {
        // remove prefix
        var ranges = editor.selection.getAllRanges();
        var filterLength = editor.completer.completions.filterText.length;

        for (var i = 0; i < ranges.length; i++) {
          ranges[i].start.column -= filterLength;
          editor.session.remove(ranges[i]);
        } // insert completion term (add parentheses for functions)


        editor.execCommand('insertstring', data.caption); // move cursor backwards for functions

        if (data.is_function) {
          editor.navigateLeft(1);
        }
      }
    }; // this message handler is called when new autocomplete results are available.

    Shiny.addCustomMessageHandler('__.examinr.__-autocomplete', function (suggestions) {
      var completions = suggestions.map(function (item) {
        // Items are an array of the form [namespace (str), symbol (str), is_function (bool)]
        if (!item || !item[1]) {
          return null;
        }

        return {
          caption: item[1] + (item[2] ? '()' : ''),
          value: item[1],
          score: 0,
          meta: item[0] ? '{' + item[0] + '}' : '',
          is_function: item[2],
          completer: customRCompleter
        };
      }).filter(function (x) {
        return x;
      });
      aceAutocompleteCallback(null, completions);
    });

    function isPopupOpen(editor) {
      return editor.completer && editor.completer.popup && editor.completer.popup.isOpen;
    }

    function getCompletions(editor, session, position, _, callback) {
      // send autocompletion request with all the code up to cursor position
      // (done to enable multi-line autocompletions)
      var code = session.getTextRange({
        start: {
          row: 0,
          column: 0
        },
        end: position
      }); // If the popup is not open, force a Shiny input event, otherwise only if the code changed.

      var priority = isPopupOpen(editor) ? 'value' : 'event'; // this will be called when the Shiny message is received

      aceAutocompleteCallback = callback; // update the input value for the autocomplete input

      Shiny.setInputValue('__.examinr.__-autocomplete', {
        code: code,
        label: editor.exerciseLabel
      }, {
        priority: priority
      });
    } // Initialize autocomplete for the exercise.
    // Return false if the exercise does not need autocomplete, true otherwise.


    function initializeExerciseAutocomplete() {
      var exercise = $(this);

      if (exercise.data('options').autocomplete !== true) {
        return;
      } // Initialize the editor for autocomplete


      var editor = exercise.data('editor');
      var exerciseOptions = exercise.data('options');

      var startAutocomplete = function startAutocomplete() {
        editor.execCommand('startAutocomplete');
      };

      var onChangeCallback = function onChangeCallback(data) {
        // use only a single autocompleter at a time!
        clearTimeout(autocompleteTimerId);
        data = data || {};

        if (data.action !== 'insert' || !data.lines || !data.lines.length || data.lines.length > 1) {
          return;
        } // NOTE: Ace has already updated the document line at this point
        // so we can just look at the state of that line


        var pos = editor.getCursorPosition();
        var line = editor.session.getLine(pos.row); // NOTE: we allow new autocompletion sessions following a
        // ':' insertion just to enable cases where the user is
        // typing e.g. 'stats::rnorm()' while the popup is visible

        if (isPopupOpen(editor) && !/::$/.test(line)) {
          return;
        } // figure out appropriate delay -- want to autocomplete
        // immediately after a '$' or '@' insertion, but need to
        // execute on timeout to allow Ace to finish processing
        // events (if any)


        var delayMs = /[$@]$|::$/.test(line) ? 10 : 300;
        autocompleteTimerId = setTimeout(startAutocomplete, delayMs);
      };

      editor.on('change', onChangeCallback);
      editor.on('destroy', function () {
        editor.off(onChangeCallback);
      });
      editor.exerciseLabel = exerciseOptions.label;
      editor.completers = editor.completers || [];
      editor.completers.push({
        getCompletions: getCompletions
      });
      editor.setOptions({
        enableBasicAutocompletion: true,
        enableLiveAutocompletion: false
      });
      editor.keyBinding.addKeyboardHandler({
        handleKeyboard: autocompleteKeyboardHandler
      });
    }

    function autocompleteKeyboardHandler(data, hash, keyString, keyCode, event) {
      if (hash !== -1 && data.editor) {
        var modifierCombo = modifierCombination(event);

        if (keyCode === kKeycodeSpace && modifierCombo === kModifierKeyCtrl || keyCode === kKeycodeTab && modifierCombo === kModifierKeyNone && (!data.editor.completer || !data.editor.completer.activated)) {
          // cancel any pending autocomplete
          clearTimeout(autocompleteTimerId);

          if (isPopupOpen(data.editor)) {
            data.editor.completer.popup.hide();
            return {
              command: 'null'
            };
          } else {
            return {
              command: 'startAutocomplete'
            };
          }
        }
      }
    }

    function initializeAutocomplete() {
      $('.examinr-exercise').each(initializeExerciseAutocomplete);
    }

    $(document).ready(function () {
      initializeAutocomplete();
    });
    return {};
  }();

  exports.sections = function () {
    'use strict';

    var recalculatedDelay = 250;
    var sectionsOptions = {};
    var currentSectionEl;
    var currentSection = {};

    function finishedRecalculating() {
      exports.shim.toggle($('body'), false);
    }

    Shiny.addCustomMessageHandler('__.examinr.__-sectionChange', function (section) {
      if (section.current) {
        if (currentSectionEl) {
          currentSectionEl.hide();
        }

        currentSection = section.current;
        currentSectionEl = $('#' + currentSection.ui_id).parent().show().trigger('shown');
        var outputElements = currentSectionEl.find('.shiny-bound-output');
        var recalculating = outputElements.length;

        if (recalculating > 0) {
          // Assume that all outputs need to be recalculated.
          // If not, call finishedRecalculating() after a set delay.
          var recalculatingTimerId = window.setTimeout(finishedRecalculating, recalculatedDelay);
          outputElements.one('shiny:recalculated', function () {
            --recalculating;

            if (recalculating <= 0) {
              // All outputs have been recalculated.
              finishedRecalculating();
            } else {
              // Some outputs are still to be recalculated. Wait for them a short while, otherwise call
              // finishedRecalculating()
              window.clearTimeout(recalculatingTimerId);
              recalculatingTimerId = window.setTimeout(finishedRecalculating, recalculatedDelay);
            }
          });
        } else {
          finishedRecalculating();
        }
      }
    });

    function initializeSectionedExam() {
      var sectionsOptionsEl = $('#examinr-sections-options');

      if (sectionsOptionsEl.length > 0) {
        sectionsOptions = JSON.parse(sectionsOptionsEl.text());
        sectionsOptionsEl.remove();
      }

      if (!sectionsOptions.progressive) {
        // All-at-once exam. Show the "next button" only for the last section.
        $('.examinr-section-next').hide();
        $('section.level1').last().find('.examinr-section-next').show();
      } else {
        // progressive exams
        $('section.level1').hide();
        exports.shim.toggle($('body'), true);
        $('.examinr-section-next').click(function () {
          exports.shim.toggle($('body'), true);
        });
      }
    }

    $(document).ready(function () {
      initializeSectionedExam();
    });
  }();

  return exports;
}();
//# sourceMappingURL=exam.js.map
