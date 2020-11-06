exports.status = (function () {
  'use strict'

  var messages = {}
  var config = {}
  var timelimitTimer
  var timelimit = Number.POSITIVE_INFINITY
  var statusContainer

  const dialogContainerTitle = $('<h4 class="modal-title" id="' +
    exports.aria.randomId('examinr-status-dialog-title-') + '">')
  const dialogContainerContent = $('<div class="modal-body" id="' +
    exports.aria.randomId('examinr-status-dialog-body-') + '">')
  const dialogContainerFooter = $(
    '<div class="modal-footer">' +
      '<button type="button" class="btn btn-primary" data-dismiss="modal">Close</button>' +
    '</div>')
  const dialogContainer = $(
    '<div class="modal" tabindex="-1" role="alertdialog" ' +
        'aria-labelledby="' + dialogContainerTitle.attr('id') + '"' +
        'aria-describedby="' + dialogContainerContent.attr('id') + '">' +
      '<div class="modal-dialog modal-lg" role="document">' +
        '<div class="modal-content"><div class="modal-header"></div></div>' +
      '</div>' +
    '</div>')
  const progressEl = $('<div class="alert alert-info examinr-progress" role="status"></div>')
  const statusMessageEl = $('<div class="alert alert-info lead examinr-status-message" role="alert"></div>')

  dialogContainer.find('.modal-header').append(dialogContainerTitle)
  dialogContainer.find('.modal-content').append(dialogContainerContent).append(dialogContainerFooter)

  /**
   * Show a status message.
   * @param {object} condition the condition object to show. Must contain the following elements:
   *  type {string} one of "error", "locked", "warning", or "info"
   *  message {string} the status message, may contain HTML
   *  title {string} (for type "error" or "locked") the title for the error dialog
   *  button {string} (for type "error") the button label for the error dialog
   *  action {string} (for type "error") the action associated with the button. If "reload", the page is reloaded,
   *    otherwise, the dialog is simply closed.
   */
  Shiny.addCustomMessageHandler('__.examinr.__-statusMessage', function (condition) {
    statusMessageEl.detach()
    if (condition.type === 'error') {
      showErrorDialog(condition.content.title, condition.content.body, condition.action, condition.content.button,
        condition.triggerId, condition.triggerEvent, condition.triggerDelay)
    } else if (condition.type === 'locked') {
      showErrorDialog(condition.content.title, condition.content.body, 'none', '')
      $('.main-container').hide()
    } else {
      var alertContext = condition.type === 'warning' ? 'alert-warning' : 'alert-info'
      statusMessageEl.removeClass('alert-warning alert-info').addClass(alertContext)
      statusMessageEl.html(condition.content.body).find('.examinr-timestamp').each(parseTimestamp)
    }
    fixMainOffset()
  })

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
    if (attempt && attempt.active) {
      $('.main-container').show().trigger('shown')
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
    } else {
      $('.main-container').hide()
      progressEl.hide()
    }
  })

  /**
   * Fix the top offset of the main content to make room for the status container.
   */
  function fixMainOffset () {
    if (statusContainer && statusContainer.length > 0) {
      $('body').css('paddingTop', statusContainer.height())
    }
  }

  /**
   * Parse the content inside the element as timestamp and replace with the browser's locale date-time string.
   */
  function parseTimestamp () {
    const el = $(this)
    const timestamp = parseInt(el.text())
    if (timestamp && !isNaN(timestamp)) {
      el.text(new Date(timestamp * 1000).toLocaleString())
    } else {
      el.text('')
    }
  }

  /**
   * Show a modal error dialog.
   * @param {string} title title of the dialog, may contain HTML
   * @param {string} content content of the dialog, may contain HTML
   * @param {string} action what action should be taken when the button is clicked. If "reload", the browser is
   *   instructed to reload the page. If "none", the dialog cannot be closed. In all other cases,
   *   clicking the button will close the dialog.
   * @param {string} button label for the button, may not contain HTML
   */
  function showErrorDialog (title, content, action, button, triggerId, triggerEvent, triggerDelay) {
    const closeBtn = dialogContainerFooter.children('button')

    dialogContainerTitle.html(title).find('.examinr-timestamp').each(parseTimestamp)
    dialogContainerContent.html(content).find('.examinr-timestamp').each(parseTimestamp)

    if (action === 'none') {
      dialogContainerFooter.hide()
    } else {
      closeBtn.text(button)
      if (action === 'reload') {
        closeBtn.one('click', function () {
          window.location.reload()
        })
      } else if (action === 'trigger' && triggerId && triggerEvent) {
        closeBtn.one('click', function () {
          if (triggerDelay) {
            exports.shim.toggle($('body'), true)
            window.setTimeout(() => $('#' + triggerId).trigger(triggerEvent), triggerDelay)
          } else {
            $('#' + triggerId).trigger(triggerEvent)
          }
        })
      }
    }

    exports.shim.toggle($('body'), false)

    dialogContainer.attr('role', (action === 'none') ? 'dialog' : 'errordialog')
      .appendTo(document.body)
      .one('hidden.bs.modal', function () {
        dialogContainer.detach()
      })
      .modal({
        keyboard: false,
        backdrop: 'static',
        show: true
      })
  }

  function toBase10 (val) {
    return (val >= 10 ? val.toString(10) : '0' + val.toString(10))
  }

  /**
   * Update the "time left" status.
   */
  function updateTimeLeft () {
    var msLeft = timelimit === Number.POSITIVE_INFINITY ? Number.POSITIVE_INFINITY : timelimit - new Date()
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

        if (hrsLeft > 0 || minLeft >= 12) {
          timelimitTimer = window.setTimeout(updateTimeLeft, 60000) // call every minute
        } else {
          if (progressEl.hasClass('alert')) {
            if (minLeft < 5) {
              progressEl.removeClass('alert-warning').addClass('alert-danger')
            } else if (minLeft < 10) {
              progressEl.removeClass('alert-info').addClass('alert-warning')
            }
          }
          timelimitTimer = window.setTimeout(updateTimeLeft, 1000) // call every second
        }
      } else {
        // Time is up. Destroy the interface.
        $('.main-container').remove()
        showErrorDialog(messages.attemptTimeout.title, messages.attemptTimeout.body, 'none')
      }
    } else {
      timerEl.hide()
    }
  }

  $(function () {
    exports.shim.toggle($('body'), true)
    statusContainer = $('.examinr-exam-status')
    if (statusContainer.length > 0) {
      statusContainer.prependTo(document.body)
      config = JSON.parse(statusContainer.children('script.status-config').remove().text() || '{}')
      messages = JSON.parse(statusContainer.children('script.status-messages').remove().text() || '{}')

      if (messages.progress) {
        // replace the following format strings:
        // - "{section_nr}" with an element holding the current section number
        // - "{total_sections}" with an element holding the total number of sections
        // - "{time_left}" with an element holding the time left
        const sectionProgress = messages.progress.section
          .replace('{section_nr}', '<span class="examinr-section-nr">1</span>')
          .replace('{total_sections}', '<span class="examinr-total-sections">' + (config.totalSections || 1) +
                   '</span>')
        const timerHtml = messages.progress.timer
          .replace('{time_left}', '<span class="examinr-timer" role="timer">' +
                                    '<span class="hrs">??</span>' +
                                    '<span class="min">??</span>' +
                                    '<span class="sec"></span>' +
                                  '</span>')

        if (!config.progressive && !config.haveTimelimit) {
          // Neither timer nor section progress --> no need for a progress banner.
          progressEl.hide()
        } else {
          if (config.progressive && config.haveTimelimit) {
            progressEl.html(messages.progress.combined
              .replace('{section}', sectionProgress)
              .replace('{timer}', timerHtml))
          } else if (config.progressive) {
            progressEl.html(sectionProgress)
          } else if (config.haveTimelimit) {
            progressEl.html(timerHtml)
          }

          statusContainer.append(progressEl)
          updateTimeLeft()
        }
      }
    }

    if (config.progressbar) {
      const progressbarEl = $(
        '<div class="progress">' +
          '<div class="progress-bar" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="' +
            config.totalSections + '" style="min-width: 2em;">' +
          '</div>' +
        '</div>')
      statusContainer.addClass('examinr-with-progressbar').append(progressbarEl)
    }
    fixMainOffset()
  })

  return {
    /**
     * Reset (i.e., hide) the status messages
     */
    resetMessages: function () {
      statusMessageEl.detach()
      dialogContainer.detach()
      fixMainOffset()
    },

    /**
     * Get the message associated with an identifier.
     * @param {string} what the message identifier
     * @returns the message for the given identifier, or null if the identifier is unknown.
     */
    getMessage: function (what) {
      return messages[what] || null
    },

    /**
     * Update the current section number.
     * @param {int} currentSectionNr the current section number
     */
    updateProgress: function (currentSectionNr) {
      if (!currentSectionNr || isNaN(currentSectionNr) || currentSectionNr < 0 ||
          currentSectionNr > config.totalSections) {
        currentSectionNr = config.totalSections
      }
      progressEl.show().find('.examinr-section-nr').text(currentSectionNr)
      if (config.progressbar) {
        progressEl.find('.progress-bar')
          .attr('aria-valuenow', currentSectionNr)
          .width(Math.round(100 * currentSectionNr / config.totalSections) + '%')
      }
      fixMainOffset()
    }
  }
}())
