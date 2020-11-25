exports.grading = (function () {
  'use strict'

  function updateGrading (question, gradingData) {
    // Save locally
    question.data('gradingData', gradingData)

    // And remotely
    if (!gradingData.feedbackShown) {
      gradingData.feedback = null
    }
    Shiny.setInputValue('__.examinr.__-gradingData', gradingData)
  }

  function toggleFeedback () {
    const btn = $(this)
    const question = btn.parents('.examinr-question')
    const gradingData = question.data('grading') || {}
    if (gradingData.feedbackShown) {
      btn.children('.btn-label').text('+')
      btn.children('.sr-only').text('Add comment')
      question.data('feedbackShown', false)
        .find('.examinr-grading-feedback')
        .remove()
    } else {
      btn.children('.btn-label').html('&times;')
      btn.children('.sr-only').text('Remove comment')
      let footer = question.find('.card-footer')
      if (footer.length === 0) {
        footer = $('<div class="card-footer">')
        footer.appendTo(question.hasClass('card') ? question : question.find('.card'))
      }
      question.data('feedbackShown', true)

      const commentInputId = exports.utils.randomId('comment-')

      footer.append(
        '<div class="input-group examinr-grading-feedback">' +
          '<div class="input-group-prepend">' +
            '<label class="input-group-text" for="' + commentInputId + '">' +
              exports.status.getMessage('feedback').commentLabel +
            '</label>' +
          '</div>' +
          '<textarea class="form-control" id="' + commentInputId + '">' +
            (gradingData.feedback || '') +
          '</textarea>' +
        '</div>')

      question.find('.examinr-grading-feedback textarea').on('change', function () {
        const gradingData = question.data('grading') || {}
        gradingData.feedback = $(this).val()
        updateGrading(question, gradingData)
      })
    }
    gradingData.feedbackShown = !gradingData.feedbackShown
    updateGrading(question, gradingData)
  }

  function prepareQuestion () {
    const question = $(this)
    const gradingData = question.data('grading') || {}
    const pointsEl = question.find('.examinr-points')
    const container = pointsEl.parent()
    const placeholder = pointsEl.remove().text()

    if (!gradingData.maxPoints) {
      gradingData.maxPoints = parseFloat(question.data('maxPoints')) || 1
    }

    const pointsInput = $('<input type="number" class="form-control" />')
      .attr('max', gradingData.maxPoints)
      .attr('id', exports.utils.randomId())

    const feedbackBtn = gradingData.feedbackShown ? '&times;' : '+'
    const feedbackLabel = gradingData.feedbackShown ? 'Remove feedback' : 'Add feedback'

    container.addClass('clearfix')
      .append('<div class="input-group input-group-sm examinr-points">' +
        '<label class="sr-only" for="' + pointsInput.attr('id') + '">Points</label>' +
        '<div class="input-group-append">' +
          '<span class="input-group-text">/ ' + placeholder + '</span>' +
          '<button type="button" class="btn btn-secondary">' +
            '<span class="btn-label" aria-hidden="true">' + feedbackBtn + '</span>' +
            '<span class="sr-only">' + feedbackLabel + '</span>' +
          '</button>' +
        '</div>' +
      '</div>')
      .find('.input-group')
      .prepend(pointsInput)

    question.data('grading', gradingData)
    container.find('.btn').click(toggleFeedback)
    exports.utils.disableNumberInputDefaults(pointsInput)
  }

  function startGrading () {
    exports.status.disableProgress()
    const statusContainer = exports.status.statusContainer()

    const studentNameInputId = exports.utils.randomId('student-name')
    const attemptInputId = exports.utils.randomId('attempt')

    statusContainer.append(
      '<form class="form-inline examinr-grading-attempt">' +
        '<div class="input-group input-group-sm">' +
          '<div class="input-group-prepend">' +
            '<button class="btn btn-secondary" type="button">' +
              '<span aria-hidden="true">&lt;</span>' +
              '<span class="sr-only">Previous student</span>' +
            '</button>' +
          '</div>' +
          '<label class="sr-only" for="' + studentNameInputId + '">Student</label>' +
          '<input type="text" id="' + studentNameInputId + '" class="form-control" placeholder="Student" />' +
          '<span class="input-group-append">' +
            '<button class="btn btn-secondary" type="button">' +
              '<span aria-hidden="true">&gt;</span>' +
              '<span class="sr-only">Next Student</span>' +
            '</button>' +
          '</span>' +
        '</div>' +
        '<div class="input-group input-group-sm">' +
          '<label class="sr-only" for="' + attemptInputId + '">Attempt</label>' +
          '<select id="' + attemptInputId + '" class="form-control" disabled></select>' +
        '</div>' +
      '</form>'
    )

    exports.status.fixMainOffset()

    // Prepare the questions
    $('.examinr-question').each(prepareQuestion)
  }

  return {
    startGrading: startGrading
  }
}())
