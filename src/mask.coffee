###
 Attaches jquery-ui input mask onto input element
###
angular.module('ui.directives').directive 'uiMask', ['$parse', 'uiConfig', ($parse, uiConfig)->

  defaultConfig = 
    # The basio mask rules - overridge these in uiConfig
    rules:
      'z': /[a-z]/
      'Z': /[A-Z]/
      'a': /[a-zA-Z]/
      '*': /[0-9a-zA-Z]/
      '@': /[0-9a-zA-ZçÇáàãâéèêíìóòôõúùü]/
      '9': /[0-9]/

    keyCodes:
      8   : 'backspace',   9 : 'tab'
      13  : 'enter',      16 : 'shift',
      17  : 'control',    18 : 'alt',
      27  : 'esc',        33 : 'page up',
      34  : 'page down',  35 : 'end',
      36  : 'home',       37 : 'left',
      38  : 'up',         39 : 'right',
      40  : 'down',       45 : 'insert',
      46  : 'delete',    116 : 'f5'
      123  : 'f12',       224 : 'command'

    defaultOptions:
      type: 'fixed'             # the mask of this mask - can be fixed, reverse or repeat
      #      maxLength: -1             # the maxLength of the mask
      #      defaultValue: ''          # the default value for this input

      #      allowTextAlign: true      # use false to tell directive not to use text-align styles to align reverse masks
      selectCharsOnFocus: true  # select all chars from input on its focus
      #      autoTab: true             # auto focus the next form element when you type the mask completely
      #      setSize: false            # sets the input size based on the length of the mask (works with fixed and reverse masks only)

    namedMaskFormats:
      'phone'             : {mask: '(99) 9999-9999' }
      'phone-us'          : {mask: '(999) 999-9999' }
      'date-uk'           : {mask: '39/19/9999' }
      'date-us'           : {mask: '19/39/9999' }
      'cep'               : {mask: '99999-999' }
      'time'              : {mask: '29:59' }
      'creditcard'        : {mask: '9999 9999 9999 9999' }
      'integer'           : {mask: '999.999.999.999',    type: 'reverse' }
      'decimal'           : {mask: '99,999.999.999.999', type: 'reverse', defaultValue: '000'}
      'decimal-us'        : {mask: '99.999,999,999,999', type: 'reverse', defaultValue: '000'}
      'signed-decimal'    : {mask: '99,999.999.999.999', type: 'reverse', defaultValue: '+000'}
      'signed-decimal-us' : {mask: '99,999.999.999.999', type: 'reverse', defaultValue: '+000'}

  angular.extend(defaultConfig, uiConfig.mask)

  getKeyCode = (e)->
    e.charCode ? e.keyCode ? e.which

  directive = 
    require: 'ngModel'
    link: ($scope, $element, $attrs, $modelCtrl)->
      config = angular.copy(defaultConfig);
      mask = {} # declare the mask object
      ignoreKeyPress = false

      # Watch the mask attribute
      $scope.$watch $attrs.uiMask, (value, original)->
        return if value is original

        mask = parseMask(value, config.defaultOptions)

        # Bind up the DOM events
        $element.bind
          keydown: onKeyDown
          keypress: onKeyPress
          keyup: onKeyUp
          paste: onPaste

          focus: onFocus
          blur: onBlur
          change: onChange

      # Setup the formatter than will mask the model value
      controller.$formatters.push (value)->
        maskValue(value)

      onKeyDown = (e)->
        return if isReadonly()
        keyCode = getKeyCode(e)
        ignoreKeyPress = keyCode in config.keyCodes or e.ctrlKey or e.metaKey or e.altKey

      onKeyPress = (e)->
        return if isReadonly() or ignoreKeyPress
      onKeyUp = (e)->
        return if isReadonly() or ignoreKeyPress
      onPaste = ()->
        return if isReadonly()
      onFocus = ()->
        if mask.selectCharsOnFocus
          $element.select();
      onBlur = ()->
        # Not sure if we need to do anything here
      onChange = ()->
        # Not sure if we need to do anything here
      isReadonly = ()->
        $attrs('readonly')

  parseMask = (maskAttr, config)->
    # If the maskAttr is a string, look it up in the named masks or take the string as the mask itself
    if angular.isString(maskAttr)
      mask = config.namedMaskFormats[maskAttr] ? { format: maskAttr }
    else if angular.isObject(maskAttr)
      mask = maskAttr
    else
      throw new Error('Invalid mask: ' + maskAttr)

    # Merge with the default options
    mask = angular.extend({}, config.defaultOptions, mask)

    # Extract rules for each character in the mask format string
    mask.placeholders = (
      for chars in mask.format.split('')
        char: char
        rule: options.rules[char]
    )
    # This will hold an array of the characters that will be displayed in the input box
    mask.value = (for placeholder in mask.placeholders
      if placeholder.rule? then '' else placeholder.char
    )
    return mask

  # Update the mask with the value, optionally only updating between the start and end character positions of the masked string
  maskValue = (mask, value, start, end)->
    valuePos = 0
    valueEnd = value.length
    maskStart = start ? 0
    maskEnd = end ? mask.format.length
    maskPos = 0

    # Work our way through the value trying to format it into the mask
    while valuePos < valueEnd and maskPos < maskEnd
      valueChar = value.charAt(valuePos)
      maskChar = mask.placeholders[maskPos]
      if maskChar.rule?
        if maskChar.rule.match(valueChar)
          # Matched rule - add this character from the value
          mask.value[maskPos] = valueChar
          maskPos += 1
          valuePos += 1
        else
          # Unmatched rule - skip this character from the value
      else
        # Fixed mask character - add this character from the mask
        mask.value[maskPos] = maskChar.char
        maskPos += 1

  setRange = (input, start, end)->
    end ?= start
    if input.setSelectionRange
      input.setSelectionRange(start, end)
    else # assume IE
      range = input.createTextRange()
      range.collapse()
      range.moveStart('character', start)
      range.moveEnd('character', end - start)
      range.select()

      return {start: input.selectionStart, end: input.selectionEnd} if not $.browser.msie
      pos = {start: 0, end: 0}
      range = document.selection.createRange()
      pos.start = 0 - range.duplicate().moveStart('character', -100000)
      maskPos = 0

      pos.end = pos.start + range.text.length
      return pos
]