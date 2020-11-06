exports.sections = (function () {
  'use strict'

  const recalculatedDelay = 250
  var sectionsOptions = {}
  var currentSectionEl
  var currentSection = {}

  function finishedRecalculating () {
    exports.shim.toggle($('body'), false)
  }

  Shiny.addCustomMessageHandler('__.examinr.__-sectionChange', function (section) {
    if (section.current) {
      if (currentSectionEl) {
        currentSectionEl.removeAttr('role').hide()
      }
      currentSection = section.current
      currentSectionEl = $('#' + currentSection.ui_id).parent()
        .show()
        .attr('role', 'main')
        .trigger('shown')

      const outputElements = currentSectionEl.find('.shiny-bound-output')
      var recalculating = outputElements.length
      if (recalculating > 0) {
        // Assume that all outputs need to be recalculated.
        // If not, call finishedRecalculating() after a set delay.
        var recalculatingTimerId = window.setTimeout(finishedRecalculating, recalculatedDelay)
        outputElements.one('shiny:recalculated', function () {
          --recalculating
          if (recalculating <= 0) {
            // All outputs have been recalculated.
            finishedRecalculating()
          } else {
            // Some outputs are still to be recalculated. Wait for them a short while, otherwise call
            // finishedRecalculating()
            window.clearTimeout(recalculatingTimerId)
            recalculatingTimerId = window.setTimeout(finishedRecalculating, recalculatedDelay)
          }
        })
      } else {
        finishedRecalculating()
      }
      exports.status.resetMessages()
      if (section.current.order) {
        exports.status.updateProgress(section.current.order)
      }
    }
  })

  $(function () {
    const sectionsOptionsEl = $('#examinr-sections-options')
    if (sectionsOptionsEl.length > 0) {
      sectionsOptions = JSON.parse(sectionsOptionsEl.text())
      sectionsOptionsEl.remove()
    }

    // Add the correct label to each section
    $('section.level1').each(function () {
      const el = $(this)
      exports.aria.labelledBy(el, el.children('h1'))
    })
    $('#section-header').attr('aria-hidden', 'true')

    if (!sectionsOptions.progressive) {
      // All-at-once exam. Show the "next button" only for the last section.
      $('.examinr-section-next').hide()
      const mainContainer = $('.main-container')
      mainContainer.attr('role', 'main')

      exports.aria.labelledBy(mainContainer, $('h1.title'))

      $('section.level1').last().find('.examinr-section-next').show()
    } else {
      // progressive exams
      $('section.level1').hide()
      $('.examinr-section-next').click(function () {
        exports.shim.toggle($('body'), true)
      })
    }
  })

  return {}
}())
