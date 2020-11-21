exports.sections = (function () {
  'use strict'

  const recalculatedDelay = 250
  let currentSectionEl
  let currentSection = {}
  let actualSections

  function finishedRecalculating () {
    exports.utils.toggleShim($('body'), false)
  }

  Shiny.addCustomMessageHandler('__.examinr.__-sectionChange', function (section) {
    if (section) {
      if (section.feedback === true) {
        // Redirect to the feedback
        window.location.search = '?display=feedback'
      }

      if (currentSectionEl && currentSectionEl.length > 0) {
        currentSectionEl.removeAttr('role').hide()
      } else if (section.id) {
        $('section.level1').hide()
      }
      currentSection = section
      currentSectionEl = $('#' + currentSection.id).parent()
        .show()
        .attr('role', 'main')
        .trigger('shown')

      const outputElements = currentSectionEl.find('.shiny-bound-output')
      let recalculating = outputElements.length
      if (recalculating > 0) {
        // Assume that all outputs need to be recalculated.
        // If not, call finishedRecalculating() after a set delay.
        let recalculatingTimerId = window.setTimeout(finishedRecalculating, recalculatedDelay)
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
      if (section.order) {
        exports.attempt.updateSection(section.order)
      }
    }
  })

  $(function () {
    const sectionsConfig = JSON.parse($('script.examinr-sections-config').remove().text() || '{}')

    actualSections = $('section.level1')
    // Add the correct label to each section
    actualSections.each(function () {
      const el = $(this)
      exports.accessibility.ariaLabelledBy(el, el.children('h1'))
    })

    $('.examinr-section-next').click(function () {
      exports.utils.toggleShim($('body'), true)
    })

    if (!sectionsConfig.progressive) {
      // All-at-once exam. Show the "next button" only for the last real section.
      $('.examinr-section-next').hide()
      exports.accessibility.ariaLabelledBy($('main'), $('h1.title'))

      // hide the last section (used for final remarks)
      if (sectionsConfig.hideLastSection) {
        actualSections.last().hide()
        actualSections = actualSections.slice(0, -1)
        actualSections.last().find('.examinr-section-next').show()
      }
    } else {
      // progressive exams: hide all sections
      actualSections.hide()
      if (sectionsConfig.hideLastSection) {
        $('section.level1:last .examinr-section-next').remove()
        actualSections = actualSections.slice(0, -1)
      }
    }
  })

  return {
    showAll: function () {
      actualSections.show().trigger('shown')
    }
  }
}())
