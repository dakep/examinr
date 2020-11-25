exports.feedback = (function () {
  'use strict'

  const correctIcon = '<svg aria-label="correct" class="examinr-feedback-annotation" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zm-3.97-3.03a.75.75 0 0 0-1.08.022L7.477 9.417 5.384 7.323a.75.75 0 0 0-1.06 1.06L6.97 11.03a.75.75 0 0 0 1.079-.02l3.992-4.99a.75.75 0 0 0-.01-1.05z"/></svg>'

  const incorrectIcon = '<svg aria-label="incorrect" class="examinr-feedback-annotation" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0zM5.354 4.646a.5.5 0 1 0-.708.708L7.293 8l-2.647 2.646a.5.5 0 0 0 .708.708L8 8.707l2.646 2.647a.5.5 0 0 0 .708-.708L8.707 8l2.647-2.646a.5.5 0 0 0-.708-.708L8 7.293 5.354 4.646z"/></svg>'

  const addCommentLabel = 'Add comment'
  const removeCommentLabel = 'Remove comment'

  const numFormat = window.Intl.NumberFormat(undefined, {
    signDisplay: 'never',
    style: 'decimal',
    minimumSignificantDigits: 1,
    maximumSignificantDigits: 3
  })

  const feedbackRenderer = []
  const shinyRenderDelay = 250
  const saveFeedbackDelay = 250
  const attemptSelectorId = exports.utils.randomId('attempt-sel')
  const userSelectorId = exports.utils.randomId('user-sel')
  let currentAttemptId
  let centerEl

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

    // Check if the selected attempt is finished, otherwise add a visual feedback
    if (!sel.children('option').filter(':selected').data('finishedat')) {
      sel.addClass('is-not-finished')
    } else {
      sel.removeClass('is-not-finished')
    }
  }

  function userChanged () {
    const sel = $(this)
    exports.utils.toggleShim($('body'), true)
    // update the input value for the autocomplete input
    Shiny.setInputValue('__.examinr.__-gradingUserSel', sel.val())
  }

  function updateAttemptSelector (attempts, current) {
    const sel = $('#' + attemptSelectorId)
    if (sel.length > 0 && attempts && attempts.length > 0) {
      const options = attempts.map(at => (
        '<option value="' + at.id + '" data-finishedat="' + (at.finishedAt || '') + '">' +
          (at.finishedAt ? exports.utils.formatDate(at.finishedAt * 1000)
            : 'Unfinished (started at ' + exports.utils.formatDate(at.startedAt * 1000) + ')') +
        '</option>'
      )).join('')

      sel.html(options)
        .prop('disabled', attempts.length < 2)
        .removeClass('is-not-finished')

      if (current) {
        if (current.id) {
          sel.val(current.id)
        }
        if (!current.finishedAt) {
          sel.addClass('is-not-finished')
        }
      }
    } else {
      sel.prop('disabled', true)
    }
  }

  /**
   * Render feedback data
   */
  Shiny.addCustomMessageHandler('__.examinr.__-feedback', function (data) {
    exports.utils.toggleShim($('body'), false)
    exports.status.resetMessages()

    data.grading = (data.grading === true)
    if (!centerEl) {
      $('.examinr-section-next').remove()
      $('main').show()
      exports.sections.showAll()

      exports.status.append('<div class="input-group input-group-sm">' +
            '<div class="input-group-prepend">' +
              '<label class="input-group-text" for="' + attemptSelectorId + '">' +
                exports.status.getMessage('feedback').attemptLabel +
              '</label>' +
            '</div>' +
            '<select class="custom-select" id="' + attemptSelectorId + '"></select>' +
          '</div>', 'right')
        .children('#' + attemptSelectorId)
        .change(attemptChanged)

      if (data.grading) {
        centerEl = exports.status.append('<div class="input-group input-group-sm">' +
            '<div class="input-group-prepend">' +
              '<button class="btn btn-secondary" type="button">' +
                '<span aria-hidden="true">&lt;</span>' +
                '<span class="sr-only">Previous student</span>' +
              '</button>' +
              '<label class="input-group-text" for="' + userSelectorId + '">' +
                'User' +
              '</label>' +
            '</div>' +
            '<select class="custom-select" id="' + userSelectorId + '" disabled></select>' +
            '<div class="input-group-append">' +
              '<button class="btn btn-secondary" type="button">' +
                '<span aria-hidden="true">&gt;</span>' +
                '<span class="sr-only">Next Student</span>' +
              '</button>' +
            '</div>' +
          '</div>')

        if (data.users && data.users.length > 0) {
          const userSel = centerEl.children('#' + userSelectorId)
          userSel.prop('disabled', false)
            .change(userChanged)
            .append(data.users.map(user => (
              '<option value="' + user.id + '">' + (user.displayName || user.id) + '</option>'
            )).join(''))
        }
      } else {
        centerEl = exports.status.append('<span></span>')
      }
    }
    updateAttemptSelector(data.allAttempts, data.attempt)
    if (data.attempt) {
      currentAttemptId = data.attempt.id
      if (data.attempt.userId) {
        centerEl.find('select').val(data.attempt.userId)
      }
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
          feedbackRenderer[i].callback(question, feedbackMap[label] || {}, data.grading)
          if (label in feedbackMap) {
            totalPoints += (feedbackMap[label].maxPoints || 0)
            if (feedbackMap[label].points || feedbackMap[label].points === 0) {
              awardedPoints += feedbackMap[label].points
            } else {
              awardedPoints = NaN
            }
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

    if (!data.grading) {
      centerEl.html(exports.status.getMessage('feedback').status
        .replace('{awarded_points}', awardedPoints)
        .replace('{total_points}', totalPoints))
    }

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

  function saveFeedbackCallback (qid) {
    return exports.utils.debounce(function (feedback) {
      if (currentAttemptId) {
        Shiny.setInputValue('__.examinr.__-saveFeedback', {
          attempt: currentAttemptId,
          qid: qid,
          points: feedback.points,
          comment: feedback.comment,
          maxPoints: feedback.maxPoints
        })
      }
    }, saveFeedbackDelay)
  }

  function pointsChanged (event) {
    const input = $(this)
    const question = input.parents('.examinr-question')
    const feedback = question.data('feedback')
    const numVal = parseFloat(input.val())
    input.val(numVal)
    if (!isNaN(numVal)) {
      feedback.points = numVal
      question.data('feedback', feedback)
      event.data.saveFeedback(feedback)
    }
  }

  function commentChanged (event) {
    const input = $(this)
    const question = input.parents('.examinr-question')
    const feedback = question.data('feedback')
    feedback.comment = input.val()
    event.data.saveFeedback(feedback)
    question.data('feedback', feedback)
  }

  function toggleCommentVisible (event) {
    const toggleBtn = $(this)
    const question = toggleBtn.parents('.examinr-question')
    const feedback = question.data('feedback')
    const commentsInputGroup = question.find('.examinr-grading-comment')
    const commentsBtn = $(this)
    if (commentsInputGroup.filter(':visible').length > 0) {
      // Hide the comment box and remove the comment
      commentsInputGroup.hide()
      commentsBtn.find('.btn-label').html('+')
      commentsBtn.find('.sr-only').text(addCommentLabel)
      if (feedback.comment) {
        feedback.hiddenComment = feedback.comment
        feedback.comment = null
        event.data.saveFeedback(feedback)
      }
    } else {
      // Show the comment box and add the previously deleted comment
      commentsInputGroup.show()
      commentsBtn.find('.btn-label').html('&times;')
      commentsBtn.find('.sr-only').text(removeCommentLabel)
      if (feedback.hiddenComment) {
        commentsInputGroup.find('textarea').val(feedback.hiddenComment).focus()
        feedback.hiddenComment = null
      }
    }
    question.data('feedback', feedback)
  }

  /**
   * Add default feedback elements to a question.
   * This renders the points (either as badge for feedback or as input element for grading) and appends
   * the solution and any comments in the footer.
   *
   * @param {jQuery} question question element
   * @param {Object} feedback feedback object
   * @param {boolean} grading render for grading
   */
  function renderDefaultFeedback (question, feedback, grading) {
    const footer = questionFooter(question)
    // remove all previous feedback
    footer.find('.examinr-grading-feedback').remove()

    // Append the solution to the footer
    if (feedback.solution) {
      footer.append('<div class="examinr-grading-feedback">' +
      '<h6>' + exports.status.getMessage('feedback').solutionLabel + '</h6>' +
      '<div>' + feedback.solution + '</div>' +
      '</div>')
    }

    if (grading) {
      if (question.find('.examinr-grading-points').length === 0) {
        const badge = question.find('.examinr-points')
        const pointsInputId = exports.utils.randomId('examinr-pts-')
        const commentInputId = exports.utils.randomId('examinr-comment-')

        badge.parent()
          .addClass('clearfix')
          .append('<div class="input-group input-group-sm examinr-points examinr-grading-points">' +
              '<label class="sr-only" for="' + pointsInputId + '">Points</label>' +
              '<input type="number" class="form-control" id="' + pointsInputId + '" step="any" required ' +
                'max="' + (2 * feedback.maxPoints) + '" />' +
              '<div class="input-group-append">' +
                '<span class="input-group-text">' +
                  '<span class="sr-only"> out of </span>' +
                  '<span class="examinr-points-outof">' + badge.text() + '</span>' +
                '</span>' +
                '<button type="button" class="btn btn-secondary">' +
                  '<span class="btn-label" aria-hidden="true">' + (feedback.comment ? '&times;' : '+') + '</span>' +
                  '<span class="sr-only">' + (feedback.comment ? removeCommentLabel : addCommentLabel) + '</span>' +
                '</button>' +
              '</div>' +
            '</div>')

        badge.remove()

        footer.append('<div class="input-group examinr-grading-comment">' +
            '<div class="input-group-prepend">' +
              '<label class="input-group-text" for="' + commentInputId + '">Comment</label>' +
            '</div>' +
            '<textarea class="form-control" id="' + commentInputId + '"></textarea>' +
          '</div>')

        const saveFeedbackDebounced = { saveFeedback: saveFeedbackCallback(feedback.qid) }

        question.find('#' + pointsInputId).on('change', saveFeedbackDebounced, pointsChanged)
        question.find('#' + commentInputId).on('change', saveFeedbackDebounced, commentChanged)
        question.find('.examinr-grading-points button').on('click', saveFeedbackDebounced, toggleCommentVisible)
        if (!feedback.comment) {
          footer.find('.examinr-grading-comment').hide()
        }
      }

      question.find('.examinr-grading-points input').val(feedback.points)
      question.data('feedback', feedback)
    } else {
      const badge = question.find('.examinr-points')
      // Render the awarded points in the badge
      if (badge.find('.examinr-points-awarded').length === 0) {
        const outof = badge.text()
        badge.html('<span class="examinr-points-awarded"></span><span class="sr-only"> out of </span> ' +
                   '<span class="examinr-points-outof">' + outof + '</span>')
      }

      if (feedback.points || feedback.points === 0) {
        const context = feedback.points <= 0 ? 'danger'
          : (feedback.points >= feedback.maxPoints ? 'success' : 'secondary')

        badge.removeClass('badge-secondary badge-info badge-success badge-danger')
          .addClass('badge-' + context)
          .find('.examinr-points-awarded')
          .addClass('lead')
          .text(feedback.points)
      } else {
        badge.removeClass('badge-secondary badge-info badge-success badge-danger')
          .addClass('badge-info')
          .find('.examinr-points-awarded')
          .removeClass('lead')
          .html('&mdash;')
      }
    }

    if (grading) {
      if (feedback.comment) {
        question.find('.examinr-grading-points .btn .btn-label').html('&times;')
        question.find('.examinr-grading-points .btn .sr-only').text(removeCommentLabel)
        footer.find('.examinr-grading-comment').show()
          .find('textarea').val(feedback.comment)
      } else {
        question.find('.examinr-grading-points .btn .btn-label').html('+')
        question.find('.examinr-grading-points .btn .sr-only').text(addCommentLabel)
        footer.find('.examinr-grading-comment').hide()
          .find('textarea').val('')
      }
    } else if (feedback.comment) {
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
    callback: function (question, feedback, grading) {
      renderDefaultFeedback(question, feedback, grading)

      question.find('.shiny-input-container input,.shiny-input-container textarea')
        .prop('readonly', true)
        .val(feedback.answer || '')
    }
  })

  // Default feedback renderer for built-in questions created by `mc_question()`
  feedbackRenderer.push({
    selector: '.examinr-q-mcquestion',
    callback: function (question, feedback, grading) {
      const solution = feedback.solution
      feedback.solution = null
      renderDefaultFeedback(question, feedback, grading)

      runAfterUpdate(question, function () {
        // reset old feedback
        question.find('.examinr-feedback-annotation').remove()
        question.find('.shiny-input-container label').removeAttr('class')

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
    callback: function (question, feedback, grading) {
      const footer = questionFooter(question)
      if (grading && footer.children('hr').length === 0) {
        footer.append('<hr class="mb-3 mt-3" />')
      }

      const solution = feedback.solution
      feedback.solution = null
      renderDefaultFeedback(question, feedback, grading, grading)

      const editor = question.data('editor')
      if (editor) {
        if (!grading) {
          editor.setReadOnly(true)
        }
        editor.getSession().setValue(feedback.answer || '\n')
      }

      if (!grading) {
        footer.find('.examinr-run-button').remove()
        footer.find('.examinr-exercise-status').remove()
      }

      footer.removeClass('alert alert-danger text-muted')
      if (solution) {
        footer.append('<div class="examinr-grading-feedback">' +
            '<h6>' + exports.status.getMessage('feedback').solutionLabel + '</h6>' +
            '<pre><code>' + solution + '</code></pre>' +
          '</div>')
      }
    }
  })

  return {
    /**
     * Add default feedback elements to a question.
     * This renders the points (either as badge for feedback or as input element for grading) and appends
     * the solution and any comments in the footer.
     *
     * @param {jQuery} question question element
     * @param {Object} feedback feedback object
     * @param {boolean} grading true if rendering for grading and false for regular (immutable) feedback
     */
    renderDefaultFeedback: renderDefaultFeedback,

    /**
     * Register a function to render the feedback for all questions matching the given selector.
     * If two functions match the same question, the function registered *later* will be called.
     *
     * @param {string} selector a valid jQuery selector query
     * @param {function} func callback function which will be called with two arguments:
     *   {jQuery} question the question element
     *   {Object} the feedback object
     *   {boolean} true if rendering for grading and false for regular (immutable) feedback
     */
    registerFeedbackRenderer: function (selector, func) {
      feedbackRenderer.unshift({ selector: selector, callback: func })
    }
  }
}())
