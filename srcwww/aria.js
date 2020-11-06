exports.aria = (function () {
  'use strict'

  function generateRandomId (prefix) {
    if (!prefix) {
      prefix = 'aria-el-'
    }
    return prefix + Math.random().toString(36).slice(2)
  }

  function getOrMakeId (el) {
    if (el.attr('id')) {
      return el.attr('id')
    }
    const newId = generateRandomId()
    el.attr('id', newId)
    return newId
  }

  function associate (ariaAttribute, target, ref) {
    const refId = getOrMakeId(ref)
    target.attr('aria-' + ariaAttribute, refId)
  }

  return {
    randomId: generateRandomId,
    associate: associate,
    labelledBy: function (el, labelEl) {
      associate('labelledby', el, labelEl)
    },
    describedBy: function (el, labelEl) {
      associate('describedby', el, labelEl)
    },
  }
}())
