// const $ = require('jquery')
const accessibility = require('./accessibility')
const attempt = require('./attempt')
const autocomplete = require('./autocomplete')
const exercises = require('./exercises')
const login = require('./login')
const sections = require('./section_navigation')
const status = require('./status')
const utils = require('./utils')

require('./feedback')
require('./grading')

$(function () {
  utils.init()
  status.init()
  accessibility.init()
  login.init()
  attempt.init()
  exercises.init()
  autocomplete.init()
  sections.init()

  window.Exam = {
    utils: utils
  }
})

