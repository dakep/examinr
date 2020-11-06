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

  exports.status = function () {
    'use strict';

    var messages = {};
    var config = {};
    var timelimitTimer;
    var timelimit = Number.POSITIVE_INFINITY;
    var statusContainer;
    var dialogContainerTitle = $('<h4 class="modal-title" id="examinr-status-dialog-title-' + Math.random().toString(36).slice(2) + '">');
    var dialogContainerContent = $('<div class="modal-body" id="examinr-status-dialog-body-' + Math.random().toString(36).slice(2) + '">');
    var dialogContainerFooter = $('<div class="modal-footer">' + '<button type="button" class="btn btn-primary" data-dismiss="modal">Close</button>' + '</div>');
    var dialogContainer = $('<div class="modal" tabindex="-1" role="alertdialog" ' + 'aria-labelledby="' + dialogContainerTitle.attr('id') + '"' + 'aria-describedby="' + dialogContainerContent.attr('id') + '">' + '<div class="modal-dialog modal-lg" role="document">' + '<div class="modal-content"><div class="modal-header"></div></div>' + '</div>' + '</div>');
    var progressEl = $('<div class="alert alert-info examinr-progress" role="status"></div>');
    var statusMessageEl = $('<div class="alert alert-info lead examinr-status-message" role="alert"></div>');
    dialogContainer.find('.modal-header').append(dialogContainerTitle);
    dialogContainer.find('.modal-content').append(dialogContainerContent).append(dialogContainerFooter);
    /**
     * Show a status message.
     * @param {object} condition the condition object to show. Must contain the following elements:
     *  type {string} one of "error", "locked", "warning", or "info"
     *  message {string} the status message, may contain HTML
     *  title {string} (for type "error" or "locked") the title for the error dialog
     *  button {string} (for type "error") the button label for the error dialog
     *  action {string} (for type "error") the action associated with the button. If "reload", the page is reloaded,
     *    otherwise, the dialog is simply closed.
     */

    Shiny.addCustomMessageHandler('__.examinr.__-statusMessage', function (condition) {
      statusMessageEl.detach();

      if (condition.type === 'error') {
        showErrorDialog(condition.content.title, condition.content.body, condition.action, condition.content.button, condition.triggerId, condition.triggerEvent, condition.triggerDelay);
      } else if (condition.type === 'locked') {
        showErrorDialog(condition.content.title, condition.content.body, 'none', '');
        $('.main-container').hide();
      } else {
        var alertContext = condition.type === 'warning' ? 'alert-warning' : 'alert-info';
        statusMessageEl.removeClass('alert-warning alert-info').addClass(alertContext);
        statusMessageEl.html(condition.content.body).find('.examinr-timestamp').each(parseTimestamp);
      }

      fixMainOffset();
    });
    /** Update the current attempt information.
     *
     * @param {object} attempt an object with the following properties:
     *   - {boolean} active whether there is an active attempt.
     *   - {integer} timelimit the timestamp (in seconds) when the current attempt is closed.
     */

    Shiny.addCustomMessageHandler('__.examinr.__-attemptStatus', function (attempt) {
      if (attempt.gracePeriod) {
        config.gracePeriod = attempt.gracePeriod;
      }

      if (attempt && attempt.active) {
        $('.main-container').show().trigger('shown');
        progressEl.show();

        if (attempt.timelimit !== 0 && (!attempt.timelimit || attempt.timelimit === 'Inf')) {
          attempt.timelimit = Number.POSITIVE_INFINITY;
        }

        try {
          timelimit = new Date(attempt.timelimit * 1000);

          if (timelimitTimer) {
            window.clearTimeout(timelimitTimer);
            timelimitTimer = false;
          }

          updateTimeLeft();
        } catch (e) {
          window.console.warn('Cannot set timelimit for current attempt:', e);
          timelimit = Number.POSITIVE_INFINITY;
        }
      } else {
        $('.main-container').hide();
        progressEl.hide();
      }
    });
    /**
     * Fix the top offset of the main content to make room for the status container.
     */

    function fixMainOffset() {
      if (statusContainer && statusContainer.length > 0) {
        $('body').css('paddingTop', statusContainer.height());
      }
    }
    /**
     * Parse the content inside the element as timestamp and replace with the browser's locale date-time string.
     */


    function parseTimestamp() {
      var el = $(this);
      var timestamp = parseInt(el.text());

      if (timestamp && !isNaN(timestamp)) {
        el.text(new Date(timestamp * 1000).toLocaleString());
      } else {
        el.text('');
      }
    }
    /**
     * Show a modal error dialog.
     * @param {string} title title of the dialog, may contain HTML
     * @param {string} content content of the dialog, may contain HTML
     * @param {string} action what action should be taken when the button is clicked. If "reload", the browser is
     *   instructed to reload the page. If "none", the dialog cannot be closed. In all other cases,
     *   clicking the button will close the dialog.
     * @param {string} button label for the button, may not contain HTML
     */


    function showErrorDialog(title, content, action, button, triggerId, triggerEvent, triggerDelay) {
      var closeBtn = dialogContainerFooter.children('button');
      dialogContainerTitle.html(title).find('.examinr-timestamp').each(parseTimestamp);
      dialogContainerContent.html(content).find('.examinr-timestamp').each(parseTimestamp);

      if (action === 'none') {
        dialogContainerFooter.hide();
      } else {
        closeBtn.text(button);

        if (action === 'reload') {
          closeBtn.one('click', function () {
            window.location.reload();
          });
        } else if (action === 'trigger' && triggerId && triggerEvent) {
          closeBtn.one('click', function () {
            if (triggerDelay) {
              exports.shim.toggle($('body'), true);
              window.setTimeout(function () {
                return $('#' + triggerId).trigger(triggerEvent);
              }, triggerDelay);
            } else {
              $('#' + triggerId).trigger(triggerEvent);
            }
          });
        }
      }

      exports.shim.toggle($('body'), false);
      dialogContainer.attr('role', action === 'none' ? 'dialog' : 'errordialog').appendTo(document.body).one('hidden.bs.modal', function () {
        dialogContainer.detach();
      }).modal({
        keyboard: false,
        backdrop: 'static',
        show: true
      });
    }

    function toBase10(val) {
      return val >= 10 ? val.toString(10) : '0' + val.toString(10);
    }
    /**
     * Update the "time left" status.
     */


    function updateTimeLeft() {
      var msLeft = timelimit === Number.POSITIVE_INFINITY ? Number.POSITIVE_INFINITY : timelimit - new Date();
      var timerEl = progressEl.find('.examinr-timer');

      if (!isNaN(msLeft) && msLeft < Number.POSITIVE_INFINITY) {
        if (msLeft < 1 && msLeft > -1000 * (config.gracePeriod || 1)) {
          msLeft = 0;
        }

        if (msLeft >= 0) {
          var hrsLeft = Math.floor(msLeft / 3600000);
          var minLeft = Math.floor(msLeft % 3600000 / 60000);
          var secLeft = Math.floor(msLeft % 60000 / 1000);

          if (hrsLeft > 0) {
            timerEl.children('.hrs').removeClass('ignore').text(toBase10(hrsLeft));
          } else {
            timerEl.children('.hrs').addClass('ignore').text('00');
          }

          timerEl.children('.min').text(toBase10(minLeft));

          if (hrsLeft > 0 || minLeft >= 10) {
            timerEl.children('.min').addClass('nosec');
            timerEl.children('.sec').hide();
          } else {
            timerEl.children('.min').removeClass('nosec');
            timerEl.children('.sec').show().text(toBase10(secLeft));
          }

          timerEl.show();

          if (hrsLeft > 0 || minLeft >= 12) {
            timelimitTimer = window.setTimeout(updateTimeLeft, 60000); // call every minute
          } else {
            if (progressEl.hasClass('alert')) {
              if (minLeft < 5) {
                progressEl.removeClass('alert-warning').addClass('alert-danger');
              } else if (minLeft < 10) {
                progressEl.removeClass('alert-info').addClass('alert-warning');
              }
            }

            timelimitTimer = window.setTimeout(updateTimeLeft, 1000); // call every second
          }
        } else {
          // Time is up. Destroy the interface.
          $('.main-container').remove();
          showErrorDialog(messages.attemptTimeout.title, messages.attemptTimeout.body, 'none');
        }
      } else {
        timerEl.hide();
      }
    }

    $(function () {
      exports.shim.toggle($('body'), true);
      statusContainer = $('.examinr-exam-status');

      if (statusContainer.length > 0) {
        statusContainer.prependTo(document.body);
        config = JSON.parse(statusContainer.children('script.status-config').remove().text() || '{}');
        messages = JSON.parse(statusContainer.children('script.status-messages').remove().text() || '{}');

        if (messages.progress) {
          // replace the following format strings:
          // - "{section_nr}" with an element holding the current section number
          // - "{total_sections}" with an element holding the total number of sections
          // - "{time_left}" with an element holding the time left
          var sectionProgress = messages.progress.section.replace('{section_nr}', '<span class="examinr-section-nr">1</span>').replace('{total_sections}', '<span class="examinr-total-sections">' + (config.totalSections || 1) + '</span>');
          var timerHtml = messages.progress.timer.replace('{time_left}', '<span class="examinr-timer" role="timer">' + '<span class="hrs">??</span>' + '<span class="min">??</span>' + '<span class="sec"></span>' + '</span>');

          if (config.progressive && config.haveTimelimit) {
            progressEl.html(messages.progress.combined.replace('{section}', sectionProgress).replace('{timer}', timerHtml));
          } else if (config.progressive) {
            progressEl.html(sectionProgress);
          } else if (config.haveTimelimit) {
            progressEl.html(timerHtml);
          }

          statusContainer.append(progressEl);
          updateTimeLeft();
        }
      }

      if (config.progressbar) {
        var progressbarEl = $('<div class="progress">' + '<div class="progress-bar" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="' + config.totalSections + '" style="min-width: 2em;">' + '</div>' + '</div>');
        statusContainer.addClass('examinr-with-progressbar').append(progressbarEl);
      }

      fixMainOffset();
    });
    return {
      /**
       * Reset (i.e., hide) the status messages
       */
      resetMessages: function resetMessages() {
        statusMessageEl.detach();
        dialogContainer.detach();
        fixMainOffset();
      },

      /**
       * Get the message associated with an identifier.
       * @param {string} what the message identifier
       * @returns the message for the given identifier, or null if the identifier is unknown.
       */
      getMessage: function getMessage(what) {
        return messages[what] || null;
      },

      /**
       * Update the current section number.
       * @param {int} currentSectionNr the current section number
       */
      updateProgress: function updateProgress(currentSectionNr) {
        if (!currentSectionNr || isNaN(currentSectionNr) || currentSectionNr < 0 || currentSectionNr > config.totalSections) {
          currentSectionNr = config.totalSections;
        }

        progressEl.show().find('.examinr-section-nr').text(currentSectionNr);

        if (config.progressbar) {
          progressEl.find('.progress-bar').attr('aria-valuenow', currentSectionNr).width(Math.round(100 * currentSectionNr / config.totalSections) + '%');
        }

        fixMainOffset();
      }
    };
  }();

  exports.questions = function () {
    'use strict';

    var arrowKeyUp = 38;
    var arrowKeyDown = 40;

    function preventDefault(e) {
      e.preventDefault();
    }

    function disableScrollOnNumberInput() {
      var numberInputs = $('input[type=number]');
      numberInputs.on('focus', function () {
        $(this).on('wheel.disableScrollEvent', preventDefault).on('keydown.disableScrollEvent', function (e) {
          if (e.which === arrowKeyDown || e.which === arrowKeyUp) {
            e.preventDefault();
          }
        });
      }).on('blur', function () {
        $(this).off('.disableScrollEvent');
      });
    }

    $(function () {
      disableScrollOnNumberInput();
    });
    return {};
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

        var editorId = exerciseOptions.inputId + '-editor';
        var pointsLabel = exerciseOptions.points ? '<span class="label ' + (exerciseOptions.labelClass || '') + '">' + exerciseOptions.points + '</span>' : '';
        var messageStrings = exports.status.getMessage('exercise') || {};
        exercise.append('<div class="panel ' + (exerciseOptions.panelClass || '') + '">' + '<div class="panel-heading">' + '<button type="button" class="btn ' + (exerciseOptions.buttonClass || '') + ' btn-xs examinr-run-button pull-right">' + '<span class="glyphicon glyphicon-play"></span>' + exerciseOptions.buttonLabel + '</button>' + '<h5 class="panel-title">' + (exerciseOptions.title || '') + pointsLabel + '</h5>' + '</div>' + '<div class="panel-body">' + '<div id="' + editorId + '" class="examinr-exercise-editor"></div>' + '</div>' + '<div class="panel-footer">' + '<div class="small alert alert-warning examinr-exercise-status">' + messageStrings.notYetRun + '</div>' + '</div>' + '</div><div class="examinr-exercise-output well"></div>');

        if (!messageStrings.notYetRun) {
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
          return $(exercise).data('options').inputId;
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
          return $(exercise).data('options').outputId;
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

    $(function () {
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
        // Items are an array of the form [namespace (str), symbol (str), isFunction (bool)]
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

    $(function () {
      $('.examinr-exercise').each(initializeExerciseAutocomplete);
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

        exports.status.resetMessages();

        if (section.current.order) {
          exports.status.updateProgress(section.current.order);
        }
      }
    });
    $(function () {
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
        $('.examinr-section-next').click(function () {
          exports.shim.toggle($('body'), true);
        });
      }
    });
    return {};
  }();

  return {};
}();
//# sourceMappingURL=exam.js.map
