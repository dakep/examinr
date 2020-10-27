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
        currentSectionEl.hide()
      }
      currentSection = section.current
      currentSectionEl = $('#' + currentSection.ui_id).parent().show().trigger('shown')
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
    }
  })

  function initializeSectionedExam () {
    const sectionsOptionsEl = $('#examinr-sections-options')
    if (sectionsOptionsEl.length > 0) {
      sectionsOptions = JSON.parse(sectionsOptionsEl.text())
      sectionsOptionsEl.remove()
    }
    if (!sectionsOptions.progressive) {
      // All-at-once exam. Show the "next button" only for the last section.
      $('.examinr-section-next').hide()
      $('section.level1').last().find('.examinr-section-next').show()
    } else {
      // progressive exams
      $('section.level1').hide()
      exports.shim.toggle($('body'), true)
      $('.examinr-section-next').click(function () {
        exports.shim.toggle($('body'), true)
      })
    }
  }

  $(document).ready(function () {
    initializeSectionedExam()
  })
}())
