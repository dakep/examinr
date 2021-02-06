"use strict";

function _typeof(obj) { "@babel/helpers - typeof"; if (typeof Symbol === "function" && typeof Symbol.iterator === "symbol") { _typeof = function _typeof(obj) { return typeof obj; }; } else { _typeof = function _typeof(obj) { return obj && typeof Symbol === "function" && obj.constructor === Symbol && obj !== Symbol.prototype ? "symbol" : typeof obj; }; } return _typeof(obj); }

if (typeof exports === 'undefined') {
  window.exports = window.Exam = {};
}

;

exports.utils = function () {
  'use strict';

  var arrowKeyUp = 38;
  var arrowKeyDown = 40;
  var lang = $('html').attr('lang') || 'en-US';

  function preventDefault(e) {
    e.preventDefault();
  }

  function generateRandomId(prefix) {
    if (!prefix) {
      prefix = 'anonymous-el-';
    }

    return prefix + Math.random().toString(36).slice(2);
  }

  function initNumericInputs() {
    var numRegexp = /^-?(\d*\.)?\d+$/;
    $('.examinr-q-numeric input[type=text]').each(function () {
      var input = $(this);
      var feedbackId = exports.utils.randomId();
      input.change(function () {
        var newVal = input.val();
        $('#' + feedbackId).remove();

        if (newVal && !numRegexp.test(newVal)) {
          input.attr('aria-describedby', feedbackId).addClass('is-invalid').after('<span id="' + feedbackId + '" class="sr-only">invalid value</span>');
        } else {
          if (newVal.length > 0) {
            input.val(parseFloat(newVal));
          }

          input.removeAttr('aria-describedby').removeClass('is-invalid');
        }
      });
    });
  }

  $(function () {
    initNumericInputs();
  });
  return {
    /**
     * A storage for objects bound to the current attempt.
     */
    attemptStorage: {
      /**
       * Get the item associated with the given key.
       *
       * @param {DOMString} key identifier for the object.
       * @return object associated with the given key.
       */
      getItem: function getItem(key) {
        return JSON.parse(window.localStorage.getItem('examinr_' + key));
      },

      /**
       * Store an item in the storage.
       *
       * @param {DOMString} key identifier for the object.
       * @param {*} value JSON-serializable object to be associated with the key.
       */
      setItem: function setItem(key, value) {
        return window.localStorage.setItem('examinr_' + key, JSON.stringify(value));
      },

      /**
       * Delete an item from storage.
       *
       * @param {DOMString} key identifier for the object.
       */
      removeItem: function removeItem(key) {
        return window.localStorage.removeItem('examinr_' + key);
      },

      /*
       * Delete all items from storage.
       */
      clear: function clear() {
        for (var i = window.localStorage.length - 1; i >= 0; --i) {
          var key = window.localStorage.key(i);

          if (key && key.startsWith('examinr_')) {
            window.localStorage.removeItem(key);
          }
        }
      },

      /**
       * Iterate over all keys in storage.
       * @param {Function} callback function being called for each key in the store given as first argument.
       */
      keys: function keys(callback) {
        for (var i = window.localStorage.length - 1; i >= 0; --i) {
          var key = window.localStorage.key(i);

          if (key && key.startsWith('examinr_')) {
            callback(key.substring(8));
          }
        }
      }
    },

    /**
     * Format the given date in the document's language
     * @param {int} timestamp the timestamp to format
     */
    formatDate: function formatDate(timestamp) {
      return new Date(timestamp).toLocaleString(lang);
    },

    /**
     * Create a function which calls the given function repeatedly until it returns `true`.
     *
     * @param {function} func function to call repeatedly until it returns true.
     * @param {integer} delay delay in ms
     */
    autoRetry: function autoRetry(func, delay, immediately) {
      return function () {
        var context = this;
        var args = arguments;
        var requireRetry = !immediately || func.apply(context, args) !== true;

        if (requireRetry) {
          var timerId = window.setInterval(function () {
            if (func.apply(context, args) === true) {
              window.clearInterval(timerId);
            }
          }, delay);
        }
      };
    },

    /**
     * Disable stepping by arrow keys and scrolling on number inputs.
     *
     * @param {jQuery} numberInputs the inputs to disable the defaults for.
     */
    disableNumberInputDefaults: function disableNumberInputDefaults(numberInputs) {
      if (!numberInputs) {
        numberInputs = $('input[type=number]');
      }

      numberInputs.on('focus', function () {
        $(this).on('wheel.disableScrollEvent', preventDefault).on('keydown.disableScrollEvent', function (e) {
          if (e.which === arrowKeyDown || e.which === arrowKeyUp) {
            e.preventDefault();
          }
        });
      }).on('blur', function () {
        $(this).off('.disableScrollEvent');
      });
    },

    /**
     * Debounce the given function, calling it only once for a series of shortly spaced calls.
     * @param {function} fun function to debounce
     * @param {integer} wait time (in ms) to wait before calling `fun`
     * @param {boolean} immediate if `fun` should be called immediately on the raising edge, not the falling edge.
     */
    debounce: function debounce(fun, wait, immediate) {
      var timerId = null;
      return function () {
        var context = this;
        var args = arguments;

        var delayed = function delayed() {
          timerId = null;

          if (!immediate) {
            fun.apply(context, args);
          }
        };

        var callImmediately = immediate && !timerId;
        window.clearTimeout(timerId);
        timerId = window.setTimeout(delayed, wait);

        if (callImmediately) {
          fun.apply(context, args);
        }
      };
    },
    randomId: generateRandomId,

    /**
     * Render any math in the element with the given id
     *
     * @param {string} id id of the element to render math.
     * @param {boolean} isDummy if true, the id attribute is removed.
     */
    triggerMathJax: function triggerMathJax(id, isDummy) {
      if (window.MathJax && window.MathJax.startup && window.MathJax.startup.promise) {
        window.MathJax.startup.promise = window.MathJax.startup.promise.then(function () {
          var el = $('#' + id);

          if (isDummy) {
            var parent = el.parent();

            if (parent.length > 0) {
              parent.append(el.remove().html());
              el = parent;
            }
          }

          return window.MathJax.typesetPromise(el);
        })["catch"](function (err) {
          return window.console.warn('Cannot typeset math: ', err.message);
        });
        return window.MathJax.startup.promise;
      }
    },

    /**
     * Render any math in the element with the given id
     *
     * @param {jQuery} el element to render math in
     */
    renderMathJax: function renderMathJax(el) {
      if (window.MathJax && window.MathJax.startup && window.MathJax.startup.promise) {
        window.MathJax.startup.promise = window.MathJax.startup.promise.then(function () {
          return window.MathJax.typesetPromise(el);
        })["catch"](function (err) {
          return window.console.warn('Cannot typeset math: ', err.message);
        });
        return window.MathJax.startup.promise;
      }
    },

    /**
     * Toggle a "working" shim over the given element.
     * @param {jQuery} el jquery element which should be covered by the shim.
     * @param {boolean} show force the shim to be shown/hidden, regardless of the current state.
     */
    toggleShim: function toggleShim(el, show) {
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
        spinOverlay = $('<div class="examinr-recompute-overlay"><div class="examinr-recompute" role="status">' + '<span class="sr-only">Loading...</span>' + '</div></div>');
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

exports.accessibility = function () {
  'use strict';

  function getOrMakeId(el) {
    if (el.attr('id')) {
      return el.attr('id');
    }

    var newId = exports.utils.randomId('aria-el-');
    el.attr('id', newId);
    return newId;
  }

  function ariaAssociate(ariaAttribute, target, ref) {
    target.attr('aria-' + ariaAttribute, getOrMakeId(ref));
  }
  /**
   * Determine if the given media query list is (a) not supported or (b) matches.
   * @param {MediaQueryList} mql
   */


  function evalMediaQueryList(mql) {
    return mql.media === 'not all' || mql.matches;
  }

  function useHighContrast() {
    var stored = window.localStorage.getItem('examinrHighContrast');

    if (stored === null) {
      // Determine based on the user-agent settings.
      return !(evalMediaQueryList(window.matchMedia('not speech')) && evalMediaQueryList(window.matchMedia('(monochrome: 0)')) && evalMediaQueryList(window.matchMedia('(forced-colors: none)')) && evalMediaQueryList(window.matchMedia('(inverted-colors: none)')) && evalMediaQueryList(window.matchMedia('not (prefers-contrast: more)')));
    }

    return stored !== 'no';
  }
  /**
  * Enable or disable the high-contrast theme. If the argument is missing, the theme is determined based
  * on the user's preference or the user-agent settings.
  *
  * @param {boolean|undefined} enabled
  */


  function highContrastTheme(enabled) {
    if (enabled !== true && enabled !== false) {
      enabled = useHighContrast();
    }

    if (enabled) {
      enabled = true;
      $('html').addClass('high-contrast');
    } else {
      $('html').removeClass('high-contrast');
      enabled = false;
    }

    window.localStorage.setItem('examinrHighContrast', enabled ? 'yes' : 'no');
    exports.exercises.highContrastTheme(enabled);
  }

  $(function () {
    $('a:empty').attr('aria-hidden', 'true');
    highContrastTheme();
    $('.btn-high-contrast').click(function () {
      highContrastTheme(!$('html').hasClass('high-contrast'));
    }); // add labels to question containers and hide labels from UI if requested

    $('.examinr-question').each(function () {
      var question = $(this);
      question.find('.hide-label .control-label').addClass('sr-only');
      ariaAssociate('labelledby', question, question.find('.card-header'));
    });
  });
  return {
    /**
     * Enable or disable the high-contrast theme. If the argument is missing, the theme is determined based
     * on the user's preference or the user-agent settings.
     *
     * @param {boolean|undefined} enabled
     */
    highContrastTheme: highContrastTheme,
    ariaAssociate: ariaAssociate,
    ariaLabelledBy: function ariaLabelledBy(el, labelEl) {
      ariaAssociate('labelledby', el, labelEl);
    },
    ariaDescribedBy: function ariaDescribedBy(el, labelEl) {
      ariaAssociate('describedby', el, labelEl);
    }
  };
}();

exports.question = function () {
  'use strict';

  var kDebounceEditorChange = 250;
  var kDelaySetMcQuestion = 250;

  function onMcChange(event, extra) {
    if (extra && extra.autofill) {
      return;
    } // Only handle the change if it is triggered by a checkbox or radio button.


    if ($(event.target).filter('input').length) {
      var question = $(event.delegateTarget);
      var store = {
        id: question.attr('id'),
        val: question.find(':checked').map(function (ind, cb) {
          return cb.value;
        }).get()
      };
      exports.utils.attemptStorage.setItem('qinput_mc_' + store.id, store);
    }
  }

  function loadFromAttemptStorage() {
    // Recover input values from the browser-local attempt storage
    exports.utils.attemptStorage.keys(function (key) {
      if (key.startsWith('qinput_text_')) {
        var store = exports.utils.attemptStorage.getItem(key); // window.console.debug('Setting text question with id ' + store.id + ' to "' + store.val + '"')

        $('#' + store.id).val(store.val).trigger('change', [{
          autofill: true
        }]);
      } else if (key.startsWith('qinput_mc_')) {
        var _store = exports.utils.attemptStorage.getItem(key);

        var question = $('#' + _store.id);

        if (_store.val && _store.val.length) {
          // The MC question is empty at first and will be updated by the server-side code.
          // The event is fired *before* the input is updated, but the items must be checked only after the input
          // has finished updating. Delay checking the items until all of them are actually present.
          question.one('shiny:updateinput', exports.utils.autoRetry(function () {
            // window.console.debug('Setting MC question with id ' + store.id + ' to [' + store.val.join(', ') + ']')
            var allItemsPresent = true;

            _store.val.forEach(function (value) {
              var inputEl = question.find('input[value="' + value + '"]');

              if (inputEl.length === 1) {
                inputEl.prop('checked', true).trigger('change', [{
                  autofill: true
                }]);
              } else {
                allItemsPresent = false;
              }
            });

            return allItemsPresent;
          }, kDelaySetMcQuestion, true));
        }
      } else if (key.startsWith('qinput_exercise_')) {
        var _store2 = exports.utils.attemptStorage.getItem(key); // window.console.debug('Setting code editor for question ' + store.qlabel + ' to\n```' + store.val + '\n```')


        var exercise = $('.examinr-question.examinr-exercise[data-questionlabel="' + _store2.qlabel + '"]');
        var editor = exercise.data('editor');

        if (editor) {
          editor.getSession().setValue(_store2.val);
          editor.resize(true);
        }
      }
    }); // Monitor changes to inputs and save them to the browser-local attempt storage.

    $('.examinr-question .shiny-bound-input.shiny-input-checkboxgroup').change(onMcChange);
    $('.examinr-question .shiny-bound-input.shiny-input-radiogroup').change(onMcChange);
    $('.examinr-question input.shiny-bound-input, .examinr-question textarea.shiny-bound-input').change(function (event, extra) {
      if (extra && extra.autofill) {
        return;
      }

      var question = $(this);
      var store = {
        id: question.attr('id'),
        val: question.val()
      };

      if (store.val || store.val === '0') {
        // window.console.debug('Storing text input for id ' + store.id + ': "' + store.val + '"')
        exports.utils.attemptStorage.setItem('qinput_text_' + store.id, store);
      } else {
        // window.console.debug('Deleting text input for id ' + store.id + ' from storage.')
        exports.utils.attemptStorage.removeItem('qinput_text_' + store.id);
      }
    });
    $('.examinr-question.examinr-exercise.shiny-bound-input').each(function () {
      var exercise = $(this);
      var editor = exercise.data('editor');
      var store = {
        qlabel: exercise.data('questionlabel'),
        val: null
      };

      var storeEditorValue = function storeEditorValue(event) {
        store.val = exercise.data('editor').getSession().getValue();

        if (store.val || store.val === '0') {
          // window.console.debug('Storing code for exercise ' + store.qlabel + ' to\n```' + store.val + '\n```')
          exports.utils.attemptStorage.setItem('qinput_exercise_' + store.qlabel, store);
        } else {
          // window.console.debug('Deleting code for exercise ' + store.qlabel)
          exports.utils.attemptStorage.removeItem('qinput_exercise_' + store.qlabel);
        }
      };

      if (editor) {
        editor.on('change', exports.utils.debounce(storeEditorValue, kDebounceEditorChange, false));
      }
    });
  }

  return {
    restoreFromStorage: loadFromAttemptStorage
  };
}();

exports.status = function () {
  'use strict';

  var messages = {};
  var statusContainer;
  var defaultContext = 'info';
  var currentContext = defaultContext;
  var dialogContainerTitle = $('<h4 class="modal-title" id="' + exports.utils.randomId('examinr-status-dialog-title-') + '">');
  var dialogContainerContent = $('<div class="modal-body" id="' + exports.utils.randomId('examinr-status-dialog-body-') + '">');
  var dialogContainerFooter = $('<div class="modal-footer">' + '<button type="button" class="btn btn-primary" data-dismiss="modal">Close</button>' + '</div>');
  var dialogContainer = $('<div class="modal" tabindex="-1" role="alertdialog" ' + 'aria-labelledby="' + dialogContainerTitle.attr('id') + '"' + 'aria-describedby="' + dialogContainerContent.attr('id') + '">' + '<div class="modal-dialog modal-lg" role="document">' + '<div class="modal-content"><div class="modal-header"></div></div>' + '</div>' + '</div>');
  var statusMessageEl = $('<div class="lead" role="alert"></div>');
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
    statusContainer.removeClass('alert-warning');
    statusMessageEl.detach();

    if (condition.type === 'error') {
      showErrorDialog(condition.content.title, condition.content.body, condition.action, condition.content.button, condition.triggerId, condition.triggerEvent, condition.triggerDelay);
    } else if (condition.type === 'locked') {
      showErrorDialog(condition.content.title, condition.content.body, 'none', '');
      $('main').hide();
    } else {
      statusMessageEl.html(condition.content.body).find('.examinr-timestamp').each(parseTimestamp);
      exports.utils.toggleShim($('body'), false);
      statusContainer.removeClass('alert-info').addClass(condition.type === 'warning' ? 'alert-warning' : 'alert-info').children('.col-center').append(statusMessageEl);
    }

    fixMainOffset();
  });
  /**
   * Fix the top offset of the main content to make room for the status container.
   */

  function fixMainOffset() {
    if (statusContainer && statusContainer.length > 0) {
      $('body').css('paddingTop', statusContainer.outerHeight());
    }
  }
  /**
   * Parse the content inside the element as timestamp and replace with the browser's locale date-time string.
   */


  function parseTimestamp() {
    var el = $(this);
    var timestamp = parseInt(el.text(), 10);

    if (timestamp && !isNaN(timestamp)) {
      el.text(exports.utils.formatDate(timestamp * 1000));
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
            exports.utils.toggleShim($('body'), true);
            window.setTimeout(function () {
              return $('#' + triggerId).trigger(triggerEvent);
            }, triggerDelay);
          } else {
            $('#' + triggerId).trigger(triggerEvent);
          }
        });
      }
    }

    exports.utils.toggleShim($('body'), false);
    dialogContainer.attr('role', action === 'none' ? 'dialog' : 'errordialog').appendTo(document.body).one('hidden.bs.modal', function () {
      dialogContainer.detach();
    }).modal({
      keyboard: false,
      backdrop: 'static',
      show: true
    });
  }

  $(function () {
    exports.utils.toggleShim($('body'), true);
    statusContainer = $('.examinr-exam-status');
    messages = JSON.parse($('script.examinr-status-messages').remove().text() || '{}');
    statusContainer.addClass('alert alert-' + currentContext);
    fixMainOffset();
  });
  return {
    /**
     * Reset (i.e., hide) the status messages
     */
    resetMessages: function resetMessages() {
      statusMessageEl.detach();
      dialogContainer.detach();
      statusContainer.removeClass('alert-warning alert-danger').addClass('alert-info');
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
     * Set the context of the status bar.
     * @param {string} context the context class, one of info, warning, danger. If missing, reset to the default
     *   context class.
     */
    setContext: function setContext(context) {
      if (!context) {
        context = defaultContext;
      }

      statusContainer.removeClass('alert-' + currentContext).addClass('alert-' + context);
      currentContext = context;
    },

    /**
     * Append the element to the status bar and adjust the offset.
     * @param {jQuery} el the element to append
     * @param {string} where where to append the element. Can be one of "left", "center" or "right"
     */
    append: function append(el, where) {
      el = $(el);

      switch (where) {
        case 'left':
          statusContainer.children('.col-left').append(el);
          break;

        case 'right':
          statusContainer.children('.col-right').append(el);
          break;

        case 'center':
        default:
          statusContainer.children('.col-center').append(el);
      }

      fixMainOffset();
      return el;
    },

    /**
     * Remove the element from the status bar and adjust the offset.
     * @param {jQuery} el the element to remove
     */
    remove: function remove(el) {
      el.remove();
      fixMainOffset();
    },

    /**
    * Fix the top offset of the main content to make room for the status bar.
    */
    fixMainOffset: fixMainOffset,

    /**
     * Show a modal error dialog.
     * @param {string} title title of the dialog, may contain HTML
     * @param {string} content content of the dialog, may contain HTML
     * @param {string} action what action should be taken when the button is clicked. If "reload", the browser is
     *   instructed to reload the page. If "none", the dialog cannot be closed. In all other cases,
     *   clicking the button will close the dialog.
     * @param {string} button label for the button, may not contain HTML
     */
    showErrorDialog: showErrorDialog
  };
}();

