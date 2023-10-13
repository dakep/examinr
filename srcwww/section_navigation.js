'use strict'

// const $ = require('jquery')
const utils = require('./utils')
const question = require('./question')
const status = require('./status')
const attempt = require('./attempt')
const accessibility = require('./accessibility')
const exercises = require('./exercises')

const kRecalculatedDelay = 500
let currentSectionEl
let currentSection = {}
let actualSections

Shiny.addCustomMessageHandler('__.examinr.__-sectionChange', function (section) {
  if (section) {
    // window.console.debug('Section changed to:', section)
    if (section.feedback === true) {
      // Clear attempt storage
      utils.attemptStorage.clear()
      // Redirect to the feedback
      if (window.location.search) {
        window.location.search = window.location.search + '&display=feedback'
      } else {
        window.location.search = '?display=feedback'
      }
    }

    if (currentSectionEl && currentSectionEl.length > 0) {
      currentSectionEl.removeAttr('role').hide()
    } else if (section.id) {
      $('section.level1').hide()
    }
    currentSection = section
    if (currentSection === true) {
      currentSectionEl = $('section.level1:not(.examinr-final-remarks)')
    } else {
      currentSectionEl = $('#' + currentSection.id).parent()
      currentSectionEl.attr('role', 'main')
    }
    currentSectionEl.show().trigger('shown')

    if (section.attempt_is_finished) {
      utils.attemptStorage.clear()
    } else {
      question.restoreFromStorage()
    }

    const outputElements = currentSectionEl.find('.shiny-bound-output')
    if (outputElements.length > 0) {
      // hide the shim after it's recalculated
      outputElements.one('shiny:recalculated', utils.debounce(function () {
        utils.toggleShim($('body'), false)
      }, kRecalculatedDelay, false))
    } else {
      utils.toggleShim($('body'), false)
    }

    status.resetMessages()
    if (section.order) {
      attempt.updateSection(section.order)
    }
  }
})

function checkMandatory (event) {
  // Find mandatory questions (either in the current section only, or in the entire document)
  const mandatoryQuestions = event.data.context.find('.examinr-question.examinr-mandatory-question')

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
    missing.addClass('examinr-mandatory-error')
    if (missing.find('.card-footer').length === 0) {
      missing.append('<div class="card-footer examinr-mandatory-message" role="alert">' +
          status.getMessage('sections').mandatoryError +
        '</div>')
    } else {
      missing.find('.card-footer').append('<div class="examinr-mandatory-message" role="alert">' +
          '<hr class="m-3" />' +
          status.getMessage('sections').mandatoryError +
        '</div>')
    }
    missing.get(0).scrollIntoView()
    event.stopImmediatePropagation()
    return false
  }

  /* Submit all code exercises in the current context */
  exercises.forceSubmit(false, event.data.context)
}

module.exports = {
  init: function () {
    const sectionsConfig = JSON.parse($('script.examinr-sections-config').remove().text() || '{}')

    actualSections = $('section.level1')
    actualSections.each(function () {
      const section = $(this)
      // Add the correct label to each section
      accessibility.ariaLabelledBy(section, section.children('h1'))

      // Intercept section navigation to check for mandatory questions being answers.
      if (sectionsConfig.progressive && section.find('.examinr-question.examinr-mandatory-question').length > 0) {
        section.find('.examinr-section-next').on("click", { context: section }, checkMandatory)
      } else if (!sectionsConfig.progressive) {
        section.find('.examinr-section-next').on("click", { context: $('main') }, checkMandatory)
      }
    })

    $('.examinr-section-next').on("click", function () {
      utils.toggleShim($('body'), true)
    })

    if (!sectionsConfig.progressive) {
      // All-at-once exam. Show the "next button" only for the last real section.
      $('.examinr-section-next').hide()
      accessibility.ariaLabelledBy($('main'), $('h1.title'))

      // Hide the last section (used for final remarks)
      if (sectionsConfig.hideLastSection) {
        actualSections.last().hide().addClass('examinr-final-remarks')
        actualSections = actualSections.slice(0, -1)
      }

      // Show the button in the last visible section
      actualSections.last().find('.examinr-section-next').show()
    } else {
      // progressive exams: hide all sections
      actualSections.hide()
      if (sectionsConfig.hideLastSection) {
        $('section.level1:last .examinr-section-next').remove()
        actualSections = actualSections.slice(0, -1)
      }
    }
  },

  showAll: function () {
    actualSections.show().trigger('shown')
  }
}
