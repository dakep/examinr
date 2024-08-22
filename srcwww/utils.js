'use strict'

// const $ = require('jquery')

const arrowKeyUp = 38
const arrowKeyDown = 40
const lang = $('html').attr('lang') || 'en-US'

var examMetadata = ((typeof EXAMINR_EXAM_METADATA !== 'undefined') ? EXAMINR_EXAM_METADATA : null)

function preventDefault (e) {
  e.preventDefault()
}

function attemptStoragePrefix () {
  if (examMetadata) {
    return examMetadata.id + '_' + examMetadata.version + '_'
  }
  return ''
}

function generateRandomId (prefix) {
  if (!prefix) {
    prefix = 'anonymous-el-'
  }
  return prefix + Math.random().toString(36).slice(2)
}

function initNumericInputs () {
  const numRegexp = /^-?(\d*\.)?\d+$/
  $('.examinr-q-numeric input[type=text]').each(function () {
    const input = $(this)
    const feedbackId = generateRandomId()

    input.change(function () {
      const newVal = input.val()
      $('#' + feedbackId).remove()
      if (newVal && !numRegexp.test(newVal)) {
        input.attr('aria-describedby', feedbackId).addClass('is-invalid')
          .after('<span id="' + feedbackId + '" class="sr-only">invalid value</span>')
      } else {
        if (newVal.length > 0) {
          input.val(parseFloat(newVal))
        }
        input.removeAttr('aria-describedby').removeClass('is-invalid')
      }
    })
  })
}

