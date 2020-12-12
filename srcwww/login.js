exports.login = (function () {
  'use strict'

  const kEnterKey = 13
  const dialogTitleId = exports.utils.randomId('examinr-login-title-')
  const dialogContentId = exports.utils.randomId('examinr-login-body-')

  const dialogContainer = $(
    '<div class="modal" tabindex="-1" role="alertdialog" ' +
        'aria-labelledby="' + dialogTitleId + '"' +
        'aria-describedby="' + dialogContentId + '">' +
      '<div class="modal-dialog modal-lg" role="document">' +
        '<div class="modal-content">' +
          '<div class="modal-header">' +
            '<h4 class="modal-title" id="' + dialogTitleId + '"><h4>' +
          '</div>' +
          '<div class="modal-body" id="' + dialogContentId + '">' +
            '<form novalidate></form>' +
          '</div>' +
          '<div class="modal-footer text-right">' +
            '<button type="button" class="btn btn-primary"></button>' +
          '</div>' +
        '</div>' +
      '</div>' +
    '</div>')

  /**
   * Display a login screen
   */
  function showLogin (data) {
    exports.utils.toggleShim($('body'), false)
    dialogContainer.find('#' + dialogTitleId).html(data.title || 'Login')
    dialogContainer.find('button').html((data.btnLabel || 'Login'))
    const formEl = dialogContainer.find('form')
    data.inputs.forEach(input => {
      const inputId = exports.utils.randomId('examinr-login-')
      const invalidFeedbackId = exports.utils.randomId('examinr-login-invalid-')
      formEl.append(
        '<div class="form-group">' +
          '<label for="' + inputId + '">' + (input.label || 'Missing label') + '</label>' +
          '<input type="' + (input.type || 'text') + '" class="form-control" name="' + (input.name || inputId) + '" id="' + inputId + '" placeholder="' + (input.label || '') + '" required>' +
          '<div class="invalid-feedback" id="' + invalidFeedbackId + '">' +
            (input.emptyError || 'This field cannot be empty!') +
          '</div>' +
        '</div>')
    })

    dialogContainer.prependTo(document.body).modal({
      keyboard: false,
      backdrop: 'static',
      show: true
    })
    dialogContainer.find('input').keypress(function (event) {
      if (event.which === kEnterKey) {
        dialogContainer.find('button').click()
      }
    })
    dialogContainer.find('button').click(function (event) {
      let allOk = true
      dialogContainer.find('.alert').remove()
      const values = dialogContainer.find('input').map(function () {
        const el = $(this)
        const val = el.val()
        if (!val || val.length < 1) {
          allOk = false
          const invalidFeedbackId = exports.utils.randomId('examinr-login-invalid-')
          el.addClass('is-invalid')
            .attr('aria-describedby', invalidFeedbackId)
            .next().show()
        } else if (el.hasClass('is-invalid')) {
          el.removeClass('is-invalid')
            .removeAttr('aria-describedby')
            .next().hide()
        }
        return {
          name: el.attr('name'),
          value: el.val()
        }
      }).get()
      if (allOk) {
        exports.utils.toggleShim($('body'), true)
        Shiny.setInputValue('__.examinr.__-login', { inputs: values }, { priority: 'event' })
      }
      event.stopImmediatePropagation()
    })
  }

  Shiny.addCustomMessageHandler('__.examinr.__-loginscreen', showLogin)
  Shiny.addCustomMessageHandler('__.examinr.__-login', function (data) {
    if (data.status === true) {
      dialogContainer.modal('hide').remove()
    } else if (data.error) {
      exports.utils.toggleShim($('body'), false)
      const errorMsg = $('<div class="alert alert-danger">' + data.error + '</div>')
      if (data.errorTitle) {
        errorMsg.prepend('<strong>' + data.errorTitle + '</strong><hr class="mt-2 mb-2" />')
      }
      dialogContainer.find('.modal-body').append(errorMsg)
    }
  })

  return {
    showLogin: showLogin
  }
}())
