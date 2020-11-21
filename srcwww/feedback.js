exports.feedback = (function () {
  'use strict'

  const correctIcon = '<svg aria-label="correct" class="examinr-feedback-annotation" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zm-3.97-3.03a.75.75 0 0 0-1.08.022L7.477 9.417 5.384 7.323a.75.75 0 0 0-1.06 1.06L6.97 11.03a.75.75 0 0 0 1.079-.02l3.992-4.99a.75.75 0 0 0-.01-1.05z"/></svg>'

  const incorrectIcon = '<svg aria-label="incorrect" class="examinr-feedback-annotation" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zM5.354 4.646a.5.5 0 1 0-.708.708L7.293 8l-2.647 2.646a.5.5 0 0 0 .708.708L8 8.707l2.646 2.647a.5.5 0 0 0 .708-.708L8.707 8l2.647-2.646a.5.5 0 0 0-.708-.708L8 7.293 5.354 4.646z"/></svg>'

  const numFormat = window.Intl.NumberFormat(undefined, {
    signDisplay: 'never',
    style: 'decimal',
    minimumSignificantDigits: 1,
    maximumSignificantDigits: 3
  })

  const feedbackRenderer = []
  const shinyRenderDelay = 250
  let pointsEl

  function runAfterUpdate (input, func) {
    func()
    input.one('shiny:updateinput', function () {
      window.setTimeout(func, shinyRenderDelay)
    })
  }

  function attemptChanged () {
    const sel = $(this)
    exports.utils.toggleShim($('body'), true)
    // update the input value for the autocomplete input
    Shiny.setInputValue('__.examinr.__-attemptSel', sel.val())
  }

  /**
   * Render feedback data
   */
  Shiny.addCustomMessageHandler('__.examinr.__-feedback', function (data) {
    exports.utils.toggleShim($('body'), false)
    if (!pointsEl) {
      $('.examinr-section-next').remove()
      $('main').show()
      exports.sections.showAll()

      let options = ''
      let disabled = 'disabled'

      if (data.otherAttempts && data.otherAttempts.length > 0) {
        options = data.otherAttempts.map(at => (
          '<option value="' + at.id + '">' + exports.utils.formatDate(at.finishedAt * 1000) + '</option>'
        )).join('')

        if (data.otherAttempts.length > 1) {
          disabled = ''
        }
      }

      const selId = exports.utils.randomId('attempt-sel')
      exports.status.append('<div class="input-group input-group-sm">' +
            '<div class="input-group-prepend">' +
              '<label class="input-group-text" for="' + selId + '">' +
                exports.status.getMessage('feedback').attemptLabel +
              '</label>' +
            '</div>' +
            '<select class="custom-select" ' + disabled + ' id="' + selId + '">' +
              options +
            '</select>' +
          '</div>', 'right')
        .children('#' + selId)
        .val(data.attempt.id)
        .change(attemptChanged)

      pointsEl = exports.status.append('<span></span>')
    }

    // turn feedback array into a map
    const feedbackMap = Object.fromEntries(data.feedback.map(function (feedback) {
      return [feedback.qid, feedback]
    }))

    let totalPoints = 0
    let awardedPoints = 0

    // Render feedback for text (or numeric) questions
    $('.examinr-question').each(function () {
      const question = $(this)
      const label = question.data('questionlabel')
      for (let i = 0, end = feedbackRenderer.length; i < end; i++) {
        if (question.filter(feedbackRenderer[i].selector).length > 0) {
          feedbackRenderer[i].callback(question, feedbackMap[label] || {})
          if (label in feedbackMap) {
            totalPoints += (feedbackMap[label].maxPoints || 0)
            awardedPoints += (feedbackMap[label].points || NaN)
            delete feedbackMap[label]
          } else {
            totalPoints += (question.data('maxpoints') || 0)
            awardedPoints = NaN
          }
          return true
        }
      }
      window.console.warn('No feedback renderer for question ' + label)
    })

    if (isNaN(awardedPoints)) {
      awardedPoints = '&mdash;'
    }

    pointsEl.html(exports.status.getMessage('feedback').status
      .replace('{awarded_points}', awardedPoints)
      .replace('{total_points}', totalPoints))

    exports.status.fixMainOffset()
  })

  function questionFooter (question) {
    const card = question.hasClass('card') ? question : question.find('.card')
    const footer = card.find('.card-footer')
    if (footer.length === 0) {
      return $('<div class="card-footer">').appendTo(card)
    }
    return footer
  }

  function renderDefaultFeedback (question, feedback) {
    const badge = question.find('.examinr-points')
    if (badge.find('.awarded').length === 0) {
      badge.prepend('<span class="awarded"></span><span class="sr-only"> out of </span>')
    }

    if (feedback.points || feedback.points === 0) {
      const context = feedback.points <= 0 ? 'danger'
        : (feedback.points >= feedback.maxPoints ? 'success' : 'secondary')

      badge.removeClass('badge-secondary badge-info badge-success badge-danger')
        .addClass('badge-' + context)
        .find('.awarded')
        .addClass('lead')
        .text(feedback.points)
    } else {
      badge.removeClass('badge-secondary badge-info badge-success badge-danger')
        .addClass('badge-info')
        .find('.awarded')
        .removeClass('lead')
        .html('&mdash;')
    }

    // remove all previous feedback
    question.find('.examinr-grading-feedback').remove()
    const footer = questionFooter(question)

    if (feedback.solution) {
      footer.append('<div class="examinr-grading-feedback">' +
          '<h6>' + exports.status.getMessage('feedback').solutionLabel + '</h6>' +
          '<div>' + feedback.solution + '</div>' +
        '</div>')
    }

    if (feedback.comment) {
      footer.append('<div class="text-muted examinr-grading-feedback">' +
        '<h6>' + exports.status.getMessage('feedback').commentLabel + '</h6>' +
        '<div>' + feedback.comment + '</div>' +
      '</div>')
    }

    exports.utils.renderMathJax(footer)
  }

  // Default feedback renderer for built-in questions created by `text_question()`
  feedbackRenderer.push({
    selector: '.examinr-q-textquestion',
    callback: function (question, feedback) {
      renderDefaultFeedback(question, feedback)

      question.find('.shiny-input-container input,.shiny-input-container textarea')
        .prop('readonly', true)
        .val(feedback.answer || '')
    }
  })

  // Default feedback renderer for built-in questions created by `mc_question()`
  feedbackRenderer.push({
    selector: '.examinr-q-mcquestion',
    callback: function (question, feedback) {
      const solution = feedback.solution
      feedback.solution = null
      renderDefaultFeedback(question, feedback)

      runAfterUpdate(question, function () {
        // reset old feedback
        question.find('.examinr-feedback-annotation').remove()
        question.find('label').removeAttr('class')

        // display new feedback
        const cbs = question.find('input[type=checkbox],input[type=radio]')
        cbs.prop('disabled', true).prop('checked', false)

        if (feedback.answer) {
          feedback.answer.forEach(sel => {
            if (sel.weight) {
              const context = sel.weight > 0 ? 'success' : 'danger'
              const weightStr = (sel.weight > 0 ? '+' : '&minus;') + numFormat.format(sel.weight)
              cbs.filter('[value="' + sel.value + '"]')
                .prop('checked', true)
                .parent()
                .append('<span class="examinr-feedback-annotation badge badge-pill badge-' + context + '">' +
                  weightStr + '</span>')
            }
          })
        }

        if (solution) {
          const correctValues = new Set(solution)

          cbs.each(function () {
            const cb = $(this)
            const label = cb.parent()
            if (cb.prop('checked')) {
              if (correctValues.has(cb.val())) {
                label.addClass('text-success').prepend(correctIcon)
              } else {
                label.addClass('text-danger').prepend(incorrectIcon)
              }
            } else {
              if (correctValues.has(cb.val())) {
                label.addClass('text-danger').prepend(incorrectIcon)
              } else {
                label.addClass('text-muted').prepend(correctIcon)
              }
            }
          })
        }
      })
    }
  })

  // Default feedback renderer for built-in exercise questions.
  feedbackRenderer.push({
    selector: '.examinr-q-exercise',
    callback: function (question, feedback) {
      const solution = feedback.solution
      feedback.solution = null
      renderDefaultFeedback(question, feedback)

      const editor = question.data('editor')
      if (editor) {
        editor.setReadOnly(true)
        editor.getSession().setValue(feedback.answer || '\n')
      }
      question.find('.examinr-run-button').remove()
      question.find('.examinr-exercise-status').remove()
      const footer = questionFooter(question)

      footer.removeClass('alert alert-danger text-muted')
      if (solution) {
        questionFooter(question)
          .append('<div class="examinr-grading-feedback">' +
            '<h6>' + exports.status.getMessage('feedback').solutionLabel + '</h6>' +
            '<pre><code>' + solution + '</code></pre>' +
          '</div>')
      }
    }
  })

  return {
    /**
     * Register a function to render the feedback for all questions matching the given selector.
     * If two functions match the same question, the function registered *later* will be called.
     *
     * @param {string} selector a valid jQuery selector query
     * @param {function} func callback function which will be called with two arguments:
     *   {jQuery} question the question element
     *   {Object} the feedback object
     */
    registerFeedbackRenderer: function (selector, func) {
      feedbackRenderer.unshift({ selector: selector, callback: func })
    }
  }
}())
