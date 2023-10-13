'use strict'
// const $ = require('jquery')
const utils = require('./utils')

function getOrMakeId (el) {
  if (el.attr('id')) {
    return el.attr('id')
  }
  const newId = utils.randomId('aria-el-')
  el.attr('id', newId)
  return newId
}

function ariaAssociate (ariaAttribute, target, ref) {
  target.attr('aria-' + ariaAttribute, getOrMakeId(ref))
}

/**
 * Determine if the given media query list is (a) not supported or (b) matches.
 * @param {MediaQueryList} mql
 */
function evalMediaQueryList (mql) {
  return (mql.media === 'not all') || mql.matches
}

function useHighContrast () {
  const stored = window.localStorage.getItem('examinrHighContrast')
  if (stored === null) {
    // Determine based on the user-agent settings.
    return !(evalMediaQueryList(window.matchMedia('not speech')) &&
      evalMediaQueryList(window.matchMedia('(monochrome: 0)')) &&
      evalMediaQueryList(window.matchMedia('(forced-colors: none)')) &&
      evalMediaQueryList(window.matchMedia('(inverted-colors: none)')) &&
      evalMediaQueryList(window.matchMedia('not (prefers-contrast: more)')))
  }
  return (stored !== 'no')
}

/**
* Enable or disable the high-contrast theme. If the argument is missing, the theme is determined based
* on the user's preference or the user-agent settings.
*
* @param {boolean|undefined} enabled
*/
function highContrastTheme (enabled) {
  const exercises = require('./exercises')
  if (enabled !== true && enabled !== false) {
    enabled = useHighContrast()
  }
  if (enabled) {
    enabled = true
    $('html').addClass('high-contrast')
  } else {
    $('html').removeClass('high-contrast')
    enabled = false
  }
  window.localStorage.setItem('examinrHighContrast', enabled ? 'yes' : 'no')
  exercises.highContrastTheme(enabled)
}

module.exports = {
  init: function () {
    $('a:empty').attr('aria-hidden', 'true')
    highContrastTheme()
    $('.btn-high-contrast').on("click", function () {
      highContrastTheme(!$('html').hasClass('high-contrast'))
    })

    // add labels to question containers and hide labels from UI if requested
    $('.examinr-question').each(function () {
      const question = $(this)
      question.find('.hide-label .control-label').addClass('sr-only')
      ariaAssociate('labelledby', question, question.find('.card-header'))
    })
  },

  /**
   * Enable or disable the high-contrast theme. If the argument is missing, the theme is determined based
   * on the user's preference or the user-agent settings.
   *
   * @param {boolean|undefined} enabled
   */
  highContrastTheme: highContrastTheme,

  ariaAssociate: ariaAssociate,

  ariaLabelledBy: function (el, labelEl) {
    ariaAssociate('labelledby', el, labelEl)
  },

  ariaDescribedBy: function (el, labelEl) {
    ariaAssociate('describedby', el, labelEl)
  }
}
