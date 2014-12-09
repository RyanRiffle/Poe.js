###
Poe.TextCursor is the visible caret on the screen. It is where all of the magic
happens when it comes to user input. It listens for keydown event from the body element
and inserts the text typed before the cursor. It also handles word wrap and page wrap.

The cursor is actually handled in two different areas. There is a span and a visible
cursor, this.element and this.visibleCursor respectively. The span is actually the
cursor that is used. It has one child that is a zero width space &#8203; When the cursor
is moved the visible cursor gets updated to the position of that span. Making it look
like it is the cursor.
###
class Poe.TextCursor
  ###
  Creates a Poe.TextCursor instance
  @param [Poe.Word] inside the word to put the cursor inside
  ###
  constructor: (inside) ->
    if not inside
      throw new Error('Poe.TextCursor constructor expects one argument of type Poe.Word')

    @element = $ '<span class="textcursor">&#8203;</span>'
    @visibleCursor = $ '<div class="visiblecursor"></div>'
    @currentWord = inside
    @blinkTimer = null
    inside.prepend @element
    $('body').append @visibleCursor
    @show()
    $('body').keydown(@keyEvent)
    @textStyle = new Poe.TextStyle(this)
    @textStyle.applyWord @currentWord

    @paragraphStyle = new Poe.ParagraphStyle(this)
    @paragraphStyle.apply()
    @paragraphStyle.changed @paragraphStyleChanged

    @capsLock = off

  ###
  Convienence function for getting the cursor contiaining word's parent
  @return [Poe.TextObject] the parent
  ###
  currentLine: ->
    return @currentWord.parent

  ###
  Convienence function for currentLine().parent
  @return [Poe.TextObject] currentLine().parent
  ###
  currentParagraph: ->
    return @currentLine().parent

  ###
  Convenience function for currentParagraph().parent
  @return [Poe.TextObject] currentParagraph().parent
  ###
  currentPage: ->
    return @currentParagraph().parent

  document: ->
    return @currentPage().parent

  ###
  Gets the next text node after the cursor. This will loop through all parents up to
  the Poe.Document if neccessary. It does not change any members unless applyChanges
  is true.
  @param applyChanges [Boolean] If true the currentWord is changed by this function.
  @return [null] if no node is found
  @return [jQuery or null] the next text node found
  ###
  next: (applyChanges = false) ->
    ###next = @element.nextSibling()
    word = @currentWord
    line = word.parent
    paragraph = line.parent
    page = paragraph.parent
    while !next
      [old, word] = [word, word.next()]
      old.remove() if old.isEmpty()
      if !word
        line = line.next()
        if !line
          paragraph = paragraph.next()
          if !paragraph
            page = page.next()
            return null if !page
            paragraph = page.child 0
          line = paragraph.child 0
        word = line.child 0
      next = word.children().first()
    @currentWord = word if applyChanges and next
    @textStyle.update word if @currentWord != word
    return next###
    next = @element.nextSibling()
    word = @currentWord
    if not next
      word = word.next()
      next = word?.children().first()
      @currentWord = word if applyChanges and word
    return next

  ###
  Gets the previous text node before the cursor. This will loop through all parents up to
  the Poe.Document containing the cursor if neccessary. This does not change any members
  unless applyChanges is true.
  @param applyChanges [Boolean] Sets the current word on return to the word containing
  the return value.
  @return [null] if no node is found
  @return [jQuery or null] the previous text node found
  ###
  prev: (applyChanges = false) ->
    prev = @element.prevSibling()
    word = @currentWord
    if not prev
      word = word.prev()
      prev = word?.children().last()
      @currentWord = word if applyChanges and word
    return prev

  ###
  Moves the cursor before the previous text node found by prev()
  @return [Poe.TextCursor] this
  ###
  moveLeft: ->
    prev = @prev(true)
    prev.before @element if prev
    return this

  ###
  Moves the cursor after the next text node found by next()
  @return [Poe.TextCursor] this
  ###
  moveRight: ->
    next = @next(true)
    next.after @element if next
    return this

  ###
  Moves the actual blinking cursor to where it should be.
  @return [Poe.TextCursor] this
  @private
  ###
  update: ->
    @visibleCursor.css 'top', "#{@element.position().top}px"
    @visibleCursor.css 'left', "#{@element.position().left}px"
    return this

  ###
  Fixes word wrap. Starts off by calling {Poe.TextCursor#paragraphStyleChanged} then
  loops through all lines of the currentParagraph() and checks to see if the
  last word in that line is outside of the editable area. If the word is
  outside it gets moved down to the next line. If no line exists a line is created
  after it.
  @return [Poe.TextCursor] this
  @private
  ###
  doWordWrap: ->
    # Loop through all lines in the current paragraph
    for line in @currentParagraph().children
      if line.isEmpty()
        line.remove()
        continue
      while !line.visiblyContains line.children.last()
        if !line.next()
          newLine = new Poe.Line()
          newLine.element.attr('class', line.element.attr('class'))
          newLine.child(0).remove()
          newLine.insertAfter line
        else
          newLine = line.next()

        newLine.prepend line.children.last()

      childWidth = 0
      for child in line.children
        childWidth += child.element.width()

      break if not line.next()
      break if line.next() instanceof Poe.ListItem
      hasRoom = true
      while hasRoom
        child = line.next().child(0)
        break if not child

        if childWidth + child.element.width() < line.element.outerWidth(false)
          hasRoom = true
          child.insertAfter line.children.last()
        else
          hasRoom = false
    @doPageWrap()
    return this

  doPageWrap: ->
    overflows = (page, paragraph) ->
      paragraphBottom = paragraph.element.position().top + paragraph.element.height()
      pageBottom = page.element.position().top + page.element.height()
      pageBottom += parseInt(page.element.css('padding-top'))
      return paragraphBottom > pageBottom

    for page in @document().children
      while overflows(page, page.children.last())
        if !page.next()
          newPage = new Poe.Page()
          newPage.insertAfter @currentPage()
          newPage.child(0).remove()

        next = @currentPage().next()
        paragraph = new Poe.Paragraph()
        paragraph.child(0).remove()
        next.prepend paragraph

        line = page.children.last().children.last()
        while overflows(page, line)
          paragraph.prepend line
          line = page.children.last().children.last()
          if page.children.last().isEmpty()
            page.children.last().remove()
        @update()


  ###
  Handles typing. At first it stops the cursor from blinking. Then does anything
  neccessary to translate the keydown onto the screen. Lastly it makes the cursor
  continue blinking.
  @private
  ###
  keyEvent: (event) =>
    if (event.ctrlKey)
      return
    event.preventDefault()
    @hide()
    switch event.keyCode
      when Poe.key.Shift then break

      when Poe.key.CapsLock
        @capsLock = !@capsLock

      when Poe.key.Left
        if @currentWord.children().length == 1
          @element.before "&#8203;"
        @moveLeft()

      when Poe.key.Right

        @moveRight()

      when Poe.key.Enter
        if @currentParagraph() instanceof Poe.List
          li = new Poe.ListItem()
          li.insertAfter @currentLine()
          @moveInside li.child(0)
          @textStyle.applyWord()
          break

        paragraph = new Poe.Paragraph()
        paragraph.insertAfter @currentParagraph()
        line = paragraph.child(0)
        word = line.child(0)
        @textStyle.applyWord word
        while @element.nextSibling()
          word.element.append @element.nextSibling()

        while @currentWord.element.nextSibling()
          line.append @currentWord.next()

        # Move all lines after the current to the new paragraph
        while @currentLine().element.nextSibling()
          paragraph.append @currentLine().next()

        if @currentWord.children().length == 1 and @currentLine().children.length == 1
          @currentWord.element.append '&#8203;'

        console.log line.children.length
        @currentWord = word
        @currentWord.element.prepend @element
        @textStyle.apply @currentWord
        @paragraphStyle.update @currentLine()
        @doPageWrap()

      when Poe.key.Backspace
        oldWord = @currentWord
        oldLine = @currentLine()
        oldParagraph = @currentParagraph()
        oldPage = @currentPage()
        prev = @prev(true)

        if not prev
          break

        if @currentParagraph() instanceof Poe.List
          if @currentLine().index() == @currentParagraph().children.length-1
            if @currentWord.children().length == 1
              li = @currentLine()
              paragraph = new Poe.Paragraph()
              paragraph.insertAfter @currentParagraph()
              @moveInside paragraph.child(0).child(0)
              @textStyle.applyWord()
              if li.parent.isEmpty()
                li.parent.remove()
              else
                li.remove()
              break

        prev.after @element if prev
        prev.remove() if prev

        if oldPage.isEmpty()
          oldPage.remove()
        else if oldParagraph.isEmpty()
          oldParagraph.remove()
        else if oldLine.isEmpty()
          oldLine.remove()
        else if oldWord.isEmpty()
          oldWord.remove()
        #If the cursor is at the beginning of the word move
        #it to the previous word and remove cursor containing
        #word if it is empty
        ###if not @element.prevSibling()
          word = @currentWord
          prev2 = @prev(true)
          prev2.after @element if prev2
          if word.isEmpty()
            word.remove()###

        @doWordWrap()

      when Poe.key.Delete
        next = @next()
        next.remove() if next

      when Poe.key.Space
        @element.before " "
        word = new Poe.Word()
        word.insertAfter @currentWord
        next = @element.nextSibling()
        while next
          word.append next
          next = next.nextSibling()
        word.prepend @element
        @currentWord = word
        @textStyle.applyWord @currentWord
        @doWordWrap()
      else
        if event.shiftKey and @capsLock
          event.shiftKey = false
        else if not event.shiftKey and @capsLock and event.keyCode >= 65 and event.keyCode <= 90
          event.shiftKey = true
        letter = Poe.keyMapShift[event.keyCode] if event.shiftKey
        letter = Poe.keyMap[event.keyCode] unless event.shiftKey
        @element.before letter
        @doWordWrap()
    @show()

  ###
  Callback registered with {Poe.ParagraphStyle} that will update the whole
  paragraph's alignment.
  ###
  paragraphStyleChanged: (style) =>
    @show()

  ###
  Moves the cursor inside and at the front of word
  @param word [Poe.Word] the word to move it inside
  @throws [Error] if the word is not a Poe.Word
  @return [Poe.TextCursor] this
  ###
  moveInside: (word) ->
    if not word instanceof Poe.Word
      throw new Error('Can only move inside a Poe.Word')

    word.prepend @element
    @currentWord = word
    @show()
    return this

  ###
  Shows the cursor if it is hidden and sets a time to make the cursor blink if
  it is not already.
  @return [Poe.TextCursor] this
  ###
  show: ->
    @update()
    @visibleCursor.removeClass 'hide'
    return if @blinkTimer
    @blinkTimer = setInterval @blink, 700
    return this

  ###
  Hides the cursor if it is visible and stops it from blinking.
  @return [Poe.TextCursor] this
  ###
  hide: ->
    clearInterval @blinkTimer
    @blinkTimer = null
    @visibleCursor.addClass 'hide'
    return this

  ###
  Controls the actual blinking of the cursor. See show()
  @private
  ###
  blink: =>
    @visibleCursor.toggleClass 'hide'
