<%= '<% require_asset "preloader/#{Rails.env}" %'+'>' %>

bootstrap = ->
  $('#preloader').slideUp ->
    location.hash = '!/' if !location.hash
    Joosy.Application.initialize('#application')

window.onload = ->
  Preloader.force    = false
  Preloader.complete = bootstrap
  Preloader.start    = -> document.getElementById('preloader').style.display = 'block'
  Preloader.progress = (percent) -> document.getElementById('percents').innerHTML = percent + '%'

  Preloader.load window.preload.libraries