#= require joosy/core/joosy
#= require joosy/core/modules/module
#= require joosy/core/modules/log
#= require joosy/core/modules/events
#= require joosy/core/modules/container
#= require joosy/core/modules/renderer
#= require joosy/core/modules/time_manager
#= require joosy/core/modules/widgets_manager
#= require joosy/core/modules/filters

class Joosy.Page extends Joosy.Module
  @include Joosy.Modules.Log
  @include Joosy.Modules.Events
  @include Joosy.Modules.Container
  @include Joosy.Modules.Renderer
  @include Joosy.Modules.TimeManager
  @include Joosy.Modules.WidgetsManager
  @include Joosy.Modules.Filters

  layout: false
  previous: false
  params: false
  data: false

  @fetch: (callback) ->
    @::__fetch = callback
    
  @fetchSynchronized: (callback) ->
    @::__fetch = (complete) ->
      @synchronize (context) ->
        context.after -> complete()
        callback.call(this, context)

  @scroll: (element, options={}) ->
    @::__scrollElement = element
    @::__scrollSpeed = options.speed || 500
    @::__scrollMargin = options.margin || 0
    
  @title: (title) ->
    @afterLoad ->
      title = title.apply(this) if Object.isFunction(title)
      @__previousTitle = Joosy.Application.title.text()
      Joosy.Application.title.text(title)
    
    @afterUnload ->
      Joosy.Application.title.text @__previousTitle

  @layout: (layoutClass) ->
    @::__layoutClass = layoutClass

  @beforePaint: (callback) ->
    @::__beforePaint = callback
  @paint: (callback) ->
    @::__paint = callback
  @afterPaint: (callback) ->
    @::__afterPaint = callback
  @erase: (callback) ->
    @::__erase = callback

  constructor: (@params, @previous) ->
    Joosy.Application.loading = true
    
    @__layoutClass ||= ApplicationLayout

    if @__runBeforeLoads @params, @previous
      if !@previous?.layout?.uuid? || @previous?.__layoutClass != @__layoutClass
        @__bootstrapLayout()
      else
        @__bootstrap()

  navigate: (args...) ->
    Joosy.Router.navigate(args...)

  __renderSection: ->
    'pages'

  __fixHeight: ->
    $('html').css 'min-height', $(document).height()
    
  __releaseHeight: ->
    $('html').css 'min-height', ''

  __load: ->
    @refreshElements()
    @__delegateEvents()
    @__setupWidgets()
    @__runAfterLoads @params, @previous
    if @__scrollElement
      scroll = $(@__extractSelector @__scrollElement).offset()?.top + @__scrollMargin
      Joosy.Modules.Log.debugAs @, "Scrolling to #{@__extractSelector @__scrollElement}"
      $('html, body').animate {scrollTop: scroll}, @__scrollSpeed, =>
        if @__scrollSpeed != 0
          @__releaseHeight()
    Joosy.Application.loading = false

    Joosy.Modules.Log.debugAs @, "Page loaded"

  __unload: ->
    @__clearTime()
    @__unloadWidgets()
    @__removeMetamorphs()
    @__runAfterUnloads @params, @previous
    delete @previous

  __callSyncedThrough: (entity, receiver, params, callback) ->
    if entity?[receiver]?
      entity[receiver].apply entity, params.clone().add(callback)
    else
      callback()

  # Boot Sequence:
  #
  # previous::erase  \
  # previous::unload  \
  # beforePaint        \
  #                     > paint
  # fetch             /
  #
  __bootstrap: ->
    Joosy.Modules.Log.debugAs @, "Boostraping page"
    @layout = @previous.layout

    callbacksParams = [@layout.content()]
    
    if @__scrollElement && @__scrollSpeed != 0
     @__fixHeight()

    @wait "stageClear dataReceived", =>
      @__callSyncedThrough this, '__paint', callbacksParams, =>
        # Page HTML
        @swapContainer @layout.content(), @__renderer(@data || {})
        @container = @layout.content()

        # Loading
        @__load()
        
        @layout.content()

    @__callSyncedThrough @previous, '__erase', callbacksParams, =>
      @previous?.__unload()
      @__callSyncedThrough this, '__beforePaint', callbacksParams, =>
        @trigger 'stageClear'

    @__callSyncedThrough this, '__fetch', [], =>
      Joosy.Modules.Log.debugAs @, "Fetch complete"
      @trigger 'dataReceived'

  __bootstrapLayout: ->
    Joosy.Modules.Log.debugAs @, "Boostraping page with layout"
    @layout = new @__layoutClass(@params)

    callbacksParams = [Joosy.Application.content(), this]
    
    if @__scrollElement && @__scrollSpeed != 0
      @__fixHeight()

    @wait "stageClear dataReceived", =>
      @__callSyncedThrough @layout, '__paint', callbacksParams, =>
        # Layout HTML
        data = Joosy.Module.merge {}, @layout.data || {}
        data = Joosy.Module.merge data, yield: => @layout.yield()
        
        @swapContainer Joosy.Application.content(), @layout.__renderer data

        # Page HTML
        @swapContainer @layout.content(), @__renderer(@data || {})
        @container = @layout.content()

        # Loading
        @layout.__load Joosy.Application.content()
        @__load()

        Joosy.Application.content()

    @__callSyncedThrough @previous?.layout, '__erase', callbacksParams, =>
      @previous?.layout?.__unload?()
      @previous?.__unload()
      @__callSyncedThrough @layout, '__beforePaint', callbacksParams, =>
        @trigger 'stageClear'

    @__callSyncedThrough @layout, '__fetch', [], =>
      @__callSyncedThrough this, '__fetch', [], =>
        Joosy.Modules.Log.debugAs @, "Fetch complete"
        @trigger 'dataReceived'
