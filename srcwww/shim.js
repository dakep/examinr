exports.shim = (function () {
  'use strict'

  return {
    /**
     * Toggle a "working" shim over the given element.
     * @param {jQuery} el jquery element which should be covered by the shim.
     * @param {boolean} show force the shim to be shown/hidden, regardless of the current state.
     */
    toggle: function (el, show) {
      if (!el) {
        // Overlay over entire document
        el = $('body')
      } else {
        el = $(el)
      }

      var spinOverlay = el.children('.examinr-recompute-overlay')

      // If `show` is missing, show the overlay if it's not present at the moment
      if (typeof show === 'undefined') {
        show = (spinOverlay.length === 0)
      }

      if (show === false) {
        spinOverlay.remove()
        el.removeClass('examinr-recompute-outer')
      } else {
        spinOverlay = $('<div class="examinr-recompute-overlay"><div class="examinr-recompute"></div></div>')
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
