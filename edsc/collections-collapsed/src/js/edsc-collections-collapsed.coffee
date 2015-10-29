require '../css/collections-collapsed.less'
dom = require 'core/src/dom'
extend = require 'core/src/extend'
events = require 'core/src/events'
async = require 'core/src/async'
domData = ko.utils.domData
domNodeDisposal = ko.utils.domNodeDisposal

sortable = (root, rowClass) ->
    $root = $(root)
    $placeholder = $("<li class=\"sortable-placeholder #{rowClass}\"/>")

    index = null
    $dragging = null

    $root.on 'dragstart.sortable', '> *', (e) ->
      dt = e.originalEvent.dataTransfer;
      dt.effectAllowed = 'move';
      dt.setData('Text', 'dummy');
      $dragging = $(this)
      index = $dragging.index();

    $root.on 'dragend.sortable', '> *', (e) ->
      $dragging.show()
      $placeholder.detach()
      startIndex = index
      endIndex = $dragging.index()
      if startIndex != endIndex
        $root.trigger('sortupdate', startIndex: startIndex, endIndex: endIndex)
      $dragging = null

    $root.on 'drop.sortable', '> *', (e) ->
      e.stopPropagation()
      $placeholder.after($dragging)
      false

    $root.on 'dragover.sortable dragenter.sortable', '> *', (e) ->
      e.preventDefault()
      e.originalEvent.dataTransfer.dropEffect = 'move';
      $dragging.hide().appendTo($root) # appendTo to ensure top margins are ok
      if $placeholder.index() < $(this).index()
        $(this).after($placeholder)
      else
        $(this).before($placeholder)
      false

class KnockoutComponentModel
  @register: (klass, name, template) ->
    ko.components.register name,
      viewModel:
        createViewModel: (params, componentInfo) -> new klass(params, componentInfo)
      template: template

  constructor: (params, componentInfo) ->
    @_root = componentInfo.element
    @params = params
    extend(this, params)

class CollectionsCollapsedModel extends KnockoutComponentModel
  constructor: (params, componentInfo) ->
    super(params, componentInfo)
    @_scrollParent = dom.scrollParent(@_root)
    @_flyouts = []
    if @_scrollParent
      @_scrollParent.addEventListener('scroll', async.throttled => @_alignFlyouts())

  # These methods should be factored out eventually
  toggleVisibleCollection: (args...) => @page.collections.toggleVisibleCollection(args...)
  hasCollection: (args...) => @page.project.hasCollection(args...)
  toggleCollection: (args...) => @page.ui.projectList.toggleCollection(args...)
  accessCollection: (args...) => @page.ui.projectList.loginAndDownloadCollection(args...)
  canQueryCollectionSpatial: (args...) => @page.ui.collectionsList.canQueryCollectionSpatial(args...)
  spatialQuery: (args...) => @page.query.spatial(args...)
  toggleQueryCollectionSpatial: (args...) => @page.ui.collectionsList.toggleQueryCollectionSpatial(args...)
  # End methods to factor out

  _getFlyoutTarget: (e) ->
    target = e.target
    target = target.parentNode until !target || flyout = target.getAttribute('data-flyout')
    target

  toggleFlyout: (context, e) =>
    target = @_getFlyoutTarget(e)
    if domData.get(target, 'flyout') || dom.hasClass(target, 'flyout-visible')
      @hideFlyout(context, e)
      dom.removeClass(target, 'button-active')
    else
      @showFlyout(context, e)
      dom.addClass(target, 'button-active')

  showFlyout: (context, e) =>
    target = @_getFlyoutTarget(e)
    if target && !domData.get(target, 'flyout')
      @hideFlyout(context, e)
      dom.addClass(target, 'flyout-visible')
      template = target.getAttribute('data-flyout')
      flyout = dom.stringToNode(require("../html/#{template}.html"))
      domData.set(target, 'flyout', flyout)
      @_flyouts.push(flyout)
      ko.applyBindings(context, flyout)
      parent = listItem = target
      listItem = listItem.parentNode until dom.hasClass(listItem, 'ccol')
      if dom.hasClass(target, 'flyout-tooltip-button')
        dom.addClass(flyout, 'flyout-tooltip')
      else
        parent = listItem
      listOffset = @_offset(listItem, document.body)
      parentOffset = @_offset(parent, document.body)
      dom.remove(domData.get(target, 'flyout'))

      flyout.style.top = parentOffset.top + 'px'
      flyout.style.left = listOffset.left + listItem.clientWidth + 'px'
      @_alignFlyouts();
      document.body.appendChild(flyout)
      domNodeDisposal.addDisposeCallback target, => @_destroyFlyout(target)

  _alignFlyouts: ->
    scroll = @_scrollParent?.scrollTop ? 0
    for flyout in @_flyouts
      prevScroll = domData.get(flyout, 'flyout-scroll') || 0
      domData.set(flyout, 'flyout-scroll', scroll)
      if prevScroll != scroll
        top = parseInt(flyout.style.top)
        flyout.style.top = (top + prevScroll - scroll) + 'px'


  # Finds vertical distance from the top of parent to the top of el,
  # traversing offsetParents
  _offset: (el, parent) ->
    top = -parent.offsetTop
    left = -parent.offsetLeft
    parent = parent.offsetParent if top != 0 || left != 0
    while el && el != parent
      top += el.offsetTop
      left += el.offsetLeft
      el = el.offsetParent
    {top: top, left: left}

  _destroyFlyout: (target) ->
    flyout = domData.get(target, 'flyout')
    if flyout
      index = @_flyouts.indexOf(flyout)
      @_flyouts.splice(index, 1) if index != -1
      domData.clear(flyout)
      dom.remove(flyout)

  hideFlyout: (context, e) =>
    target = @_getFlyoutTarget(e)
    if target
      @_destroyFlyout(target)
      dom.removeClass(target, 'flyout-visible')
      domData.set(target, 'flyout', null)

ccolsHtml = require('../html/collections-collapsed.html')
KnockoutComponentModel.register(CollectionsCollapsedModel, 'edsc-collections-collapsed', ccolsHtml)