module.exports = {
  init: function () {
    if (typeof EXAMINR_EXAM_METADATA !== 'undefined' && examMetadata === null) {
      examMetadata = EXAMINR_EXAM_METADATA
    }
    initNumericInputs()
  },

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
    getItem: function (key) {
      return JSON.parse(window.localStorage.getItem(attemptStoragePrefix() + key))
    },

    /**
     * Store an item in the storage.
     *
     * @param {DOMString} key identifier for the object.
     * @param {*} value JSON-serializable object to be associated with the key.
     */
    setItem: function (key, value) {
      return window.localStorage.setItem(attemptStoragePrefix() + key, JSON.stringify(value))
    },

    /**
     * Delete an item from storage.
     *
     * @param {DOMString} key identifier for the object.
     */
    removeItem: function (key) {
      return window.localStorage.removeItem(attemptStoragePrefix() + key)
    },

    /*
      * Delete all items from storage.
      */
    clear: function () {
      const attemptStoragePrefixStr = attemptStoragePrefix()
      for (var i = window.localStorage.length - 1; i >= 0; --i) {
        const key = window.localStorage.key(i)
        if (key && key.startsWith(attemptStoragePrefixStr)) {
          window.localStorage.removeItem(key)
        }
      }
    },

    /**
     * Iterate over all keys in storage.
     * @param {Function} callback function being called for each key in the store given as first argument.
     */
    keys: function (callback) {
      const attemptStoragePrefixStr = attemptStoragePrefix()
      for (var i = window.localStorage.length - 1; i >= 0; --i) {
        const key = window.localStorage.key(i)
        if (key && key.startsWith(attemptStoragePrefixStr)) {
          callback(key.substring(attemptStoragePrefixStr.length))
        }
      }
    }
  },

  /**
   * Format the given date in the document's language
   * @param {int} timestamp the timestamp to format
   */
  formatDate: function (timestamp) {
    return new Date(timestamp).toLocaleString(lang)
  },

  /**
   * Create a function which calls the given function repeatedly until it returns `true`.
   *
   * @param {function} func function to call repeatedly until it returns true.
   * @param {integer} delay delay in ms
   */
  autoRetry: function (func, delay, immediately) {
    return function () {
      const context = this
      const args = arguments
      const requireRetry = !immediately || (func.apply(context, args) !== true)
      if (requireRetry) {
        const timerId = window.setInterval(function () {
          if (func.apply(context, args) === true) {
            window.clearInterval(timerId)
          }
        }, delay)
      }
    }
  },

  /**
   * Disable stepping by arrow keys and scrolling on number inputs.
   *
   * @param {jQuery} numberInputs the inputs to disable the defaults for.
   */
  disableNumberInputDefaults: function (numberInputs) {
    if (!numberInputs) {
      numberInputs = $('input[type=number]')
    }

    numberInputs.on('focus', function () {
      $(this).on('wheel.disableScrollEvent', preventDefault)
        .on('keydown.disableScrollEvent', function (e) {
          if (e.which === arrowKeyDown || e.which === arrowKeyUp) {
            e.preventDefault()
          }
        })
    }).on('blur', function () {
      $(this).off('.disableScrollEvent')
    })
  },
  /**
   * Debounce the given function, calling it only once for a series of shortly spaced calls.
   * @param {function} fun function to debounce
   * @param {integer} wait time (in ms) to wait before calling `fun`
   * @param {boolean} when if `fun` should be called immediately on the raising edge ('immediate'),
   *   the falling edge ('delayed'; default) or both ('both').
   */
  debounce: function (fun, wait, when) {
    if (when === true) {
      when = 'immediate'
    } else if (when === false || when === undefined) {
      when = 'delayed'
    }

    const trigger_delayed = when === 'delayed' || when === 'both'
    const trigger_immediate = when === 'immediate' || when === 'both'

    let trigger_delayed_now = trigger_delayed
    let timerId = null

    return function () {
      const context = this
      const args = arguments
      const delayed = function () {
        timerId = null
        if (trigger_delayed_now) {
          fun.apply(context, args)
        }
      }
      const callImmediately = trigger_immediate && !timerId
      trigger_delayed_now = trigger_delayed && !callImmediately
      window.clearTimeout(timerId)
      timerId = window.setTimeout(delayed, wait)
      if (callImmediately) {
        fun.apply(context, args)
      }
    }
  },
  randomId: generateRandomId,
  /**
   * Render any math in the element with the given id
   *
   * @param {string} id id of the element to render math.
   * @param {boolean} isDummy if true, the id attribute is removed.
   */
  triggerMathJax: function (id, isDummy) {
    if (window.MathJax && window.MathJax.startup && window.MathJax.startup.promise) {
      window.MathJax.startup.promise = window.MathJax.startup.promise
        .then(() => {
          let el = $('#' + id)
          if (isDummy) {
            const parent = el.parent()
            if (parent.length > 0) {
              parent.append(el.remove().html())
              el = parent
            }
          }
          return window.MathJax.typesetPromise(el)
        })
        .catch((err) => window.console.warn('Cannot typeset math: ', err.message))
      return window.MathJax.startup.promise
    }
  },

  /**
   * Render any math in the element with the given id
   *
   * @param {jQuery} el element to render math in
   */
  renderMathJax: function (el) {
    if (window.MathJax && window.MathJax.startup && window.MathJax.startup.promise) {
      window.MathJax.startup.promise = window.MathJax.startup.promise
        .then(() => {
          return window.MathJax.typesetPromise(el)
        })
        .catch((err) => window.console.warn('Cannot typeset math: ', err.message))
      return window.MathJax.startup.promise
    }
  },

  /**
   * Exam metadata object.
   * May be `null` if not yet available.
   */
  examMetadata: function () {
    return examMetadata
  },

  /**
   * Toggle a "working" shim over the given element.
   * @param {jQuery} el jquery element which should be covered by the shim.
   * @param {boolean} show force the shim to be shown/hidden, regardless of the current state.
   */
  toggleShim: function (el, show) {
    if (!el) {
      // Overlay over entire document
      el = $('body')
    } else {
      el = $(el)
    }

    let spinOverlay = el.children('.examinr-recompute-overlay')

    // If `show` is missing, show the overlay if it's not present at the moment
    if (typeof show === 'undefined') {
      show = (spinOverlay.length === 0)
    }

    if (show === false) {
      spinOverlay.remove()
      el.removeClass('examinr-recompute-outer')
    } else {
      spinOverlay = $('<div class="examinr-recompute-overlay"><div class="examinr-recompute" role="status">' +
                        '<span class="sr-only">Loading...</span>' +
                      '</div></div>')
      el.prepend(spinOverlay)
      const op = spinOverlay.offsetParent()
      if (op.length > 0 && op.get(0) !== el.get(0)) {
        el.addClass('examinr-recompute-outer')
      }
      el.show()
    }
  }
}
