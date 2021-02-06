exports.question = (function () {
  'use strict'

  const kDebounceEditorChange = 250
  const kDelaySetMcQuestion = 250

  function onMcChange (event, extra) {
    if (extra && extra.autofill) {
      return
    }
    // Only handle the change if it is triggered by a checkbox or radio button.
    if ($(event.target).filter('input').length) {
      const question = $(event.delegateTarget)
      const store = {
        id: question.attr('id'),
        val: question.find(':checked').map((ind, cb) => cb.value).get()
      }
      exports.utils.attemptStorage.setItem('qinput_mc_' + store.id, store)
    }
  }

  function loadFromAttemptStorage () {
    // Recover input values from the browser-local attempt storage
    exports.utils.attemptStorage.keys(function (key) {
      if (key.startsWith('qinput_text_')) {
        const store = exports.utils.attemptStorage.getItem(key)
        // window.console.debug('Setting text question with id ' + store.id + ' to "' + store.val + '"')
        $('#' + store.id).val(store.val).trigger('change', [{ autofill: true }])
      } else if (key.startsWith('qinput_mc_')) {
        const store = exports.utils.attemptStorage.getItem(key)
        const question = $('#' + store.id)
        if (store.val && store.val.length) {
          // The MC question is empty at first and will be updated by the server-side code.
          // The event is fired *before* the input is updated, but the items must be checked only after the input
          // has finished updating. Delay checking the items until all of them are actually present.
          question.one('shiny:updateinput', exports.utils.autoRetry(function () {
            // window.console.debug('Setting MC question with id ' + store.id + ' to [' + store.val.join(', ') + ']')
            let allItemsPresent = true
            store.val.forEach(value => {
              const inputEl = question.find('input[value="' + value + '"]')
              if (inputEl.length === 1) {
                inputEl.prop('checked', true).trigger('change', [{ autofill: true }])
              } else {
                allItemsPresent = false
              }
            })
            return allItemsPresent
          }, kDelaySetMcQuestion, true))
        }
      } else if (key.startsWith('qinput_exercise_')) {
        const store = exports.utils.attemptStorage.getItem(key)
        // window.console.debug('Setting code editor for question ' + store.qlabel + ' to\n```' + store.val + '\n```')
        const exercise = $('.examinr-question.examinr-exercise[data-questionlabel="' + store.qlabel + '"]')
        const editor = exercise.data('editor')
        if (editor) {
          editor.getSession().setValue(store.val)
          editor.resize(true)
        }
      }
    })

    // Monitor changes to inputs and save them to the browser-local attempt storage.
    $('.examinr-question .shiny-bound-input.shiny-input-checkboxgroup').change(onMcChange)
    $('.examinr-question .shiny-bound-input.shiny-input-radiogroup').change(onMcChange)
    $('.examinr-question input.shiny-bound-input, .examinr-question textarea.shiny-bound-input').change(function (event, extra) {
      if (extra && extra.autofill) {
        return
      }

      const question = $(this)
      const store = {
        id: question.attr('id'),
        val: question.val()
      }
      if (store.val || store.val === '0') {
        // window.console.debug('Storing text input for id ' + store.id + ': "' + store.val + '"')
        exports.utils.attemptStorage.setItem('qinput_text_' + store.id, store)
      } else {
        // window.console.debug('Deleting text input for id ' + store.id + ' from storage.')
        exports.utils.attemptStorage.removeItem('qinput_text_' + store.id)
      }
    })
    $('.examinr-question.examinr-exercise.shiny-bound-input').each(function () {
      const exercise = $(this)
      const editor = exercise.data('editor')
      const store = {
        qlabel: exercise.data('questionlabel'),
        val: null
      }

      const storeEditorValue = function (event) {
        store.val = exercise.data('editor').getSession().getValue()
        if (store.val || store.val === '0') {
          // window.console.debug('Storing code for exercise ' + store.qlabel + ' to\n```' + store.val + '\n```')
          exports.utils.attemptStorage.setItem('qinput_exercise_' + store.qlabel, store)
        } else {
          // window.console.debug('Deleting code for exercise ' + store.qlabel)
          exports.utils.attemptStorage.removeItem('qinput_exercise_' + store.qlabel)
        }
      }

      if (editor) {
        editor.on('change', exports.utils.debounce(storeEditorValue, kDebounceEditorChange, false))
      }
    })
  }

  return {
    restoreFromStorage: loadFromAttemptStorage
  }
}())