exports.attempt = function () {
  'use strict';

  var config = {};
  var timelimitTimer;
  var timelimit = Number.POSITIVE_INFINITY;
  var timerIsShown = false;
  var progressEl = $('<div class="examinr-progress" role="status"></div>');
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
      // window.console.debug('Attempt is active:', attempt)
      $('main').show().trigger('shown');
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
      // window.console.debug('Attempt is inactive.')
      $('main').hide();
      exports.status.remove(progressEl);
      exports.status.setContext();
    }
  });

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

        if (!timerIsShown) {
          exports.status.fixMainOffset();
          timerIsShown = true;
        }

        if (hrsLeft > 0 || minLeft >= 12) {
          timelimitTimer = window.setTimeout(updateTimeLeft, 60000); // call every minute
        } else {
          if (minLeft < 5) {
            exports.status.setContext('danger');
          } else if (minLeft < 10) {
            exports.status.setContext('warning');
          }

          timelimitTimer = window.setTimeout(updateTimeLeft, 1000); // call every second
        }
      } else {
        // Time is up. Destroy the interface.
        $('main').remove();
        var timeoutMsg = exports.status.getMessage('attemptTimeout');
        exports.status.showErrorDialog(timeoutMsg.title, timeoutMsg.body, 'none');
      }
    } else {
      timerEl.hide();
    }
  }

  $(function () {
    config = JSON.parse($('script.examinr-attempts-config').remove().text() || '{}');
    var progressMsg = exports.status.getMessage('progress');

    if (progressMsg) {
      // replace the following format strings:
      // - "{section_nr}" with an element holding the current section number
      // - "{total_sections}" with an element holding the total number of sections
      // - "{time_left}" with an element holding the time left
      var sectionProgress = progressMsg.section.replace('{section_nr}', '<span class="examinr-section-nr">1</span>').replace('{total_sections}', '<span class="examinr-total-sections">' + (config.totalSections || 1) + '</span>');
      var timerHtml = progressMsg.timer.replace('{time_left}', '<span class="examinr-timer" role="timer">' + '<span class="hrs">??</span>' + '<span class="min">??</span>' + '<span class="sec"></span>' + '</span>');

      if (config.progressive || config.haveTimelimit) {
        if (config.progressive && config.haveTimelimit) {
          progressEl.html(progressMsg.combined.replace('{section}', sectionProgress).replace('{timer}', timerHtml));
        } else if (config.progressive) {
          progressEl.html(sectionProgress);
        } else if (config.haveTimelimit) {
          progressEl.html(timerHtml);
        }

        exports.status.append(progressEl);
        updateTimeLeft();
      }
    }

    if (config.progressbar) {
      var progressbarEl = $('<div class="progress">' + '<div class="progress-bar" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="' + config.totalSections + '" style="min-width: 2em;">' + '</div>' + '</div>');
      exports.status.append(progressbarEl);
    }
  });
  return {
    /**
     * Update the current section number.
     * @param {int} currentSectionNr the current section number
     */
    updateSection: function updateSection(currentSectionNr) {
      if (!currentSectionNr || isNaN(currentSectionNr) || currentSectionNr < 0 || currentSectionNr > config.totalSections) {
        progressEl.hide();
      } else {
        progressEl.show().find('.examinr-section-nr').text(currentSectionNr);

        if (config.progressbar) {
          progressEl.find('.progress-bar').attr('aria-valuenow', currentSectionNr).width(Math.round(100 * currentSectionNr / config.totalSections) + '%');
        }
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
  var kThemeMonochrome = 'ace/theme/monochrome';
  var kThemeDefault = 'ace/theme/textmate';
  var kRetryUpdateHeightDelay = 250;
  var currentTheme = kThemeMonochrome;
  var exerciseRunButtonEnabled = true;

  function attachAceEditor(id, code) {
    var editor = ace.edit(id);
    editor.setHighlightActiveLine(false);
    editor.setShowPrintMargin(false);
    editor.setShowFoldWidgets(false);
    editor.setBehavioursEnabled(true);
    editor.renderer.setDisplayIndentGuides(false);
    editor.setTheme(currentTheme);
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

    exports.utils.toggleShim(outputContainer, running);
    exerciseRunButtonEnabled = running === false;
    $('.examinr-run-button').prop('disabled', !exerciseRunButtonEnabled);
  }

  function initializeExerciseEditor() {
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
    var pointsLabel = exerciseOptions.points ? '<span class="examinr-points badge badge-secondary">' + exerciseOptions.points + '</span>' : '';
    var messageStrings = exports.status.getMessage('exercise') || {};
    var exercisePanel = $('<div class="card">' + '<h6 class="card-header">' + (exerciseOptions.title || '') + pointsLabel + '</h6>' + '<div class="card-body">' + '<div id="' + editorId + '" class="examinr-exercise-editor" role="textbox" contenteditable="true" ' + 'aria-multiline="true" tabindex=0 ></div>' + '</div>' + '<div class="card-footer text-muted">' + '<button type="button" class="btn btn-secondary btn-sm examinr-run-button float-right">' + '<span class="icon"><svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-play-fill" fill="currentColor" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path d="M11.596 8.697l-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 0 1 0 1.393z"/></svg></span>' + exerciseOptions.buttonLabel + '</button>' + '<div class="examinr-exercise-status">' + messageStrings.notYetRun + '</div>' + '</div>' + '</div>');
    var outputContainer = $('<div class="examinr-exercise-output card bg-light">' + (messageStrings.outputTitle ? '<div class="card-header text-muted small">' + messageStrings.outputTitle + '</div>' : '') + '<div class="card-body p-3" role="status"></div>' + '</div>');
    var exerciseEditor = exercise.find('#' + editorId);
    exercise.append(exercisePanel).append(outputContainer); // make exercise more accessible

    exports.accessibility.ariaLabelledBy(exercise, exercisePanel.find('.card-header'));
    exports.accessibility.ariaAssociate('controls', exercisePanel.find('.examinr-run-button'), outputContainer.find('.card-body'));
    exerciseEditor.attr('aria-label', exerciseOptions.inputLabel);
    exerciseEditor.children().attr('aria-hidden', 'true');

    if (!messageStrings.notYetRun) {
      exercise.find('.examinr-exercise-status').hide();
    } else {
      exports.accessibility.ariaDescribedBy(exercisePanel, exercise.find('.examinr-exercise-status'));
    }

    exercise.find('.examinr-exercise-output').hide();
    var runCodeButton = exercise.find('.examinr-run-button'); // Proxy a "run code" event through the button to also trigger shiny input events.

    var triggerClick = function triggerClick() {
      runCodeButton.click();
    };

    var editor = attachAceEditor(editorId, code);
    editor.setFontSize(0.8125 * parseFloat(exercise.find('.card-body').css('font-size')));
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
    runCodeButton.click(function () {
      editor.focus();
    });
    exercise.data({
      editor: editor,
      options: exerciseOptions
    });
    exercise.parents('section').on('shown', exports.utils.autoRetry(function () {
      // window.console.debug('Resize editor ' + exerciseOptions.inputId + ' after section is shown.')
      updateAceHeight();
      editor.resize(true);
      return $(editor.container).height() > 0;
    }, kRetryUpdateHeightDelay, true));
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
          var outputContainer = exercise.find('.examinr-exercise-output').show().find('.card-body');
          outputContainer.html(data.result);
          outputContainer.find('.kable-table table').addClass('table table-striped table-sm');
        } else {
          exercise.find('.examinr-exercise-output').hide();
        }

        if (data.status) {
          var footerClass = data.status_class && data.status_class !== 'info' ? 'alert-' + data.status_class : 'text-muted';
          exercise.find('.card-footer').removeClass('text-muted').removeClass('alert-success').removeClass('alert-warning').removeClass('alert-danger').addClass(footerClass);
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
    $('.examinr-exercise').each(initializeExerciseEditor);
    initializeEditorBindings();
  });
  return {
    highContrastTheme: function highContrastTheme(enabled) {
      currentTheme = enabled ? kThemeMonochrome : kThemeDefault;
      $('.examinr-exercise').each(function () {
        var editor = $(this).data('editor');

        if (editor) {
          editor.setTheme(currentTheme);
        }
      });
    }
  };
}();

exports.feedback = function () {
  'use strict';

  var correctIcon = '<svg aria-label="correct" class="examinr-feedback-annotation" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zm-3.97-3.03a.75.75 0 0 0-1.08.022L7.477 9.417 5.384 7.323a.75.75 0 0 0-1.06 1.06L6.97 11.03a.75.75 0 0 0 1.079-.02l3.992-4.99a.75.75 0 0 0-.01-1.05z"/></svg>';
  var incorrectIcon = '<svg aria-label="incorrect" class="examinr-feedback-annotation" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zM5.354 4.646a.5.5 0 1 0-.708.708L7.293 8l-2.647 2.646a.5.5 0 0 0 .708.708L8 8.707l2.646 2.647a.5.5 0 0 0 .708-.708L8.707 8l2.647-2.646a.5.5 0 0 0-.708-.708L8 7.293 5.354 4.646z"/></svg>';
  var addCommentLabel = 'Add comment';
  var removeCommentLabel = 'Remove comment';
  var numFormat = window.Intl.NumberFormat(undefined, {
    signDisplay: 'never',
    style: 'decimal',
    minimumSignificantDigits: 1,
    maximumSignificantDigits: 3
  });
  var feedbackRenderer = [];
  var shinyRenderDelay = 250;
  var saveFeedbackDelay = 250;
  var attemptSelectorId = exports.utils.randomId('attempt-sel');
  var userSelectorId = exports.utils.randomId('user-sel');
  var userSelectGroup = $('<div class="input-group input-group-sm">' + '<div class="input-group-prepend">' + '<button class="btn examinr-feedback-user-prev btn-secondary" type="button">' + '<span aria-hidden="true">&lt;</span>' + '<span class="sr-only">Previous student</span>' + '</button>' + '<label class="input-group-text sr-only" for="' + userSelectorId + '">' + 'User' + '</label>' + '</div>' + '<select class="custom-select" id="' + userSelectorId + '" disabled></select>' + '<div class="input-group-append">' + '<button class="btn examinr-feedback-user-next btn-secondary" type="button">' + '<span aria-hidden="true">&gt;</span>' + '<span class="sr-only">Next Student</span>' + '</button>' + '</div>' + '</div>');
  var currentAttemptId;
  var centerEl;
  var refreshContentEvents = 0;

  function runAfterUpdate(input, func) {
    var callbackTimer = window.setTimeout(func, shinyRenderDelay);
    input.one('shiny:updateinput', function () {
      window.clearTimeout(callbackTimer);
      window.setTimeout(func, shinyRenderDelay);
    });
  }

  function disableUi() {
    exports.utils.toggleShim($('body'), true);
    refreshContentEvents = 2;
    $(document).one('shiny:idle', function () {
      if (--refreshContentEvents <= 0) {
        exports.utils.toggleShim($('body'), false);
      }
    });
  }

  function attemptChanged() {
    var sel = $(this);
    disableUi(); // update the input value for the autocomplete input

    Shiny.setInputValue('__.examinr.__-attemptSel', sel.val()); // Check if the selected attempt is finished, otherwise add a visual feedback

    if (!sel.children('option').filter(':selected').data('finishedat')) {
      sel.addClass('is-not-finished');
    } else {
      sel.removeClass('is-not-finished');
    }
  }

  function userChanged() {
    var sel = $(this);
    disableUi(); // update the input value for the autocomplete input

    Shiny.setInputValue('__.examinr.__-gradingUserSel', sel.val());
    toggleUserNavigationButtons();
  }

  function toggleUserNavigationButtons() {
    var nextUsers = findNextUsers();
    userSelectGroup.find('.examinr-feedback-user-prev').prop('disabled', !nextUsers[0]);
    userSelectGroup.find('.examinr-feedback-user-next').prop('disabled', !nextUsers[1]);
  }

  function findNextUsers(userSel) {
    if (!userSel) {
      userSel = $('#' + userSelectorId);
    }

    var currentOption = userSel.children(':selected');
    return [currentOption.prev('option').val(), currentOption.next('option').val()];
  }

  function gotoNextUser(event) {
    var userSel = $('#' + userSelectorId);
    var nextUsers = findNextUsers(userSel);
    var which = -1;

    if (event.type === 'click') {
      var btnText = $(this).text();
      which = btnText.startsWith('<') ? 0 : btnText.startsWith('>') ? 1 : -1;
    }

    if (which >= 0) {
      userSel.val(nextUsers[which]).trigger('change');
    }
  }

  function updateAttemptSelector(attempts, current) {
    var sel = $('#' + attemptSelectorId);

    if (sel.length > 0 && attempts && attempts.length > 0) {
      var options = attempts.map(function (at) {
        return '<option value="' + at.id + '" data-finishedat="' + (at.finishedAt || '') + '">' + (at.finishedAt ? exports.utils.formatDate(at.finishedAt * 1000) : 'Unfinished (started at ' + exports.utils.formatDate(at.startedAt * 1000) + ')') + '</option>';
      }).join('');
      sel.html(options).prop('disabled', attempts.length < 2).removeClass('is-not-finished');

      if (current) {
        if (current.id) {
          sel.val(current.id);
        }

        if (!current.finishedAt) {
          sel.addClass('is-not-finished');
        }
      }
    } else {
      sel.prop('disabled', true);
    }
  }
  /**
   * Render feedback data
   */


  Shiny.addCustomMessageHandler('__.examinr.__-feedback', function (data) {
    if (--refreshContentEvents <= 0) {
      exports.utils.toggleShim($('body'), false);
    }

    exports.status.resetMessages();
    data.grading = data.grading === true;

    if (!centerEl) {
      $('.examinr-section-next').remove();
      $('main').show();
      exports.sections.showAll();
      var rightInputGroup = exports.status.append('<div class="input-group input-group-sm">' + '<div class="input-group-prepend">' + '<label class="input-group-text" for="' + attemptSelectorId + '">' + exports.status.getMessage('feedback').attemptLabel + '</label>' + '</div>' + '<select class="custom-select" id="' + attemptSelectorId + '"></select>' + '</div>', 'right');
      rightInputGroup.children('#' + attemptSelectorId).change(attemptChanged);

      if (data.grading) {
        // add user select dropdown
        centerEl = exports.status.append(userSelectGroup);

        if (data.users && data.users.length > 0) {
          var userSel = userSelectGroup.children('#' + userSelectorId);
          userSel.prop('disabled', false).change(userChanged).append(data.users.map(function (user) {
            return '<option value="' + user.id + '">' + (user.displayName || user.id) + '</option>';
          }).join('')); // enable prev/next buttons

          userSelectGroup.find('button').click(gotoNextUser);
        } // add download button


        if (data.gradesDownloadUrl) {
          rightInputGroup.append('<a class="btn btn-sm btn-outline-primary ml-2" href="' + data.gradesDownloadUrl + '" target="_blank" download="">' + '<span class="sr-only">Download grades</span>' + '<svg aria-hidden="true" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M8 0a5.53 5.53 0 0 0-3.594 1.342c-.766.66-1.321 1.52-1.464 2.383C1.266 4.095 0 5.555 0 7.318 0 9.366 1.708 11 3.781 11H7.5V5.5a.5.5 0 0 1 1 0V11h4.188C14.502 11 16 9.57 16 7.773c0-1.636-1.242-2.969-2.834-3.194C12.923 1.999 10.69 0 8 0zm-.354 15.854a.5.5 0 0 0 .708 0l3-3a.5.5 0 0 0-.708-.708L8.5 14.293V11h-1v3.293l-2.146-2.147a.5.5 0 0 0-.708.708l3 3z"/></svg>' + '</a>');
        }
      } else {
        centerEl = exports.status.append('<span></span>');
      }
    }

    updateAttemptSelector(data.allAttempts, data.attempt);

    if (data.attempt) {
      currentAttemptId = data.attempt.id;

      if (data.attempt.userId) {
        userSelectGroup.children('select').val(data.attempt.userId);
        toggleUserNavigationButtons();
      }
    } // turn feedback array into a map


    var feedbackMap = Object.fromEntries(data.feedback.map(function (feedback) {
      return [feedback.qid, feedback];
    }));
    var totalPoints = 0;
    var awardedPoints = 0; // Render feedback for text (or numeric) questions

    $('.examinr-question').each(function () {
      var question = $(this);
      var label = question.data('questionlabel');

      for (var i = 0, end = feedbackRenderer.length; i < end; i++) {
        if (question.filter(feedbackRenderer[i].selector).length > 0) {
          feedbackRenderer[i].callback(question, feedbackMap[label] || {}, data.grading);

          if (label in feedbackMap) {
            totalPoints += feedbackMap[label].maxPoints || 0;

            if (feedbackMap[label].points || feedbackMap[label].points === 0) {
              awardedPoints += feedbackMap[label].points;
            } else {
              awardedPoints = NaN;
            }

            delete feedbackMap[label];
          } else {
            totalPoints += question.data('maxpoints') || 0;
            awardedPoints = NaN;
          }

          return true;
        }
      }

      window.console.warn('No feedback renderer for question ' + label);
    });

    if (isNaN(awardedPoints)) {
      awardedPoints = '&mdash;';
    }

    if (!data.grading) {
      centerEl.html(exports.status.getMessage('feedback').status.replace('{awarded_points}', awardedPoints).replace('{total_points}', totalPoints));
    }

    exports.status.fixMainOffset();
  });

  function questionFooter(question) {
    var card = question.hasClass('card') ? question : question.find('.card');
    var footer = card.find('.card-footer');

    if (footer.length === 0) {
      return $('<div class="card-footer">').appendTo(card);
    }

    return footer;
  }

  function saveFeedbackCallback(qid) {
    return exports.utils.debounce(function (feedback) {
      if (currentAttemptId) {
        Shiny.setInputValue('__.examinr.__-saveFeedback', {
          attempt: currentAttemptId,
          qid: qid,
          points: feedback.points,
          comment: feedback.comment,
          maxPoints: feedback.maxPoints
        });
      }
    }, saveFeedbackDelay);
  }

  function pointsChanged(event) {
    var input = $(this);
    var question = input.parents('.examinr-question');
    var feedback = question.data('feedback');
    var numVal = parseFloat(input.val());
    input.val(numVal);

    if (!isNaN(numVal)) {
      feedback.points = numVal;
      question.data('feedback', feedback);
      event.data.saveFeedback(feedback);
    }
  }

  function commentChanged(event) {
    var input = $(this);
    var question = input.parents('.examinr-question');
    var feedback = question.data('feedback');
    feedback.comment = input.val();
    event.data.saveFeedback(feedback);
    question.data('feedback', feedback);
  }

  function toggleCommentVisible(event) {
    var toggleBtn = $(this);
    var question = toggleBtn.parents('.examinr-question');
    var feedback = question.data('feedback');
    var commentsInputGroup = question.find('.examinr-grading-comment');
    var commentsBtn = $(this);

    if (commentsInputGroup.filter(':visible').length > 0) {
      // Hide the comment box and remove the comment
      commentsInputGroup.hide();
      commentsBtn.find('.btn-label').html('+');
      commentsBtn.find('.sr-only').text(addCommentLabel);

      if (feedback.comment) {
        feedback.hiddenComment = feedback.comment;
        feedback.comment = null;
        event.data.saveFeedback(feedback);
      }
    } else {
      // Show the comment box and add the previously deleted comment
      commentsInputGroup.show();
      commentsBtn.find('.btn-label').html('&times;');
      commentsBtn.find('.sr-only').text(removeCommentLabel);

      if (feedback.hiddenComment) {
        commentsInputGroup.find('textarea').val(feedback.hiddenComment).focus();
        feedback.hiddenComment = null;
      }
    }

    question.data('feedback', feedback);
  }
  /**
   * Add default feedback elements to a question.
   * This renders the points (either as badge for feedback or as input element for grading) and appends
   * the solution and any comments in the footer.
   *
   * @param {jQuery} question question element
   * @param {Object} feedback feedback object
   * @param {boolean} grading render for grading
   */


  function renderDefaultFeedback(question, feedback, grading) {
    var footer = questionFooter(question); // remove all previous feedback

    footer.find('.examinr-grading-feedback').remove(); // Append the solution to the footer

    if (feedback.solution) {
      footer.append('<div class="examinr-grading-feedback">' + '<h6>' + exports.status.getMessage('feedback').solutionLabel + '</h6>' + '<div>' + feedback.solution + '</div>' + '</div>');
    }

    if (grading) {
      if (question.find('.examinr-grading-points').length === 0) {
        var badge = question.find('.examinr-points');
        var pointsInputId = exports.utils.randomId('examinr-pts-');
        var commentInputId = exports.utils.randomId('examinr-comment-');
        badge.parent().addClass('clearfix').append('<div class="input-group input-group-sm examinr-points examinr-grading-points">' + '<label class="sr-only" for="' + pointsInputId + '">Points</label>' + '<input type="number" class="form-control" id="' + pointsInputId + '" step="any" required ' + 'max="' + 2 * feedback.maxPoints + '" />' + '<div class="input-group-append">' + '<span class="input-group-text">' + '<span class="sr-only"> out of </span>' + '<span class="examinr-points-outof">' + badge.text() + '</span>' + '</span>' + '<button type="button" class="btn btn-secondary">' + '<span class="btn-label" aria-hidden="true">' + (feedback.comment ? '&times;' : '+') + '</span>' + '<span class="sr-only">' + (feedback.comment ? removeCommentLabel : addCommentLabel) + '</span>' + '</button>' + '</div>' + '</div>');
        badge.remove();
        footer.append('<div class="input-group examinr-grading-comment">' + '<div class="input-group-prepend">' + '<label class="input-group-text" for="' + commentInputId + '">Comment</label>' + '</div>' + '<textarea class="form-control" id="' + commentInputId + '"></textarea>' + '</div>');
        var saveFeedbackDebounced = {
          saveFeedback: saveFeedbackCallback(feedback.qid)
        };
        question.find('#' + pointsInputId).on('change', saveFeedbackDebounced, pointsChanged);
        question.find('#' + commentInputId).on('change', saveFeedbackDebounced, commentChanged);
        question.find('.examinr-grading-points button').on('click', saveFeedbackDebounced, toggleCommentVisible);

        if (!feedback.comment) {
          footer.find('.examinr-grading-comment').hide();
        }
      }

      question.find('.examinr-grading-points input').val(feedback.points);
      question.data('feedback', feedback);
    } else {
      var _badge = question.find('.examinr-points'); // Render the awarded points in the badge


      if (_badge.find('.examinr-points-awarded').length === 0) {
        var outof = _badge.text();

        _badge.html('<span class="examinr-points-awarded"></span><span class="sr-only"> out of </span> ' + '<span class="examinr-points-outof">' + outof + '</span>');
      }

      if (feedback.points || feedback.points === 0) {
        var context = feedback.points <= 0 ? 'danger' : feedback.points >= feedback.maxPoints ? 'success' : 'info';

        _badge.removeClass('badge-secondary badge-info badge-success badge-danger').addClass('badge-' + context).find('.examinr-points-awarded').addClass('lead').text(feedback.points);
      } else {
        _badge.removeClass('badge-secondary badge-info badge-success badge-danger').addClass('badge-secondary').find('.examinr-points-awarded').removeClass('lead').html('&mdash;');
      }
    }

    if (grading) {
      if (feedback.comment) {
        question.find('.examinr-grading-points .btn .btn-label').html('&times;');
        question.find('.examinr-grading-points .btn .sr-only').text(removeCommentLabel);
        footer.find('.examinr-grading-comment').show().find('textarea').val(feedback.comment);
      } else {
        question.find('.examinr-grading-points .btn .btn-label').html('+');
        question.find('.examinr-grading-points .btn .sr-only').text(addCommentLabel);
        footer.find('.examinr-grading-comment').hide().find('textarea').val('');
      }
    } else if (feedback.comment) {
      footer.append('<div class="text-muted examinr-grading-feedback">' + '<h6>' + exports.status.getMessage('feedback').commentLabel + '</h6>' + '<div>' + feedback.commentHtml || feedback.comment + '</div>' + '</div>');
    }

    exports.utils.renderMathJax(footer);
  } // Default feedback renderer for built-in questions created by `text_question()`


  feedbackRenderer.push({
    selector: '.examinr-q-textquestion',
    callback: function callback(question, feedback, grading) {
      renderDefaultFeedback(question, feedback, grading);
      question.find('.shiny-input-container input,.shiny-input-container textarea').prop('readonly', true).val(feedback.answer || '');
    }
  }); // Default feedback renderer for built-in questions created by `mc_question()`

  feedbackRenderer.push({
    selector: '.examinr-q-mcquestion',
    callback: function callback(question, feedback, grading) {
      var solution = feedback.solution;
      feedback.solution = null;
      renderDefaultFeedback(question, feedback, grading);
      runAfterUpdate(question, function () {
        // reset old feedback
        question.find('.examinr-feedback-annotation').remove();
        question.find('.shiny-input-container label').removeAttr('class'); // display new feedback

        var cbs = question.find('input[type=checkbox],input[type=radio]');
        cbs.prop('disabled', true).prop('checked', false);

        if (feedback.answer) {
          feedback.answer.forEach(function (sel) {
            var cb = cbs.filter('[value="' + sel.value + '"]');
            cb.prop('checked', true);

            if (sel.weight) {
              var context = sel.weight > 0 ? 'success' : 'danger';
              var weightStr = (sel.weight > 0 ? '+' : '&minus;') + numFormat.format(sel.weight);
              cb.parent().append('<span class="examinr-feedback-annotation badge badge-pill badge-' + context + '">' + weightStr + '</span>');
            }
          });
        }

        if (solution) {
          var correctValues = new Set(solution);
          cbs.each(function () {
            var cb = $(this);
            var label = cb.parent();

            if (cb.prop('checked')) {
              if (correctValues.has(cb.val())) {
                label.addClass('text-success').prepend(correctIcon);
              } else {
                label.addClass('text-danger').prepend(incorrectIcon);
              }
            } else {
              if (correctValues.has(cb.val())) {
                label.addClass('text-danger').prepend(incorrectIcon);
              } else {
                label.addClass('text-muted').prepend(correctIcon);
              }
            }
          });
        }
      });
    }
  }); // Default feedback renderer for built-in exercise questions.

  feedbackRenderer.push({
    selector: '.examinr-q-exercise',
    callback: function callback(question, feedback, grading) {
      var footer = questionFooter(question);

      if (grading && footer.children('hr').length === 0) {
        footer.append('<hr class="mb-3 mt-3" />');
      }

      var solution = feedback.solution;
      feedback.solution = null;
      renderDefaultFeedback(question, feedback, grading, grading);
      var editor = question.data('editor');

      if (editor) {
        if (!grading) {
          editor.setReadOnly(true);
        }

        editor.getSession().setValue(feedback.answer || '\n');
      }

      if (!grading) {
        footer.find('.examinr-run-button').remove();
        footer.find('.examinr-exercise-status').remove();
      }

      footer.removeClass('alert alert-danger text-muted');

      if (solution) {
        footer.append('<div class="examinr-grading-feedback">' + '<h6>' + exports.status.getMessage('feedback').solutionLabel + '</h6>' + '<pre><code>' + solution + '</code></pre>' + '</div>');
      }
    }
  });
  return {
    /**
     * Add default feedback elements to a question.
     * This renders the points (either as badge for feedback or as input element for grading) and appends
     * the solution and any comments in the footer.
     *
     * @param {jQuery} question question element
     * @param {Object} feedback feedback object
     * @param {boolean} grading true if rendering for grading and false for regular (immutable) feedback
     */
    renderDefaultFeedback: renderDefaultFeedback,

    /**
     * Register a function to render the feedback for all questions matching the given selector.
     * If two functions match the same question, the function registered *later* will be called.
     *
     * @param {string} selector a valid jQuery selector query
     * @param {function} func callback function which will be called with two arguments:
     *   {jQuery} question the question element
     *   {Object} the feedback object
     *   {boolean} true if rendering for grading and false for regular (immutable) feedback
     */
    registerFeedbackRenderer: function registerFeedbackRenderer(selector, func) {
      feedbackRenderer.unshift({
        selector: selector,
        callback: func
      });
    }
  };
}();
/*
 * Some parts of this file are dervied from the learnr project, which is licensed under the Apache 2.0 license.
 * Original work Copyright 2019 RStudio
 * Derived work Copyright 2020 David Kepplinger
 */


(function () {
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
})();

exports.sections = function () {
  'use strict';

  var kRecalculatedDelay = 500;
  var currentSectionEl;
  var currentSection = {};
  var actualSections;
  Shiny.addCustomMessageHandler('__.examinr.__-sectionChange', function (section) {
    if (section) {
      // window.console.debug('Section changed to:', section)
      if (section.feedback === true) {
        // Clear attempt storage
        exports.utils.attemptStorage.clear(); // Redirect to the feedback

        if (window.location.search) {
          window.location.search = window.location.search + '&display=feedback';
        } else {
          window.location.search = '?display=feedback';
        }
      }

      if (currentSectionEl && currentSectionEl.length > 0) {
        currentSectionEl.removeAttr('role').hide();
      } else if (section.id) {
        $('section.level1').hide();
      }

      currentSection = section;

      if (currentSection === true) {
        currentSectionEl = $('section.level1:not(.examinr-final-remarks)');
      } else {
        currentSectionEl = $('#' + currentSection.id).parent();
        currentSectionEl.attr('role', 'main');
      }

      currentSectionEl.show().trigger('shown');

      if (section.attempt_is_finished) {
        exports.utils.attemptStorage.clear();
      } else {
        exports.question.restoreFromStorage();
      }

      var outputElements = currentSectionEl.find('.shiny-bound-output');

      if (outputElements.length > 0) {
        outputElements.one('shiny:recalculated', exports.utils.debounce(function () {
          exports.utils.toggleShim($('body'), false);
        }, kRecalculatedDelay, false));
      } else {
        exports.utils.toggleShim($('body'), false);
      }

      exports.status.resetMessages();

      if (section.order) {
        exports.attempt.updateSection(section.order);
      }
    }
  });

  function checkMandatory(event) {
    // Find mandatory questions (either in the current section only, or in the entire document)
    var mandatoryQuestions = event.data.context.find('.examinr-question.examinr-mandatory-question'); // Reset style

    mandatoryQuestions.removeClass('examinr-mandatory-error');
    mandatoryQuestions.find('.examinr-mandatory-message').remove();
    var missing = mandatoryQuestions.filter(function () {
      var okay = true;
      var q = $(this);

      if (q.filter('.examinr-q-textquestion').length > 0) {
        q.find('.shiny-input-container input').each(function () {
          var val = $(this).val();
          okay = val && val.length > 0 || val === 0;
          return okay;
        });
      } else if (q.filter('.examinr-q-mcquestion')) {
        okay = q.find('.shiny-bound-input input[value!="N/A"]:checked').length > 0;
      }

      return !okay;
    });

    if (missing.length > 0) {
      missing.addClass('examinr-mandatory-error');

      if (missing.find('.card-footer').length === 0) {
        missing.append('<div class="card-footer examinr-mandatory-message" role="alert">' + exports.status.getMessage('sections').mandatoryError + '</div>');
      } else {
        missing.find('.card-footer').append('<div class="examinr-mandatory-message" role="alert">' + '<hr class="m-3" />' + exports.status.getMessage('sections').mandatoryError + '</div>');
      }

      missing.get(0).scrollIntoView();
      event.stopImmediatePropagation();
      return false;
    }
  }

  $(function () {
    var sectionsConfig = JSON.parse($('script.examinr-sections-config').remove().text() || '{}');
    actualSections = $('section.level1');
    actualSections.each(function () {
      var section = $(this); // Add the correct label to each section

      exports.accessibility.ariaLabelledBy(section, section.children('h1')); // Intercept section navigation to check for mandatory questions being answers.

      if (sectionsConfig.progressive && section.find('.examinr-question.examinr-mandatory-question').length > 0) {
        section.find('.examinr-section-next').click({
          context: section
        }, checkMandatory);
      } else if (!sectionsConfig.progressive) {
        section.find('.examinr-section-next').click({
          context: $('main')
        }, checkMandatory);
      }
    });
    $('.examinr-section-next').click(function () {
      exports.utils.toggleShim($('body'), true);
    });

    if (!sectionsConfig.progressive) {
      // All-at-once exam. Show the "next button" only for the last real section.
      $('.examinr-section-next').hide();
      exports.accessibility.ariaLabelledBy($('main'), $('h1.title')); // Hide the last section (used for final remarks)

      if (sectionsConfig.hideLastSection) {
        actualSections.last().hide().addClass('examinr-final-remarks');
        actualSections = actualSections.slice(0, -1);
      } // Show the button in the last visible section


      actualSections.last().find('.examinr-section-next').show();
    } else {
      // progressive exams: hide all sections
      actualSections.hide();

      if (sectionsConfig.hideLastSection) {
        $('section.level1:last .examinr-section-next').remove();
        actualSections = actualSections.slice(0, -1);
      }
    }
  });
  return {
    showAll: function showAll() {
      actualSections.show().trigger('shown');
    }
  };
}();

exports.grading = function () {
  'use strict';

  function updateGrading(question, gradingData) {
    // Save locally
    question.data('gradingData', gradingData); // And remotely

    if (!gradingData.feedbackShown) {
      gradingData.feedback = null;
    }

    Shiny.setInputValue('__.examinr.__-gradingData', gradingData);
  }

  function toggleFeedback() {
    var btn = $(this);
    var question = btn.parents('.examinr-question');
    var gradingData = question.data('grading') || {};

    if (gradingData.feedbackShown) {
      btn.children('.btn-label').text('+');
      btn.children('.sr-only').text('Add comment');
      question.data('feedbackShown', false).find('.examinr-grading-feedback').remove();
    } else {
      btn.children('.btn-label').html('&times;');
      btn.children('.sr-only').text('Remove comment');
      var footer = question.find('.card-footer');

      if (footer.length === 0) {
        footer = $('<div class="card-footer">');
        footer.appendTo(question.hasClass('card') ? question : question.find('.card'));
      }

      question.data('feedbackShown', true);
      var commentInputId = exports.utils.randomId('comment-');
      footer.append('<div class="input-group examinr-grading-feedback">' + '<div class="input-group-prepend">' + '<label class="input-group-text" for="' + commentInputId + '">' + exports.status.getMessage('feedback').commentLabel + '</label>' + '</div>' + '<textarea class="form-control" id="' + commentInputId + '">' + (gradingData.feedback || '') + '</textarea>' + '</div>');
      question.find('.examinr-grading-feedback textarea').on('change', function () {
        var gradingData = question.data('grading') || {};
        gradingData.feedback = $(this).val();
        updateGrading(question, gradingData);
      });
    }

    gradingData.feedbackShown = !gradingData.feedbackShown;
    updateGrading(question, gradingData);
  }

  function prepareQuestion() {
    var question = $(this);
    var gradingData = question.data('grading') || {};
    var pointsEl = question.find('.examinr-points');
    var container = pointsEl.parent();
    var placeholder = pointsEl.remove().text();

    if (!gradingData.maxPoints) {
      gradingData.maxPoints = parseFloat(question.data('maxPoints')) || 1;
    }

    var pointsInput = $('<input type="number" class="form-control" />').attr('max', gradingData.maxPoints).attr('id', exports.utils.randomId());
    var feedbackBtn = gradingData.feedbackShown ? '&times;' : '+';
    var feedbackLabel = gradingData.feedbackShown ? 'Remove feedback' : 'Add feedback';
    container.addClass('clearfix').append('<div class="input-group input-group-sm examinr-points">' + '<label class="sr-only" for="' + pointsInput.attr('id') + '">Points</label>' + '<div class="input-group-append">' + '<span class="input-group-text">/ ' + placeholder + '</span>' + '<button type="button" class="btn btn-secondary">' + '<span class="btn-label" aria-hidden="true">' + feedbackBtn + '</span>' + '<span class="sr-only">' + feedbackLabel + '</span>' + '</button>' + '</div>' + '</div>').find('.input-group').prepend(pointsInput);
    question.data('grading', gradingData);
    container.find('.btn').click(toggleFeedback);
    exports.utils.disableNumberInputDefaults(pointsInput);
  }

  function startGrading() {
    exports.status.disableProgress();
    var statusContainer = exports.status.statusContainer();
    var studentNameInputId = exports.utils.randomId('student-name');
    var attemptInputId = exports.utils.randomId('attempt');
    statusContainer.append('<form class="form-inline examinr-grading-attempt">' + '<div class="input-group input-group-sm">' + '<div class="input-group-prepend">' + '<button class="btn btn-secondary" type="button">' + '<span aria-hidden="true">&lt;</span>' + '<span class="sr-only">Previous student</span>' + '</button>' + '</div>' + '<label class="sr-only" for="' + studentNameInputId + '">Student</label>' + '<input type="text" id="' + studentNameInputId + '" class="form-control" placeholder="Student" />' + '<span class="input-group-append">' + '<button class="btn btn-secondary" type="button">' + '<span aria-hidden="true">&gt;</span>' + '<span class="sr-only">Next Student</span>' + '</button>' + '</span>' + '</div>' + '<div class="input-group input-group-sm">' + '<label class="sr-only" for="' + attemptInputId + '">Attempt</label>' + '<select id="' + attemptInputId + '" class="form-control" disabled></select>' + '</div>' + '</form>');
    exports.status.fixMainOffset(); // Prepare the questions

    $('.examinr-question').each(prepareQuestion);
  }

  return {
    startGrading: startGrading
  };
}();

(function () {
  'use strict';

  var kEnterKey = 13;
  var dialogTitleId = exports.utils.randomId('examinr-login-title-');
  var dialogContentId = exports.utils.randomId('examinr-login-body-');
  var dialogContainer = $('<div class="modal" tabindex="-1" role="alertdialog" ' + 'aria-labelledby="' + dialogTitleId + '"' + 'aria-describedby="' + dialogContentId + '">' + '<div class="modal-dialog modal-lg" role="document">' + '<div class="modal-content">' + '<div class="modal-header">' + '<h4 class="modal-title" id="' + dialogTitleId + '"><h4>' + '</div>' + '<div class="modal-body" id="' + dialogContentId + '">' + '<form novalidate></form>' + '</div>' + '<div class="modal-footer text-right">' + '<button type="button" class="btn btn-primary"></button>' + '</div>' + '</div>' + '</div>' + '</div>');
  /**
   * Display a login screen
   */

  Shiny.addCustomMessageHandler('__.examinr.__-loginscreen', function (data) {
    exports.utils.toggleShim($('body'), false);
    dialogContainer.find('#' + dialogTitleId).html(data.title || 'Login');
    dialogContainer.find('button').html(data.btnLabel || 'Login');
    var formEl = dialogContainer.find('form');
    data.inputs.forEach(function (input) {
      var inputId = exports.utils.randomId('examinr-login-');
      var invalidFeedbackId = exports.utils.randomId('examinr-login-invalid-');
      formEl.append('<div class="form-group">' + '<label for="' + inputId + '">' + (input.label || 'Missing label') + '</label>' + '<input type="' + (input.type || 'text') + '" class="form-control" name="' + (input.name || inputId) + '" id="' + inputId + '" placeholder="' + (input.label || '') + '" required>' + '<div class="invalid-feedback" id="' + invalidFeedbackId + '">' + (input.emptyError || 'This field cannot be empty!') + '</div>' + '</div>');
    });
    dialogContainer.prependTo(document.body).modal({
      keyboard: false,
      backdrop: 'static',
      show: true
    });
    dialogContainer.find('input').keypress(function (event) {
      if (event.which === kEnterKey) {
        dialogContainer.find('button').click();
      }
    }).first().focus();
    dialogContainer.find('button').click(function (event) {
      var allOk = true;
      dialogContainer.find('.alert').remove();
      var values = dialogContainer.find('input').map(function () {
        var el = $(this);
        var val = el.val();

        if (!val || val.length < 1) {
          allOk = false;
          var invalidFeedbackId = exports.utils.randomId('examinr-login-invalid-');
          el.addClass('is-invalid').attr('aria-describedby', invalidFeedbackId).next().show();
        } else if (el.hasClass('is-invalid')) {
          el.removeClass('is-invalid').removeAttr('aria-describedby').next().hide();
        }

        return {
          name: el.attr('name'),
          value: el.val()
        };
      }).get();

      if (allOk) {
        exports.utils.toggleShim($('body'), true);
        Shiny.setInputValue('__.examinr.__-login', {
          inputs: values
        }, {
          priority: 'event'
        });
      }

      event.stopImmediatePropagation();
    });
  });
  Shiny.addCustomMessageHandler('__.examinr.__-login', function (data) {
    if (data.status === true) {
      dialogContainer.modal('hide').remove();
    } else if (data.error) {
      exports.utils.toggleShim($('body'), false);
      var errorMsg = $('<div class="alert alert-danger">' + data.error + '</div>');

      if (data.errorTitle) {
        errorMsg.prepend('<strong>' + data.errorTitle + '</strong><hr class="mt-2 mb-2" />');
      }

      dialogContainer.find('.modal-body').append(errorMsg);
    }
  });
})();

ace.define('ace/theme/monochrome', ['require', 'exports', 'module', 'ace/lib/dom'], function (acequire, exports, module) {
  exports.isDark = false;
  exports.cssClass = 'ace-monochrome';
  exports.cssText = '.ace-monochrome .ace_gutter{background:#000;color:#fff}.ace-monochrome.ace_print-margin{width:2px;background:#999}.ace-monochrome .ace_editor{background-color:#fff;color:#000}.ace-monochrome .ace_cursor{color:#000;border:0;border-right:0;border-left:.5em solid #000}.ace-monochrome .ace_marker-layer .ace_selection{background:#777}.ace-monochrome.ace_multiselect .ace_selection.ace_start{border-radius:2px}.ace-monochrome .ace_marker-layer .ace_step{background:#000}.ace-monochrome .ace_marker-layer .ace_bracket{margin:0;border:2px solid #d55e00}.ace-monochrome .ace_marker-layer .ace_active-line{background:transparent;border:2px solid #d55e00}.ace-monochrome .ace_gutter-active-line{background:#000}.ace-monochrome .ace_marker-layer .ace_selected-word{border:2px dashed #d55e00}.ace-monochrome .ace_invisible{color:#fff}.ace-monochrome .ace_comment,.ace-monochrome .ace_constant.ace_language{font-style:italic;color:#444}.ace-monochrome .ace_indent-guide{background:url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAACCAYAAACZgbYnAAAAEklEQVQImWPQ0FD0ZXBzd/wPAAjVAoxeSgNeAAAAAElFTkSuQmCC") right repeat-y}.ace_layer{z-index:3}.ace_layer.ace_print-margin-layer{z-index:2}.ace_layer.ace_marker-layer{z-index:1}.ace_editor.ace_autocomplete{background:#ccc;border:solid 2px #000 !important;color:#000}.ace_editor.ace_autocomplete .ace_marker-layer .ace_active-line,.ace_editor.ace_autocomplete .ace_marker-layer .ace_line-hover{background:#fff;border:0;border:2px dashed #d55e00}';
  var dom = acequire('../lib/dom');
  dom.importCssString(exports.cssText, exports.cssClass);
});
/*!
  * Bootstrap util.js v4.5.3 (https://getbootstrap.com/)
  * Copyright 2011-2020 The Bootstrap Authors (https://github.com/twbs/bootstrap/graphs/contributors)
  * Licensed under MIT (https://github.com/twbs/bootstrap/blob/main/LICENSE)
  */

(function (global, factory) {
  (typeof exports === "undefined" ? "undefined" : _typeof(exports)) === 'object' && typeof module !== 'undefined' ? module.exports = factory(require('jquery')) : typeof define === 'function' && define.amd ? define(['jquery'], factory) : (global = typeof globalThis !== 'undefined' ? globalThis : global || self, global.Util = factory(global.jQuery));
})(void 0, function ($) {
  'use strict';

  function _interopDefaultLegacy(e) {
    return e && _typeof(e) === 'object' && 'default' in e ? e : {
      'default': e
    };
  }

  var $__default = /*#__PURE__*/_interopDefaultLegacy($);
  /**
   * --------------------------------------------------------------------------
   * Bootstrap (v4.5.3): util.js
   * Licensed under MIT (https://github.com/twbs/bootstrap/blob/main/LICENSE)
   * --------------------------------------------------------------------------
   */

  /**
   * ------------------------------------------------------------------------
   * Private TransitionEnd Helpers
   * ------------------------------------------------------------------------
   */


  var TRANSITION_END = 'transitionend';
  var MAX_UID = 1000000;
  var MILLISECONDS_MULTIPLIER = 1000; // Shoutout AngusCroll (https://goo.gl/pxwQGp)

  function toType(obj) {
    if (obj === null || typeof obj === 'undefined') {
      return "" + obj;
    }

    return {}.toString.call(obj).match(/\s([a-z]+)/i)[1].toLowerCase();
  }

  function getSpecialTransitionEndEvent() {
    return {
      bindType: TRANSITION_END,
      delegateType: TRANSITION_END,
      handle: function handle(event) {
        if ($__default['default'](event.target).is(this)) {
          return event.handleObj.handler.apply(this, arguments); // eslint-disable-line prefer-rest-params
        }

        return undefined;
      }
    };
  }

  function transitionEndEmulator(duration) {
    var _this = this;

    var called = false;
    $__default['default'](this).one(Util.TRANSITION_END, function () {
      called = true;
    });
    setTimeout(function () {
      if (!called) {
        Util.triggerTransitionEnd(_this);
      }
    }, duration);
    return this;
  }

  function setTransitionEndSupport() {
    $__default['default'].fn.emulateTransitionEnd = transitionEndEmulator;
    $__default['default'].event.special[Util.TRANSITION_END] = getSpecialTransitionEndEvent();
  }
  /**
   * --------------------------------------------------------------------------
   * Public Util Api
   * --------------------------------------------------------------------------
   */


  var Util = {
    TRANSITION_END: 'bsTransitionEnd',
    getUID: function getUID(prefix) {
      do {
        prefix += ~~(Math.random() * MAX_UID); // "~~" acts like a faster Math.floor() here
      } while (document.getElementById(prefix));

      return prefix;
    },
    getSelectorFromElement: function getSelectorFromElement(element) {
      var selector = element.getAttribute('data-target');

      if (!selector || selector === '#') {
        var hrefAttr = element.getAttribute('href');
        selector = hrefAttr && hrefAttr !== '#' ? hrefAttr.trim() : '';
      }

      try {
        return document.querySelector(selector) ? selector : null;
      } catch (_) {
        return null;
      }
    },
    getTransitionDurationFromElement: function getTransitionDurationFromElement(element) {
      if (!element) {
        return 0;
      } // Get transition-duration of the element


      var transitionDuration = $__default['default'](element).css('transition-duration');
      var transitionDelay = $__default['default'](element).css('transition-delay');
      var floatTransitionDuration = parseFloat(transitionDuration);
      var floatTransitionDelay = parseFloat(transitionDelay); // Return 0 if element or transition duration is not found

      if (!floatTransitionDuration && !floatTransitionDelay) {
        return 0;
      } // If multiple durations are defined, take the first


      transitionDuration = transitionDuration.split(',')[0];
      transitionDelay = transitionDelay.split(',')[0];
      return (parseFloat(transitionDuration) + parseFloat(transitionDelay)) * MILLISECONDS_MULTIPLIER;
    },
    reflow: function reflow(element) {
      return element.offsetHeight;
    },
    triggerTransitionEnd: function triggerTransitionEnd(element) {
      $__default['default'](element).trigger(TRANSITION_END);
    },
    supportsTransitionEnd: function supportsTransitionEnd() {
      return Boolean(TRANSITION_END);
    },
    isElement: function isElement(obj) {
      return (obj[0] || obj).nodeType;
    },
    typeCheckConfig: function typeCheckConfig(componentName, config, configTypes) {
      for (var property in configTypes) {
        if (Object.prototype.hasOwnProperty.call(configTypes, property)) {
          var expectedTypes = configTypes[property];
          var value = config[property];
          var valueType = value && Util.isElement(value) ? 'element' : toType(value);

          if (!new RegExp(expectedTypes).test(valueType)) {
            throw new Error(componentName.toUpperCase() + ": " + ("Option \"" + property + "\" provided type \"" + valueType + "\" ") + ("but expected type \"" + expectedTypes + "\"."));
          }
        }
      }
    },
    findShadowRoot: function findShadowRoot(element) {
      if (!document.documentElement.attachShadow) {
        return null;
      } // Can find the shadow root otherwise it'll return the document


      if (typeof element.getRootNode === 'function') {
        var root = element.getRootNode();
        return root instanceof ShadowRoot ? root : null;
      }

      if (element instanceof ShadowRoot) {
        return element;
      } // when we don't find a shadow root


      if (!element.parentNode) {
        return null;
      }

      return Util.findShadowRoot(element.parentNode);
    },
    jQueryDetection: function jQueryDetection() {
      if (typeof $__default['default'] === 'undefined') {
        throw new TypeError('Bootstrap\'s JavaScript requires jQuery. jQuery must be included before Bootstrap\'s JavaScript.');
      }

      var version = $__default['default'].fn.jquery.split(' ')[0].split('.');
      var minMajor = 1;
      var ltMajor = 2;
      var minMinor = 9;
      var minPatch = 1;
      var maxMajor = 4;

      if (version[0] < ltMajor && version[1] < minMinor || version[0] === minMajor && version[1] === minMinor && version[2] < minPatch || version[0] >= maxMajor) {
        throw new Error('Bootstrap\'s JavaScript requires at least jQuery v1.9.1 but less than v4.0.0');
      }
    }
  };
  Util.jQueryDetection();
  setTransitionEndSupport();
  return Util;
});

;
/*!
  * Bootstrap modal.js v4.5.3 (https://getbootstrap.com/)
  * Copyright 2011-2020 The Bootstrap Authors (https://github.com/twbs/bootstrap/graphs/contributors)
  * Licensed under MIT (https://github.com/twbs/bootstrap/blob/main/LICENSE)
  */

(function (global, factory) {
  (typeof exports === "undefined" ? "undefined" : _typeof(exports)) === 'object' && typeof module !== 'undefined' ? module.exports = factory(require('jquery'), require('./util.js')) : typeof define === 'function' && define.amd ? define(['jquery', './util.js'], factory) : (global = typeof globalThis !== 'undefined' ? globalThis : global || self, global.Modal = factory(global.jQuery, global.Util));
})(void 0, function ($, Util) {
  'use strict';

  function _interopDefaultLegacy(e) {
    return e && _typeof(e) === 'object' && 'default' in e ? e : {
      'default': e
    };
  }

  var $__default = /*#__PURE__*/_interopDefaultLegacy($);

  var Util__default = /*#__PURE__*/_interopDefaultLegacy(Util);

  function _extends() {
    _extends = Object.assign || function (target) {
      for (var i = 1; i < arguments.length; i++) {
        var source = arguments[i];

        for (var key in source) {
          if (Object.prototype.hasOwnProperty.call(source, key)) {
            target[key] = source[key];
          }
        }
      }

      return target;
    };

    return _extends.apply(this, arguments);
  }

  function _defineProperties(target, props) {
    for (var i = 0; i < props.length; i++) {
      var descriptor = props[i];
      descriptor.enumerable = descriptor.enumerable || false;
      descriptor.configurable = true;
      if ("value" in descriptor) descriptor.writable = true;
      Object.defineProperty(target, descriptor.key, descriptor);
    }
  }

  function _createClass(Constructor, protoProps, staticProps) {
    if (protoProps) _defineProperties(Constructor.prototype, protoProps);
    if (staticProps) _defineProperties(Constructor, staticProps);
    return Constructor;
  }
  /**
   * ------------------------------------------------------------------------
   * Constants
   * ------------------------------------------------------------------------
   */


  var NAME = 'modal';
  var VERSION = '4.5.3';
  var DATA_KEY = 'bs.modal';
  var EVENT_KEY = "." + DATA_KEY;
  var DATA_API_KEY = '.data-api';
  var JQUERY_NO_CONFLICT = $__default['default'].fn[NAME];
  var ESCAPE_KEYCODE = 27; // KeyboardEvent.which value for Escape (Esc) key

  var Default = {
    backdrop: true,
    keyboard: true,
    focus: true,
    show: true
  };
  var DefaultType = {
    backdrop: '(boolean|string)',
    keyboard: 'boolean',
    focus: 'boolean',
    show: 'boolean'
  };
  var EVENT_HIDE = "hide" + EVENT_KEY;
  var EVENT_HIDE_PREVENTED = "hidePrevented" + EVENT_KEY;
  var EVENT_HIDDEN = "hidden" + EVENT_KEY;
  var EVENT_SHOW = "show" + EVENT_KEY;
  var EVENT_SHOWN = "shown" + EVENT_KEY;
  var EVENT_FOCUSIN = "focusin" + EVENT_KEY;
  var EVENT_RESIZE = "resize" + EVENT_KEY;
  var EVENT_CLICK_DISMISS = "click.dismiss" + EVENT_KEY;
  var EVENT_KEYDOWN_DISMISS = "keydown.dismiss" + EVENT_KEY;
  var EVENT_MOUSEUP_DISMISS = "mouseup.dismiss" + EVENT_KEY;
  var EVENT_MOUSEDOWN_DISMISS = "mousedown.dismiss" + EVENT_KEY;
  var EVENT_CLICK_DATA_API = "click" + EVENT_KEY + DATA_API_KEY;
  var CLASS_NAME_SCROLLABLE = 'modal-dialog-scrollable';
  var CLASS_NAME_SCROLLBAR_MEASURER = 'modal-scrollbar-measure';
  var CLASS_NAME_BACKDROP = 'modal-backdrop';
  var CLASS_NAME_OPEN = 'modal-open';
  var CLASS_NAME_FADE = 'fade';
  var CLASS_NAME_SHOW = 'show';
  var CLASS_NAME_STATIC = 'modal-static';
  var SELECTOR_DIALOG = '.modal-dialog';
  var SELECTOR_MODAL_BODY = '.modal-body';
  var SELECTOR_DATA_TOGGLE = '[data-toggle="modal"]';
  var SELECTOR_DATA_DISMISS = '[data-dismiss="modal"]';
  var SELECTOR_FIXED_CONTENT = '.fixed-top, .fixed-bottom, .is-fixed, .sticky-top';
  var SELECTOR_STICKY_CONTENT = '.sticky-top';
  /**
   * ------------------------------------------------------------------------
   * Class Definition
   * ------------------------------------------------------------------------
   */

  var Modal = /*#__PURE__*/function () {
    function Modal(element, config) {
      this._config = this._getConfig(config);
      this._element = element;
      this._dialog = element.querySelector(SELECTOR_DIALOG);
      this._backdrop = null;
      this._isShown = false;
      this._isBodyOverflowing = false;
      this._ignoreBackdropClick = false;
      this._isTransitioning = false;
      this._scrollbarWidth = 0;
    } // Getters


    var _proto = Modal.prototype; // Public

    _proto.toggle = function toggle(relatedTarget) {
      return this._isShown ? this.hide() : this.show(relatedTarget);
    };

    _proto.show = function show(relatedTarget) {
      var _this = this;

      if (this._isShown || this._isTransitioning) {
        return;
      }

      if ($__default['default'](this._element).hasClass(CLASS_NAME_FADE)) {
        this._isTransitioning = true;
      }

      var showEvent = $__default['default'].Event(EVENT_SHOW, {
        relatedTarget: relatedTarget
      });
      $__default['default'](this._element).trigger(showEvent);

      if (this._isShown || showEvent.isDefaultPrevented()) {
        return;
      }

      this._isShown = true;

      this._checkScrollbar();

      this._setScrollbar();

      this._adjustDialog();

      this._setEscapeEvent();

      this._setResizeEvent();

      $__default['default'](this._element).on(EVENT_CLICK_DISMISS, SELECTOR_DATA_DISMISS, function (event) {
        return _this.hide(event);
      });
      $__default['default'](this._dialog).on(EVENT_MOUSEDOWN_DISMISS, function () {
        $__default['default'](_this._element).one(EVENT_MOUSEUP_DISMISS, function (event) {
          if ($__default['default'](event.target).is(_this._element)) {
            _this._ignoreBackdropClick = true;
          }
        });
      });

      this._showBackdrop(function () {
        return _this._showElement(relatedTarget);
      });
    };

    _proto.hide = function hide(event) {
      var _this2 = this;

      if (event) {
        event.preventDefault();
      }

      if (!this._isShown || this._isTransitioning) {
        return;
      }

      var hideEvent = $__default['default'].Event(EVENT_HIDE);
      $__default['default'](this._element).trigger(hideEvent);

      if (!this._isShown || hideEvent.isDefaultPrevented()) {
        return;
      }

      this._isShown = false;
      var transition = $__default['default'](this._element).hasClass(CLASS_NAME_FADE);

      if (transition) {
        this._isTransitioning = true;
      }

      this._setEscapeEvent();

      this._setResizeEvent();

      $__default['default'](document).off(EVENT_FOCUSIN);
      $__default['default'](this._element).removeClass(CLASS_NAME_SHOW);
      $__default['default'](this._element).off(EVENT_CLICK_DISMISS);
      $__default['default'](this._dialog).off(EVENT_MOUSEDOWN_DISMISS);

      if (transition) {
        var transitionDuration = Util__default['default'].getTransitionDurationFromElement(this._element);
        $__default['default'](this._element).one(Util__default['default'].TRANSITION_END, function (event) {
          return _this2._hideModal(event);
        }).emulateTransitionEnd(transitionDuration);
      } else {
        this._hideModal();
      }
    };

    _proto.dispose = function dispose() {
      [window, this._element, this._dialog].forEach(function (htmlElement) {
        return $__default['default'](htmlElement).off(EVENT_KEY);
      });
      /**
       * `document` has 2 events `EVENT_FOCUSIN` and `EVENT_CLICK_DATA_API`
       * Do not move `document` in `htmlElements` array
       * It will remove `EVENT_CLICK_DATA_API` event that should remain
       */

      $__default['default'](document).off(EVENT_FOCUSIN);
      $__default['default'].removeData(this._element, DATA_KEY);
      this._config = null;
      this._element = null;
      this._dialog = null;
      this._backdrop = null;
      this._isShown = null;
      this._isBodyOverflowing = null;
      this._ignoreBackdropClick = null;
      this._isTransitioning = null;
      this._scrollbarWidth = null;
    };

    _proto.handleUpdate = function handleUpdate() {
      this._adjustDialog();
    } // Private
    ;

    _proto._getConfig = function _getConfig(config) {
      config = _extends({}, Default, config);
      Util__default['default'].typeCheckConfig(NAME, config, DefaultType);
      return config;
    };

    _proto._triggerBackdropTransition = function _triggerBackdropTransition() {
      var _this3 = this;

      if (this._config.backdrop === 'static') {
        var hideEventPrevented = $__default['default'].Event(EVENT_HIDE_PREVENTED);
        $__default['default'](this._element).trigger(hideEventPrevented);

        if (hideEventPrevented.isDefaultPrevented()) {
          return;
        }

        var isModalOverflowing = this._element.scrollHeight > document.documentElement.clientHeight;

        if (!isModalOverflowing) {
          this._element.style.overflowY = 'hidden';
        }

        this._element.classList.add(CLASS_NAME_STATIC);

        var modalTransitionDuration = Util__default['default'].getTransitionDurationFromElement(this._dialog);
        $__default['default'](this._element).off(Util__default['default'].TRANSITION_END);
        $__default['default'](this._element).one(Util__default['default'].TRANSITION_END, function () {
          _this3._element.classList.remove(CLASS_NAME_STATIC);

          if (!isModalOverflowing) {
            $__default['default'](_this3._element).one(Util__default['default'].TRANSITION_END, function () {
              _this3._element.style.overflowY = '';
            }).emulateTransitionEnd(_this3._element, modalTransitionDuration);
          }
        }).emulateTransitionEnd(modalTransitionDuration);

        this._element.focus();
      } else {
        this.hide();
      }
    };

    _proto._showElement = function _showElement(relatedTarget) {
      var _this4 = this;

      var transition = $__default['default'](this._element).hasClass(CLASS_NAME_FADE);
      var modalBody = this._dialog ? this._dialog.querySelector(SELECTOR_MODAL_BODY) : null;

      if (!this._element.parentNode || this._element.parentNode.nodeType !== Node.ELEMENT_NODE) {
        // Don't move modal's DOM position
        document.body.appendChild(this._element);
      }

      this._element.style.display = 'block';

      this._element.removeAttribute('aria-hidden');

      this._element.setAttribute('aria-modal', true);

      this._element.setAttribute('role', 'dialog');

      if ($__default['default'](this._dialog).hasClass(CLASS_NAME_SCROLLABLE) && modalBody) {
        modalBody.scrollTop = 0;
      } else {
        this._element.scrollTop = 0;
      }

      if (transition) {
        Util__default['default'].reflow(this._element);
      }

      $__default['default'](this._element).addClass(CLASS_NAME_SHOW);

      if (this._config.focus) {
        this._enforceFocus();
      }

      var shownEvent = $__default['default'].Event(EVENT_SHOWN, {
        relatedTarget: relatedTarget
      });

      var transitionComplete = function transitionComplete() {
        if (_this4._config.focus) {
          _this4._element.focus();
        }

        _this4._isTransitioning = false;
        $__default['default'](_this4._element).trigger(shownEvent);
      };

      if (transition) {
        var transitionDuration = Util__default['default'].getTransitionDurationFromElement(this._dialog);
        $__default['default'](this._dialog).one(Util__default['default'].TRANSITION_END, transitionComplete).emulateTransitionEnd(transitionDuration);
      } else {
        transitionComplete();
      }
    };

    _proto._enforceFocus = function _enforceFocus() {
      var _this5 = this;

      $__default['default'](document).off(EVENT_FOCUSIN) // Guard against infinite focus loop
      .on(EVENT_FOCUSIN, function (event) {
        if (document !== event.target && _this5._element !== event.target && $__default['default'](_this5._element).has(event.target).length === 0) {
          _this5._element.focus();
        }
      });
    };

    _proto._setEscapeEvent = function _setEscapeEvent() {
      var _this6 = this;

      if (this._isShown) {
        $__default['default'](this._element).on(EVENT_KEYDOWN_DISMISS, function (event) {
          if (_this6._config.keyboard && event.which === ESCAPE_KEYCODE) {
            event.preventDefault();

            _this6.hide();
          } else if (!_this6._config.keyboard && event.which === ESCAPE_KEYCODE) {
            _this6._triggerBackdropTransition();
          }
        });
      } else if (!this._isShown) {
        $__default['default'](this._element).off(EVENT_KEYDOWN_DISMISS);
      }
    };

    _proto._setResizeEvent = function _setResizeEvent() {
      var _this7 = this;

      if (this._isShown) {
        $__default['default'](window).on(EVENT_RESIZE, function (event) {
          return _this7.handleUpdate(event);
        });
      } else {
        $__default['default'](window).off(EVENT_RESIZE);
      }
    };

    _proto._hideModal = function _hideModal() {
      var _this8 = this;

      this._element.style.display = 'none';

      this._element.setAttribute('aria-hidden', true);

      this._element.removeAttribute('aria-modal');

      this._element.removeAttribute('role');

      this._isTransitioning = false;

      this._showBackdrop(function () {
        $__default['default'](document.body).removeClass(CLASS_NAME_OPEN);

        _this8._resetAdjustments();

        _this8._resetScrollbar();

        $__default['default'](_this8._element).trigger(EVENT_HIDDEN);
      });
    };

    _proto._removeBackdrop = function _removeBackdrop() {
      if (this._backdrop) {
        $__default['default'](this._backdrop).remove();
        this._backdrop = null;
      }
    };

    _proto._showBackdrop = function _showBackdrop(callback) {
      var _this9 = this;

      var animate = $__default['default'](this._element).hasClass(CLASS_NAME_FADE) ? CLASS_NAME_FADE : '';

      if (this._isShown && this._config.backdrop) {
        this._backdrop = document.createElement('div');
        this._backdrop.className = CLASS_NAME_BACKDROP;

        if (animate) {
          this._backdrop.classList.add(animate);
        }

        $__default['default'](this._backdrop).appendTo(document.body);
        $__default['default'](this._element).on(EVENT_CLICK_DISMISS, function (event) {
          if (_this9._ignoreBackdropClick) {
            _this9._ignoreBackdropClick = false;
            return;
          }

          if (event.target !== event.currentTarget) {
            return;
          }

          _this9._triggerBackdropTransition();
        });

        if (animate) {
          Util__default['default'].reflow(this._backdrop);
        }

        $__default['default'](this._backdrop).addClass(CLASS_NAME_SHOW);

        if (!callback) {
          return;
        }

        if (!animate) {
          callback();
          return;
        }

        var backdropTransitionDuration = Util__default['default'].getTransitionDurationFromElement(this._backdrop);
        $__default['default'](this._backdrop).one(Util__default['default'].TRANSITION_END, callback).emulateTransitionEnd(backdropTransitionDuration);
      } else if (!this._isShown && this._backdrop) {
        $__default['default'](this._backdrop).removeClass(CLASS_NAME_SHOW);

        var callbackRemove = function callbackRemove() {
          _this9._removeBackdrop();

          if (callback) {
            callback();
          }
        };

        if ($__default['default'](this._element).hasClass(CLASS_NAME_FADE)) {
          var _backdropTransitionDuration = Util__default['default'].getTransitionDurationFromElement(this._backdrop);

          $__default['default'](this._backdrop).one(Util__default['default'].TRANSITION_END, callbackRemove).emulateTransitionEnd(_backdropTransitionDuration);
        } else {
          callbackRemove();
        }
      } else if (callback) {
        callback();
      }
    } // ----------------------------------------------------------------------
    // the following methods are used to handle overflowing modals
    // todo (fat): these should probably be refactored out of modal.js
    // ----------------------------------------------------------------------
    ;

    _proto._adjustDialog = function _adjustDialog() {
      var isModalOverflowing = this._element.scrollHeight > document.documentElement.clientHeight;

      if (!this._isBodyOverflowing && isModalOverflowing) {
        this._element.style.paddingLeft = this._scrollbarWidth + "px";
      }

      if (this._isBodyOverflowing && !isModalOverflowing) {
        this._element.style.paddingRight = this._scrollbarWidth + "px";
      }
    };

    _proto._resetAdjustments = function _resetAdjustments() {
      this._element.style.paddingLeft = '';
      this._element.style.paddingRight = '';
    };

    _proto._checkScrollbar = function _checkScrollbar() {
      var rect = document.body.getBoundingClientRect();
      this._isBodyOverflowing = Math.round(rect.left + rect.right) < window.innerWidth;
      this._scrollbarWidth = this._getScrollbarWidth();
    };

    _proto._setScrollbar = function _setScrollbar() {
      var _this10 = this;

      if (this._isBodyOverflowing) {
        // Note: DOMNode.style.paddingRight returns the actual value or '' if not set
        //   while $(DOMNode).css('padding-right') returns the calculated value or 0 if not set
        var fixedContent = [].slice.call(document.querySelectorAll(SELECTOR_FIXED_CONTENT));
        var stickyContent = [].slice.call(document.querySelectorAll(SELECTOR_STICKY_CONTENT)); // Adjust fixed content padding

        $__default['default'](fixedContent).each(function (index, element) {
          var actualPadding = element.style.paddingRight;
          var calculatedPadding = $__default['default'](element).css('padding-right');
          $__default['default'](element).data('padding-right', actualPadding).css('padding-right', parseFloat(calculatedPadding) + _this10._scrollbarWidth + "px");
        }); // Adjust sticky content margin

        $__default['default'](stickyContent).each(function (index, element) {
          var actualMargin = element.style.marginRight;
          var calculatedMargin = $__default['default'](element).css('margin-right');
          $__default['default'](element).data('margin-right', actualMargin).css('margin-right', parseFloat(calculatedMargin) - _this10._scrollbarWidth + "px");
        }); // Adjust body padding

        var actualPadding = document.body.style.paddingRight;
        var calculatedPadding = $__default['default'](document.body).css('padding-right');
        $__default['default'](document.body).data('padding-right', actualPadding).css('padding-right', parseFloat(calculatedPadding) + this._scrollbarWidth + "px");
      }

      $__default['default'](document.body).addClass(CLASS_NAME_OPEN);
    };

    _proto._resetScrollbar = function _resetScrollbar() {
      // Restore fixed content padding
      var fixedContent = [].slice.call(document.querySelectorAll(SELECTOR_FIXED_CONTENT));
      $__default['default'](fixedContent).each(function (index, element) {
        var padding = $__default['default'](element).data('padding-right');
        $__default['default'](element).removeData('padding-right');
        element.style.paddingRight = padding ? padding : '';
      }); // Restore sticky content

      var elements = [].slice.call(document.querySelectorAll("" + SELECTOR_STICKY_CONTENT));
      $__default['default'](elements).each(function (index, element) {
        var margin = $__default['default'](element).data('margin-right');

        if (typeof margin !== 'undefined') {
          $__default['default'](element).css('margin-right', margin).removeData('margin-right');
        }
      }); // Restore body padding

      var padding = $__default['default'](document.body).data('padding-right');
      $__default['default'](document.body).removeData('padding-right');
      document.body.style.paddingRight = padding ? padding : '';
    };

    _proto._getScrollbarWidth = function _getScrollbarWidth() {
      // thx d.walsh
      var scrollDiv = document.createElement('div');
      scrollDiv.className = CLASS_NAME_SCROLLBAR_MEASURER;
      document.body.appendChild(scrollDiv);
      var scrollbarWidth = scrollDiv.getBoundingClientRect().width - scrollDiv.clientWidth;
      document.body.removeChild(scrollDiv);
      return scrollbarWidth;
    } // Static
    ;

    Modal._jQueryInterface = function _jQueryInterface(config, relatedTarget) {
      return this.each(function () {
        var data = $__default['default'](this).data(DATA_KEY);

        var _config = _extends({}, Default, $__default['default'](this).data(), _typeof(config) === 'object' && config ? config : {});

        if (!data) {
          data = new Modal(this, _config);
          $__default['default'](this).data(DATA_KEY, data);
        }

        if (typeof config === 'string') {
          if (typeof data[config] === 'undefined') {
            throw new TypeError("No method named \"" + config + "\"");
          }

          data[config](relatedTarget);
        } else if (_config.show) {
          data.show(relatedTarget);
        }
      });
    };

    _createClass(Modal, null, [{
      key: "VERSION",
      get: function get() {
        return VERSION;
      }
    }, {
      key: "Default",
      get: function get() {
        return Default;
      }
    }]);

    return Modal;
  }();
  /**
   * ------------------------------------------------------------------------
   * Data Api implementation
   * ------------------------------------------------------------------------
   */


  $__default['default'](document).on(EVENT_CLICK_DATA_API, SELECTOR_DATA_TOGGLE, function (event) {
    var _this11 = this;

    var target;
    var selector = Util__default['default'].getSelectorFromElement(this);

    if (selector) {
      target = document.querySelector(selector);
    }

    var config = $__default['default'](target).data(DATA_KEY) ? 'toggle' : _extends({}, $__default['default'](target).data(), $__default['default'](this).data());

    if (this.tagName === 'A' || this.tagName === 'AREA') {
      event.preventDefault();
    }

    var $target = $__default['default'](target).one(EVENT_SHOW, function (showEvent) {
      if (showEvent.isDefaultPrevented()) {
        // Only register focus restorer if modal will actually get shown
        return;
      }

      $target.one(EVENT_HIDDEN, function () {
        if ($__default['default'](_this11).is(':visible')) {
          _this11.focus();
        }
      });
    });

    Modal._jQueryInterface.call($__default['default'](target), config, this);
  });
  /**
   * ------------------------------------------------------------------------
   * jQuery
   * ------------------------------------------------------------------------
   */

  $__default['default'].fn[NAME] = Modal._jQueryInterface;
  $__default['default'].fn[NAME].Constructor = Modal;

  $__default['default'].fn[NAME].noConflict = function () {
    $__default['default'].fn[NAME] = JQUERY_NO_CONFLICT;
    return Modal._jQueryInterface;
  };

  return Modal;
});
//# sourceMappingURL=exam.js.map
