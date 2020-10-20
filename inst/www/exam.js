"use strict";

/*
 * Some parts of this file are dervied from the learnr project, which is licensed under the Apache 2.0 license.
 * Original work Copyright 2019 RStudio
 * Modified work Copyright 2020 David Kepplinger
 */
window.Exam = function () {
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

  function toggleRecomputeOverlay(el, show) {
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

  function exerciseRunning(outputContainer, running) {
    if (typeof running === 'undefined') {
      running = !exerciseRunButtonEnabled;
    }

    toggleRecomputeOverlay(outputContainer, running);
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
  } // Initialize the exam on document load


  $(document).ready(function () {
    initializeExerciseEditors();
    initializeEditorBindings();
  });
  return {
    toggleRecomputeOverlay: toggleRecomputeOverlay
  };
}();
//# sourceMappingURL=exam.js.map
