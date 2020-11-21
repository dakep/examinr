exports.status = (function () {
  'use strict'

  let messages = {}
  let statusContainer
  const defaultContext = 'info'
  let currentContext = defaultContext

  const dialogContainerTitle = $('<h4 class="modal-title" id="' +
    exports.utils.randomId('examinr-status-dialog-title-') + '">')
  const dialogContainerContent = $('<div class="modal-body" id="' +
    exports.utils.randomId('examinr-status-dialog-body-') + '">')
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

  const statusMessageEl = $('<div class="alert alert-danger lead examinr-status-message" role="alert"></div>')

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
      $('main').hide()
    } else {
      const alertContext = condition.type === 'warning' ? 'alert-warning' : 'alert-info'
      statusMessageEl.removeClass('alert-warning alert-info')
        .addClass(alertContext)
        .append(statusMessageEl)
        .html(condition.content.body)
        .find('.examinr-timestamp')
        .each(parseTimestamp)
    }
    fixMainOffset()
  })

  /**
   * Fix the top offset of the main content to make room for the status container.
   */
  function fixMainOffset () {
    if (statusContainer && statusContainer.length > 0) {
      $('body').css('paddingTop', statusContainer.outerHeight())
    }
  }

  /**
   * Parse the content inside the element as timestamp and replace with the browser's locale date-time string.
   */
  function parseTimestamp () {
    const el = $(this)
    const timestamp = parseInt(el.text())
    if (timestamp && !isNaN(timestamp)) {
      el.text(exports.utils.formatDate(timestamp * 1000))
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
            exports.utils.toggleShim($('body'), true)
            window.setTimeout(() => $('#' + triggerId).trigger(triggerEvent), triggerDelay)
          } else {
            $('#' + triggerId).trigger(triggerEvent)
          }
        })
      }
    }

    exports.utils.toggleShim($('body'), false)

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

  $(function () {
    exports.utils.toggleShim($('body'), true)
    statusContainer = $('.examinr-exam-status')
    messages = JSON.parse($('script.examinr-status-messages').remove().text() || '{}')
    statusContainer.addClass('alert alert-' + currentContext)
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
     * Set the context of the status bar.
     * @param {string} context the context class, one of info, warning, danger. If missing, reset to the default
     *   context class.
     */
    setContext: function (context) {
      if (!context) {
        context = defaultContext
      }
      statusContainer.removeClass('alert-' + currentContext).addClass('alert-' + context)
      currentContext = context
    },

    /**
     * Append the element to the status bar and adjust the offset.
     * @param {jQuery} el the element to append
     * @param {string} where where to append the element. Can be one of "left", "center" or "right"
     */
    append: function (el, where) {
      el = $(el)
      switch (where) {
        case 'left':
          statusContainer.children('.col-left').append(el)
          break
        case 'right':
          statusContainer.children('.col-right').append(el)
          break
        case 'center':
        default:
          statusContainer.children('.col-center').append(el)
      }
      fixMainOffset()
      return el
    },

    /**
     * Remove the element from the status bar and adjust the offset.
     * @param {jQuery} el the element to remove
     */
    remove: function (el) {
      el.remove()
      fixMainOffset()
    },

    /**
    * Fix the top offset of the main content to make room for the status bar.
    */
    fixMainOffset: fixMainOffset,

    /**
     * Show a modal error dialog.
     * @param {string} title title of the dialog, may contain HTML
     * @param {string} content content of the dialog, may contain HTML
     * @param {string} action what action should be taken when the button is clicked. If "reload", the browser is
     *   instructed to reload the page. If "none", the dialog cannot be closed. In all other cases,
     *   clicking the button will close the dialog.
     * @param {string} button label for the button, may not contain HTML
     */
    showErrorDialog: showErrorDialog
  }
}())
