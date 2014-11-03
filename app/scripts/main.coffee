    
class Player
    constructor: (@name, @health) ->
        if !@name?
            @name = (null)
        if !@health?
            @health = (null)
    
class PlayerSlot
    constructor: (@player) ->
        @is_slot = () -> true
        @visible = (false)
        @isVisible = () -> @visible
        
class Bracket
    constructor: () ->
        @lastmatch = (null)
        @matches = {}
        
###
 # Every Bracket has a list of matches
 # Every match has two PlayerSlots
 # A PlayerSlot can contain a Player or be null
 # A PlayerSlot contains a rectangle which denotes it's size
 # a Player has a name, and some amount of health
 # (in a triple elim, the health for all starts at 3)
###
    
class BracketViewer
    constructor: () ->
        @canvas = document.getElementById "tourneyViewer"
        @tourneyData = (null)
        @bracket1 = new Bracket
        @bracket2 = new Bracket
        @bracket3 = new Bracket
        @champBracket = new Bracket
        @rectStroke = "#000000"
        @rectFill = "#AAAAAA"
        @rectWidth = 110
        @rectHeight = 40
        @textHeight = "14px"
        @fileLoaded = false
        
        try
            @context = @canvas.getContext "2d"
        catch
            throw Message: "Failure to get canvas context."
        
        mainDiv = document.getElementById "mainContent"
        
        $(mainDiv).bind 'dragover', (event) ->
            event.stopPropagation()
            event.preventDefault()
            
        $(mainDiv).bind 'drop', @drop
        
        $(window).resize @resize
        @resize()
            
    drop: (event) =>
        console.log "wakka"
        
        event.stopPropagation()
        event.preventDefault()
        
        files = event.originalEvent.dataTransfer.files
        
        if files.length != 1
            throw Message: "Multiple files dropped"
            
        file = files[0]
        filename = escape file.name
        
        if not /\.json$/.test(filename)
            throw Message: "Needs to be a JSON file"
        
        reader = new FileReader()
        
        reader.onload = (event) =>
            @tourneyData = JSON.parse event.target.result
            console.info "File loaded"
            @createBrackets()
        
        reader.readAsText file
    
    createBrackets: () ->
        ###
         # Add list of subsequent games to each match. Also add an 
         # attribute player_slots and add the number of PlayerSlot objects 
         # for each previous game.
        ###
        for id, match of @tourneyData
            match.is_slot = () -> (false)
            
            if !match.subsequent_matches?
                match.subsequent_matches = []
                
            if match.previous_matches.length > 0
                prevMatch1id = match.previous_matches[0].toString()
                prevMatch2id = match.previous_matches[1].toString()
                prevMatch1 = @tourneyData[prevMatch1id]
                prevMatch2 = @tourneyData[prevMatch2id]
                
                if !prevMatch1.subsequent_matches?
                    prevMatch1.subsequent_matches = []
                
                if !prevMatch2.subsequent_matches?
                    prevMatch2.subsequent_matches = []
                    
                prevMatch1.subsequent_matches.push id
                prevMatch2.subsequent_matches.push id
      
        ###
         # Start filling the first bracket. This will place references to 
         # all the games that are leaves of the overall tree in an array.
         # These matches are the bottom of the first bracket.
        ###
        tier = {}
        for id, match of @tourneyData
            if match.previous_matches.length == 0
                @bracket1.matches[id] = match
                tier[id] = match
        
        ###
         # Find matches that use the winner of one of those games in the
         # bottom rung and add it to the next rung. Then swap the next
         # rung for the old rung. Do this until there is only one game
         # in the rung, which will be the final game in the first bracket.
        ###
        newtier = {}
        while Object.keys(tier).length > 1
            for id, match of @tourneyData
                if match.previous_matches.length > 0
                    prevMatch1id = match.previous_matches[0].toString()
                    prevMatch2id = match.previous_matches[1].toString()
                    prevMatch1 = @tourneyData[prevMatch1id]
                    prevMatch2 = @tourneyData[prevMatch2id]
                    for tierid, tiermatch of tier
                        if ((prevMatch1id == tierid and
                        (match.player_1 == tiermatch.winner or
                        match.player_2 == tiermatch.winner)) or  
                        (prevMatch2id == tierid and
                        (match.player_1 == tiermatch.winner or
                        match.player_2 == tiermatch.winner)))
                            @bracket1.matches[id] = match
                            newtier[id] = match
            tier = newtier
            newtier = {}
       
        ###
         # Since we have the final match already left in the current
         # tier array just initialize it as the last match of the bracket.
        ###
        for id, match of tier
            @bracket1.lastmatch = id
        
        ###
         # Now start building the second bracket. To do this, we first find
         # all the game in the entire list that contain two losers from the
         # first bracket. These will be the bottom rung matches in bracket 2.
        ###
        for id, match of @tourneyData
            if match.previous_matches.length > 0
                prevMatch1id = match.previous_matches[0].toString()
                prevMatch2id = match.previous_matches[1].toString()
                prevMatch1 = @tourneyData[prevMatch1id]
                prevMatch2 = @tourneyData[prevMatch2id]
                
                if prevMatch1.winner == prevMatch1.player_1
                    loser1 = prevMatch1.player_2
                else
                    loser1 = prevMatch1.player_1
                    
                if prevMatch2.winner == prevMatch2.player_1
                    loser2 = prevMatch2.player_2
                else
                    loser2 = prevMatch2.player_1           
                    
                matchHasTwoLosersFromBrack1 = 
                (@bracket1.matches[prevMatch1id]? and
                (match.player_1 == loser1 or
                match.player_2 == loser1)) and
                (@bracket1.matches[prevMatch2id]? and
                (match.player_1 == loser2 or
                match.player_2 == loser2))
                    
                if (matchHasTwoLosersFromBrack1)
                    @bracket2.matches[id] = match
        
        ###
         # Then we fill out the rest of bracket two. Here you will insert all
         # game that either have one winner from bracket2 and one loser from
         # bracket1 or two winners from bracket2. This needs to be run until
         # nothing is inserted because a check to see if a bracket2 game exists
         # may not have been inserted into bracket2 yet. Once no insertion has
         # been made, bracket2 will be complete.
        ###
        insertionMade = (true)
        while insertionMade
            insertionMade = (false)
            for id, match of @tourneyData
                if match.previous_matches.length > 0 and !@bracket2.matches[id]?
                    prevMatch1id = match.previous_matches[0].toString()
                    prevMatch2id = match.previous_matches[1].toString()
                    prevMatch1 = @tourneyData[prevMatch1id]
                    prevMatch2 = @tourneyData[prevMatch2id]
                    
                    if prevMatch1.winner == prevMatch1.player_1
                        loser1 = prevMatch1.player_2
                    else
                        loser1 = prevMatch1.player_1
                        
                    if prevMatch2.winner == prevMatch2.player_1
                        loser2 = prevMatch2.player_2
                    else
                        loser2 = prevMatch2.player_1           
                        
                    matchHasLoserFromBrack1 = 
                    (@bracket1.matches[prevMatch1id]? and
                    (match.player_1 == loser1 or
                    match.player_2 == loser1)) or
                    (@bracket1.matches[prevMatch2id]? and
                    (match.player_1 == loser2 or
                    match.player_2 == loser2))
                    
                    matchHasWinnerFromBrack2 = 
                    (@bracket2.matches[prevMatch1id]? and
                    (match.player_1 == prevMatch1.winner or
                    match.player_2 == prevMatch1.winner)) or
                    (@bracket2.matches[prevMatch2id]? and
                    (match.player_1 == prevMatch2.winner or
                    match.player_2 == prevMatch2.winner))
                    
                    matchHasTwoWinnersFromBrack2 = 
                    (@bracket2.matches[prevMatch1id]? and
                    (match.player_1 == prevMatch1.winner or
                    match.player_2 == prevMatch1.winner)) and
                    (@bracket2.matches[prevMatch2id]? and
                    (match.player_1 == prevMatch2.winner or
                    match.player_2 == prevMatch2.winner))
                    
                    if matchHasLoserFromBrack1 and matchHasWinnerFromBrack2 or
                    matchHasTwoWinnersFromBrack2
                        insertionMade = (true)
                        @bracket2.matches[id] = match

        ###
         # Here we find the last match in bracket 2. This can be found by
         # grabbing any match in the object, (which is only possible via
         # a javascript for, in loop) I use the loop to grab the first match
         # in the bracket, iterate up the subsequent games within bracket 2,
         # until I can't either subsequent matches in this bracket, 
         # and that will be the top of tier 2.
        ### 
        for id, match of @bracket2.matches
            nextId = id
            nextMatch = match
            
            subMatch1id = id
            subMatch2id = id
            subMatch1 = match
            subMatch2 = match
            
            while @bracket2.matches[subMatch1id]? or
            @bracket2.matches[subMatch2id]?
                if @bracket2.matches[subMatch1id]?
                    nextId = subMatch1id
                    nextMatch = subMatch1
                else if @bracket2.matches[subMatch2id]?
                    nextId = subMatch2id
                    nextMatch = subMatch2
                else
                    break

                subMatch1id = nextMatch.subsequent_matches[0].toString()
                subMatch2id = nextMatch.subsequent_matches[1].toString()
                subMatch1 = @tourneyData[subMatch1id]
                subMatch2 = @tourneyData[subMatch2id]
            
            @bracket2.lastmatch = nextId
            break
        
        ###
         # Here find bracket3 the same way we found bracket2. First find
         # all games that have two losers from the now complete bracket2.
        ###
        for id, match of @tourneyData
            if match.previous_matches.length > 0
                prevMatch1id = match.previous_matches[0].toString()
                prevMatch2id = match.previous_matches[1].toString()
                prevMatch1 = @tourneyData[prevMatch1id]
                prevMatch2 = @tourneyData[prevMatch2id]
                
                if prevMatch1.winner == prevMatch1.player_1
                    loser1 = prevMatch1.player_2
                else
                    loser1 = prevMatch1.player_1
                    
                if prevMatch2.winner == prevMatch2.player_1
                    loser2 = prevMatch2.player_2
                else
                    loser2 = prevMatch2.player_1           
                    
                matchHasTwoLosersFromBrack2 = 
                (@bracket2.matches[prevMatch1id]? and
                (match.player_1 == loser1 or
                match.player_2 == loser1)) and
                (@bracket2.matches[prevMatch2id]? and
                (match.player_1 == loser2 or
                match.player_2 == loser2))
                    
                if (matchHasTwoLosersFromBrack2)
                    @bracket3.matches[id] = match
        
        ###
         # The we find all the games that have a loser from bracket 2 and
         # a winner from bracket 3, and all games that have two winners
         # from brack 3.
        ###
        insertionMade = (true)
        while insertionMade
            insertionMade = (false)
            for id, match of @tourneyData
                if match.previous_matches.length > 0 and !@bracket3.matches[id]?
                    prevMatch1id = match.previous_matches[0].toString()
                    prevMatch2id = match.previous_matches[1].toString()
                    prevMatch1 = @tourneyData[prevMatch1id]
                    prevMatch2 = @tourneyData[prevMatch2id]
                    
                    if prevMatch1.winner == prevMatch1.player_1
                        loser1 = prevMatch1.player_2
                    else
                        loser1 = prevMatch1.player_1
                        
                    if prevMatch2.winner == prevMatch2.player_1
                        loser2 = prevMatch2.player_2
                    else
                        loser2 = prevMatch2.player_1           
                        
                    matchHasLoserFromBrack2 = 
                    (@bracket2.matches[prevMatch1id]? and
                    (match.player_1 == loser1 or
                    match.player_2 == loser1)) or
                    (@bracket2.matches[prevMatch2id]? and
                    (match.player_1 == loser2 or
                    match.player_2 == loser2))
                    
                    matchHasWinnerFromBrack3 = 
                    (@bracket3.matches[prevMatch1id]? and
                    (match.player_1 == prevMatch1.winner or
                    match.player_2 == prevMatch1.winner)) or
                    (@bracket3.matches[prevMatch2id]? and
                    (match.player_1 == prevMatch2.winner or
                    match.player_2 == prevMatch2.winner))
                    
                    matchHasTwoWinnersFromBrack3 = 
                    (@bracket3.matches[prevMatch1id]? and
                    (match.player_1 == prevMatch1.winner or
                    match.player_2 == prevMatch1.winner)) and
                    (@bracket3.matches[prevMatch2id]? and
                    (match.player_1 == prevMatch2.winner or
                    match.player_2 == prevMatch2.winner))
                    
                    if matchHasLoserFromBrack2 and matchHasWinnerFromBrack3 or
                    matchHasTwoWinnersFromBrack3
                        insertionMade = (true)
                        @bracket3.matches[id] = match
        
        ###
         # We find the last match in bracket3 just as we found it in bracket2
        ### 
        for id, match of @bracket3.matches
            nextId = id
            nextMatch = match
            
            subMatch1id = id
            subMatch2id = id
            subMatch1 = match
            subMatch2 = match
            
            while @bracket3.matches[subMatch1id]? or
            @bracket3.matches[subMatch2id]?
                if @bracket3.matches[subMatch1id]?
                    nextId = subMatch1id
                    nextMatch = subMatch1
                else if @bracket3.matches[subMatch2id]?
                    nextId = subMatch2id
                    nextMatch = subMatch2
                else
                    break

                subMatch1id = nextMatch.subsequent_matches[0].toString()
                subMatch1 = @tourneyData[subMatch1id]
                if nextMatch.subsequent_matches.length == 2
                    subMatch2id = nextMatch.subsequent_matches[1].toString()
                    subMatch2 = @tourneyData[subMatch2id]
                else
                    subMatch2id = subMatch1id
                    subMatch2 = subMatch1
            
            @bracket3.lastmatch = nextId
            break
        
        ###
         # All the games that do no exist in the other brackets are 
         # the championship games
        ###
        for id, match of @tourneyData
            if !@bracket1.matches[id]? and 
            !@bracket2.matches[id]? and 
            !@bracket3.matches[id]?
                @champBracket.matches[id] = match
                
        ###
         # Since the last match in the champ bracket has no subsequent games,
         # it's very easy to just look through them and find the one with no
         # subsequent matches.
        ###
        for id, match of @champBracket.matches
            if match.subsequent_matches.length == 0
                @champBracket.lastmatch = id
                break
        
        ###
         # For all the matches that have previous games in other brackets,
         # add a player slot to the bracket in it's place. They are always
         # losers in the case of all the games in bracket 2 and 3.
        ###
        for id, match of @bracket2.matches
            if match.previous_matches.length > 0
                prevMatch1id = match.previous_matches[0].toString()
                prevMatch2id = match.previous_matches[1].toString()
                prevMatch1 = @tourneyData[prevMatch1id]
                prevMatch2 = @tourneyData[prevMatch2id]
                
                if !@bracket2.matches[prevMatch1id]?
                    if prevMatch1.winner == prevMatch1.player_1 
                        @bracket2[id] = new PlayerSlot(prevMatch1.player_2)
                    else
                        @bracket2[id] = new PlayerSlot(prevMatch1.player_1)
                else if !@bracket2.matches[prevMatch2id]?
                    if prevMatch2.winner == prevMatch2.player_1
                        @bracket2[id] = new PlayerSlot(prevMatch2.player_2)
                    else
                        @bracket2[id] = new PlayerSlot(prevMatch2.player_1)
        
        ###
         # Same for bracket 3; put player slots where games do not exist
         # in the bracket.
        ###
        for id, match of @bracket3.matches
            if match.previous_matches.length > 0
                prevMatch1id = match.previous_matches[0].toString()
                prevMatch2id = match.previous_matches[1].toString()
                prevMatch1 = @tourneyData[prevMatch1id]
                prevMatch2 = @tourneyData[prevMatch2id]
                
                if !@bracket3.matches[prevMatch1id]?
                    if prevMatch1.winner == prevMatch1.player_1 
                        @bracket3[id] = new PlayerSlot(prevMatch1.player_2)
                    else
                        @bracket3[id] = new PlayerSlot(prevMatch1.player_1)
                else if !@bracket3.matches[prevMatch2id]?
                    if prevMatch2.winner == prevMatch2.player_1
                        @bracket3[id] = new PlayerSlot(prevMatch2.player_2)
                    else
                        @bracket3[id] = new PlayerSlot(prevMatch2.player_1)
        @fileLoaded = (true)
        @redraw()
                
    resize: () =>
        @canvas.width = $(window).width() - 5
        @canvas.height = $(window).height() - 5
        @redraw()
        console.log "resized"
    
    redraw: () =>
        if @fileLoaded
            depthRecurse = (depth, match) =>
                if match.previous_matches.length == 0
                    return depth + 1
            
                prev1id = match.previous_matches[0].toString()
                prev2id = match.previous_matches[1].toString()
                prev1 = @bracket1.matches[prev1id]
                prev2 = @bracket1.matches[prev2id]
            
                v1 = 0
                v2 = 0
                if prev1?
                    v1 = depthRecurse(depth+1, prev1)
                if prev2?
                    v2 = depthRecurse(depth+1, prev2)
                return if v1 > v2 then v1 else v2    
                        
            drawPlayerSlot = (bracket, slot, x1, x2, y1, y2) =>
                width = x2 - x1
                height = y2 - y1
                
                rectx = ((width/2) * @canvas.width) - (@rectWidth/2)
                recty = ((height/2) * @canvas.height) - (@rectHeight/2)
                
                @context.beginPath()    
                @context.rect( (x1 * @canvas.width) + rectx, 
                (y1 * @canvas.height)+ recty,
                @rectWidth,
                @rectHeight)
                @context.fillStyle = @rectFill
                @context.strokeStyle = @rectStroke
                @context.lineWidth = 1
                @context.fill()
                @context.stroke()
                
                text = slot.player
                #line 1
                i = 0
                j = 0
                while @context.measureText(text.substring(0, i+1)).width < @rectWidth
                    if text.substring(0, i) == text
                        break;
                    i++
                
                #line 2
                if text.substring(0, i) != text
                    j = i
                    while @context.measureText(text.substring(i, j + 1)).width < @rectWidth
                        if j >= text.length
                            break;
                        j++
                
                @context.font = @textHeight + ' Verdana'
                @context.textAlign = 'center'
                @context.fillStyle = '#000000'
                if j == 0
                    @context.fillText(text.substring(0, i), 
                    (x1 * @canvas.width) + rectx + (@rectWidth/2), 
                    (y1 * @canvas.height) + recty + (@rectHeight/2) + (parseInt(@textHeight)/2) - 1)                  
                else
                    @context.fillText(text.substring(0, i),
                    (x1 * @canvas.width) + rectx + (@rectWidth/2),
                    (y1 * @canvas.height) + recty + (@rectHeight/2) - 3)
                    @context.textAlign = 'left'
                    @context.fillText(text.substring(i, j)
                    (x1 * @canvas.width) + rectx,
                    (y1 * @canvas.height) + recty + @rectHeight - 3)
                        
            drawMatch = (bracket, match, x1, x2, y1, y2, xinc, goLeft) =>   
                width = x2 - x1
                height = y2 - y1    
                
                rectx = (width/2) * @canvas.width - (@rectWidth/2)
                recty = (height/2) * @canvas.height - (@rectHeight/2)
                    
                @context.beginPath()    
                @context.rect( (x1 * @canvas.width) + rectx, 
                (y1 * @canvas.height)+ recty,
                @rectWidth,
                @rectHeight)
                @context.fillStyle = @rectFill
                @context.strokeStyle = @rectStroke
                @context.lineWidth = 1
                @context.fill()
                @context.stroke()
                
                if match.is_slot()
                    text = match.player
                else
                    text = match.winner
                
                
                #line 1
                i = 0
                j = 0
                while @context.measureText(text.substring(0, i+1)).width < @rectWidth
                    if text.substring(0, i) == text
                        break;
                    i++
                
                #line 2
                if text.substring(0, i) != text
                    j = i
                    while @context.measureText(text.substring(i, j + 1)).width < @rectWidth
                        if j >= text.length
                            break;
                        j++
                
                @context.font = @textHeight + ' Verdana'
                @context.textAlign = 'center'
                @context.fillStyle = '#000000'
                if j == 0
                    @context.fillText(text.substring(0, i), 
                    (x1 * @canvas.width) + rectx + (@rectWidth/2), 
                    (y1 * @canvas.height) + recty + (@rectHeight/2) + (parseInt(@textHeight)/2) - 1)                  
                else
                    @context.fillText(text.substring(0, i),
                    (x1 * @canvas.width) + rectx + (@rectWidth/2),
                    (y1 * @canvas.height) + recty + (@rectHeight/2) - 3)
                    @context.textAlign = 'left'
                    @context.fillText(text.substring(i, j)
                    (x1 * @canvas.width) + rectx,
                    (y1 * @canvas.height) + recty + @rectHeight - 3)
                
                if match.previous_matches.length == 0
                    slot1y1 = y1
                    slot1y2 = y1 + (height/2)
                    slot2y1 = slot1y2
                    slot2y2 = y2
                    
                    slot1 = new PlayerSlot match.player_1
                    slot2 = new PlayerSlot match.player_2
                    
                    if goLeft
                        drawPlayerSlot(bracket, slot1, x1 - xinc, x1,
                        slot1y1, slot1y2)
                        drawPlayerSlot(bracket, slot2, x1 - xinc, x1,
                        slot2y1, slot2y2)
                    else
                        drawPlayerSlot(bracket, slot1, x2, x2 + xinc,
                        slot1y1, slot1y2)
                        drawPlayerSlot(bracket, slot2, x2, x2 + xinc,
                        slot2y1, slot2y2)
                    
                    return
                    
                prevMatch1id = match.previous_matches[0]
                prevMatch2id = match.previous_matches[1]
                prevMatch1 = bracket.matches[prevMatch1id]
                prevMatch2 = bracket.matches[prevMatch2id]
                
                prevMatch1Value = if prevMatch1.is_slot() then 1 else 2
                prevMatch2Value = if prevMatch2.is_slot() then 1 else 2
                divisor = prevMatch1Value + prevMatch2Value
                prevMatch1y1 = y1
                prevMatch1y2 = y1 + (prevMatch1Value * (height/divisor))
                prevMatch2y1 = prevMatch1y2
                prevMatch2y2 = prevMatch2y1 + (prevMatch2Value * (height/divisor))
                
                if goLeft
                    if prevMatch1.is_slot()
                        drawPlayerSlot(bracket, prevMatch1, x1-xinc, x1,
                        prevMatch1y1, prevMatch1y2)
                    else
                        drawMatch(bracket, prevMatch1, x1-xinc, x1, prevMatch1y1, 
                        prevMatch1y2, xinc, goLeft)
                    if prevMatch2.is_slot()    
                        drawPlayerSlot(bracket, prevMatch2, x1-xinc, x1,
                        prevMatch2y1, prevMatch2y2)
                    else
                        drawMatch(bracket, prevMatch2, x1-xinc, x1, prevMatch2y1,
                        prevMatch2y2, xinc, goLeft)
                else
                    if prevMatch1.is_slot()
                        drawPlayerSlot(bracket, prevMatch1, x2, x2+xinc,
                        prevMatch1y1, prevMatch2y2)
                    else
                        drawMatch(bracket, prevMatch1, x2, x2+xinc, prevMatch1y1,
                        prevMatch1y2, xinc, goLeft)
                    if prevMatch2.is_slot()
                        drawPlayerSlot(bracket, prevMatch2, x2, x2+xinc,
                        prevMatch2y1, prevMatch2y2)
                    else
                        drawMatch(bracket, prevMatch2, x2, x2+xinc, prevMatch2y1,
                        prevMatch2y2, xinc, goLeft)

            drawBracket = (bracket) =>
                match = bracket.matches[bracket.lastmatch]
                prevMatch1id = match.previous_matches[0].toString()
                prevMatch2id = match.previous_matches[1].toString()
                prevMatch1 = bracket.matches[prevMatch1id]
                prevMatch2 = bracket.matches[prevMatch2id]
            
            
                d1 = depthRecurse(1, prevMatch1)
                d2 = depthRecurse(1, prevMatch2)
            
                xDivisions = d1 + d2 + 1
        
                initialx1 = (1/xDivisions) * parseInt(xDivisions/2)
                initialx2 = initialx1 + (1/xDivisions)
                
                initwidth = initialx2 - initialx1
                initheight = 1    
                
                initrectx = ((initwidth/2) * @canvas.width) - (@rectWidth/2)
                initrecty = ((initheight/2) * @canvas.height) - (@rectHeight/2)
                    
                @context.beginPath()
                @context.rect( (initialx1 * @canvas.width) + initrectx, 
                initrecty,
                @rectWidth,
                @rectHeight)
                @context.fillStyle = @rectFill
                @context.strokeStyle = @rectStroke
                @context.lineWidth = 1
                @context.fill()
                @context.stroke()
                
                text = match.winner
                #line 1
                i = 0
                j = 0
                while @context.measureText(text.substring(0, i+1)).width < @rectWidth
                    if text.substring(0, i) == text
                        break;
                    i++
                
                #line 2
                if text.substring(0, i) != text
                    j = i
                    while @context.measureText(text.substring(i, j + 1)).width < @rectWidth
                        if j >= text.length
                            break;
                        j++
                
                @context.font = @textHeight + ' Verdana'
                @context.textAlign = 'center'
                @context.fillStyle = '#000000'
                if j == 0
                    @context.fillText(text.substring(0, i), 
                    (initialx1 * @canvas.width) + initrectx + (@rectWidth/2), 
                    initrecty + (@rectHeight/2) + (parseInt(@textHeight)/2) - 1)                  
                else
                    @context.fillText(text.substring(0, i),
                    (initialx1 * @canvas.width) + initrectx + (@rectWidth/2),
                    initrecty + (@rectHeight/2) - 3)
                    @context.textAlign = 'left'
                    @context.fillText(text.substring(i, j)
                    (initialx1 * @canvas.width) + initrectx,
                    initrecty + @rectHeight - 3)
                
                drawMatch(bracket, prevMatch1, initialx1 - (1/xDivisions), initialx1, 
                0, 1, (1/xDivisions), (true))
                drawMatch(bracket, prevMatch2, initialx2, initialx2 + (1/xDivisions),
                0, 1, (1/xDivisions), (false))

            drawBracket(@bracket1)
        
b = new BracketViewer