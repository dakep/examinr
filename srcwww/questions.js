exports.questions = (function () {
  'use strict'

  const arrowKeyUp = 38
  const arrowKeyDown = 40

  function preventDefault (e) {
    e.preventDefault()
  }

  function disableScrollOnNumberInput () {
    const numberInputs = $('input[type=number]')
    numberInputs.on('focus', function () {
      $(this).on('wheel.disableScrollEvent', preventDefault)
        .on('keydown.disableScrollEvent', function (e) {
          if (e.which === arrowKeyDown || e.which === arrowKeyUp) {
            e.preventDefault()
          }
        })
    }).on('blur', function () {
      $(this).off('.disableScrollEvent')
    })
  }

  $(function () {
    disableScrollOnNumberInput()
  })

  return {}
}())
