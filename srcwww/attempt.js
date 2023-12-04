'use strict'

// const $ = require('jquery')
const status = require('./status')
let config = {}
let timelimitTimer
let timelimit = Number.POSITIVE_INFINITY
let timerIsShown = false

const progressEl = $('<div class="examinr-progress" role="status"></div>')

/** Update the current attempt information.
 *
 * @param {object} attempt an object with the following properties:
 *   - {boolean} active whether there is an active attempt.
 *   - {integer} timelimit the timestamp (in seconds) when the current attempt is closed.
 */
Shiny.addCustomMessageHandler('__.examinr.__-attemptStatus', function (attempt) {
  if (attempt.gracePeriod) {
    config.gracePeriod = attempt.gracePeriod
  }
  if (attempt) {
    if (attempt.active) {
      // window.console.debug('Attempt is active:', attempt)
      $('main').show().trigger('shown')
      progressEl.show()

      if (attempt.timelimit !== 0 && (!attempt.timelimit || attempt.timelimit === 'Inf')) {
        attempt.timelimit = Number.POSITIVE_INFINITY
      }
      try {
        timelimit = new Date(attempt.timelimit * 1000)
        if (timelimitTimer) {
          window.clearTimeout(timelimitTimer)
          timelimitTimer = false
        }
        updateTimeLeft()
      } catch (e) {
        window.console.warn('Cannot set timelimit for current attempt:', e)
        timelimit = Number.POSITIVE_INFINITY
      }
    } else if (attempt.status == 'soft_timeout') {
      const section_navigation = require('./section_navigation')
      // The server allows us to send a final update before forcing the timeout.
      section_navigation.submitCurrentSection()
      uiSoftTimeout()
    } else {
      uiHardTimeout()
    }
  } else {
    // window.console.debug('Attempt is inactive.')
    $('main').hide()
    status.remove(progressEl)
    status.setContext()
  }
})

function toBase10 (val) {
  return (val >= 10 ? val.toString(10) : '0' + val.toString(10))
}

/**
 * Update the "time left" status.
 */
function updateTimeLeft () {
  let msLeft = timelimit === Number.POSITIVE_INFINITY ? Number.POSITIVE_INFINITY : timelimit - new Date()
  const timerEl = progressEl.find('.examinr-timer')

  if (!isNaN(msLeft) && msLeft < Number.POSITIVE_INFINITY) {
    if (msLeft < 1 && msLeft > -1000 * (config.gracePeriod || 1)) {
      msLeft = 0
    }
    if (msLeft >= 0) {
      const hrsLeft = Math.floor(msLeft / 3600000)
      const minLeft = Math.floor((msLeft % 3600000) / 60000)
      const secLeft = Math.floor((msLeft % 60000) / 1000)

      if (hrsLeft > 0) {
        timerEl.children('.hrs').removeClass('ignore').text(toBase10(hrsLeft))
      } else {
        timerEl.children('.hrs').addClass('ignore').text('00')
      }
      timerEl.children('.min').text(toBase10(minLeft))
      if (hrsLeft > 0 || minLeft >= 10) {
        timerEl.children('.min').addClass('nosec')
        timerEl.children('.sec').hide()
      } else {
        timerEl.children('.min').removeClass('nosec')
        timerEl.children('.sec').show().text(toBase10(secLeft))
      }
      timerEl.show()

      if (!timerIsShown) {
        status.fixMainOffset()
        timerIsShown = true
      }

      if (hrsLeft > 0 || minLeft >= 12) {
        timelimitTimer = window.setTimeout(updateTimeLeft, 60000) // call every minute
      } else {
        if (minLeft < 5) {
          status.setContext('danger')
        } else if (minLeft < 10) {
          status.setContext('warning')
        }
        timelimitTimer = window.setTimeout(updateTimeLeft, 1000) // call every second
      }
    } else if (msLeft > -2000 * (config.gracePeriod || 5)) {
      // Soft-timeout. Wait for at least two grace periods, or 10 seconds
      timelimitTimer = window.setTimeout(updateTimeLeft, 1000) // call every second
    } else {
      uiHardTimeout()
    }
  } else {
    timerEl.hide()
  }
}

function uiHardTimeout () {
  // Time is up. Destroy the interface.
  $('main').remove()
  uiSoftTimeout()
}

function uiSoftTimeout () {
  const timeoutMsg = status.getMessage('attemptTimeout')
  status.showErrorDialog(timeoutMsg.title, timeoutMsg.body, 'none')
}

module.exports = {
  init: function () {
    config = JSON.parse($('script.examinr-attempts-config').remove().text() || '{}')
    const progressMsg = status.getMessage('progress')

    if (progressMsg) {
      // replace the following format strings:
      // - "{section_nr}" with an element holding the current section number
      // - "{total_sections}" with an element holding the total number of sections
      // - "{time_left}" with an element holding the time left
      const sectionProgress = progressMsg.section
        .replace('{section_nr}', '<span class="examinr-section-nr">1</span>')
        .replace('{total_sections}', '<span class="examinr-total-sections">' + (config.totalSections || 1) +
                  '</span>')
      const timerHtml = progressMsg.timer
        .replace('{time_left}', '<span class="examinr-timer" role="timer">' +
                                  '<span class="hrs">??</span>' +
                                  '<span class="min">??</span>' +
                                  '<span class="sec"></span>' +
                                '</span>')

      if (config.progressive || config.haveTimelimit) {
        if (config.progressive && config.haveTimelimit) {
          progressEl.html(progressMsg.combined
            .replace('{section}', sectionProgress)
            .replace('{timer}', timerHtml))
        } else if (config.progressive) {
          progressEl.html(sectionProgress)
        } else if (config.haveTimelimit) {
          progressEl.html(timerHtml)
        }

        status.append(progressEl)
        updateTimeLeft()
      }
    }

    if (config.progressbar) {
      const progressbarEl = $(
        '<div class="progress">' +
          '<div class="progress-bar" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="' +
            config.totalSections + '" style="min-width: 2em;">' +
          '</div>' +
        '</div>')
      status.append(progressbarEl)
    }
  },

  /**
   * Update the current section number.
   * @param {int} currentSectionNr the current section number
   */
  updateSection: function (currentSectionNr) {
    if (!currentSectionNr || isNaN(currentSectionNr) || currentSectionNr < 0 ||
        currentSectionNr > config.totalSections) {
      progressEl.hide()
    } else {
      progressEl.show().find('.examinr-section-nr').text(currentSectionNr)
      if (config.progressbar) {
        progressEl.find('.progress-bar')
          .attr('aria-valuenow', currentSectionNr)
          .width(Math.round(100 * currentSectionNr / config.totalSections) + '%')
      }
    }
  }
}
