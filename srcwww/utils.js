exports.utils = (function () {
  'use strict'

  const arrowKeyUp = 38
  const arrowKeyDown = 40
  const lang = $('html').attr('lang') || 'en-US'

  function preventDefault (e) {
    e.preventDefault()
  }

  function generateRandomId (prefix) {
    if (!prefix) {
      prefix = 'anonymous-el-'
    }
    return prefix + Math.random().toString(36).slice(2)
  }

  function storeGet (key) {
    return JSON.parse(window.localStorage.getItem('examinr_' + key))
  }

  function storeSet (key, value) {
    return window.localStorage.setItem('examinr_' + key, JSON.stringify(value))
  }

  function storeRemove (key) {
    return window.localStorage.removeItem('examinr_' + key)
  }

  function initNumericInputs () {
    const numRegexp = /^-?(\d*\.)?\d+$/
    $('.examinr-q-numeric input[type=text]').each(function () {
      const input = $(this)
      const feedbackId = exports.utils.randomId()

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

  $(function () {
    initNumericInputs()
  })

  return {
    /**
     * Enable or disable the high-contrast theme. If the argument is missing, the theme is determined based
     * on the user's preference or the user-agent settings.
     *
     * @param {boolean|undefined} enabled
     */
    store: {
      get: storeGet,
      set: storeSet,
      rem: storeRemove
    },

    /**
     * Format the given date in the document's language
     * @param {int} timestamp the timestamp to format
     */
    formatDate: function (timestamp) {
      return new Date(timestamp).toLocaleString(lang)
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
     * @param {boolean} immediate if `fun` should be called immediately on the raising edge, not the falling edge.
     */
    debounce: function (fun, wait, immediate) {
      let timerId = null

      return function () {
        const context = this
        const args = arguments
        const delayed = function () {
          timerId = null
          if (!immediate) {
            fun.apply(context, args)
          }
        }
        const callImmediately = immediate && !timerId
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
}())
