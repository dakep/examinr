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
    actualSections.each(function () {
      const el = $(this)
      // Add the correct label to each section
      exports.accessibility.ariaLabelledBy(el, el.children('h1'))

      // Intercept section navigation to check for mandatory questions being answers.
      const mandatoryQuestions = el.find('.examinr-question.examinr-mandatory-question')
      if (mandatoryQuestions.length > 0) {
        el.find('.examinr-section-next').click(function (event) {
          // Reset style
          mandatoryQuestions.removeClass('examinr-mandatory-error')
          mandatoryQuestions.find('.examinr-mandatory-message').remove()

          const missing = mandatoryQuestions.filter(function () {
            let okay = true
            const q = $(this)
            if (q.filter('.examinr-q-textquestion').length > 0) {
              q.find('.shiny-input-container input').each(function () {
                const val = $(this).val()
                okay = ((val && val.length > 0) || (val === 0))
                return okay
              })
            } else if (q.filter('.examinr-q-mcquestion')) {
              okay = (q.find('.shiny-bound-input input[value!="N/A"]:checked').length > 0)
            }
            return !okay
          })
          if (missing.length > 0) {
            window.console.log('Prevent section navigation!')
            missing.addClass('examinr-mandatory-error')
            if (missing.find('.card-footer').length === 0) {
              missing.append('<div class="card-footer examinr-mandatory-message" role="alert">' +
                  exports.status.getMessage('sections').mandatoryError +
                '</div>')
            } else {
              missing.find('.card-footer').append('<div class="examinr-mandatory-message" role="alert">' +
                  '<hr class="m-3" />' +
                  exports.status.getMessage('sections').mandatoryError +
                '</div>')
            }
            missing.get(0).scrollIntoView()
            event.stopImmediatePropagation()
            return false
          }
        })
      }
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
