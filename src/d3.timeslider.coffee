class TimeSlider

    # TODO
    #  * Allow for the registration of datasets to be shown beneath the brush
    #  * Rename pixelPerDay to something more generic (could also be hours, ... depending on the time frame)
    #  * Cleanup the mess that is the axis labels right now
    #  * Compute the padding at the left & right of the timeslider
    #  * Convert all dates to UTC
    #  * Center the brush
    #  * Limit brush to the time between start & end date

    constructor: (@element, @options = {}) ->
        # Debugging?
        @debug = true

        # create the root svg element
        svg = d3.select(element).append('svg').attr('class', 'timeslider')

        # default options and other variables for later
        @options.minPixelPerDay ||= 50
        @options.width ||= @element.clientWidth
        @options.height = svg[0][0].clientHeight
        @options.brush ||= {}
        @options.brush.start || = @options.start
        @options.brush.end ||= new Date(new Date(@options.brush.start).setDate(@options.brush.start.getDate() + 3))
        @msToDays = 1000 * 60 * 60 * 24
        @numberOfDays = Math.ceil( (@options.end.getTime() - @options.start.getTime()) / @msToDays )
        @element.zoomLevel = 0

        # create the root element
        @root = svg.append('g').attr('class', 'root').attr('width', @options.width)

        @options.pixelPerDay = (@options.width - 20) / @numberOfDays
        @options.pixelPerDay = @options.minPixelPerDay if @options.pixelPerDay < @options.minPixelPerDay

        # scales
        @scales = 
            x: d3.time.scale.utc()
                .domain([ @options.start, @options.end ])
                .range([0, @numberOfDays * @options.pixelPerDay])
            y: d3.scale.linear()
                .range([ 0, @options.height ])

        # axis
        @axis = 
            x: d3.svg.axis()
                .scale(@scales.x)
                .ticks(d3.time.days.utc, 3)
                #.tickFormat(d3.time.format("%Y-%m-%d"))

        @root.append('g')
            .attr('class', 'axis')
            # TODO compute the 20px translation
            .attr('transform', "translate(0, #{@options.height - 20})")
            .call(@axis.x)

       # grid
        @grid = 
            x: d3.svg.axis()
                .scale(@scales.x)
                .ticks(d3.time.days.utc, 1)
                .tickFormat('')
                # TODO compute the 20px translation
                .tickSize(-@options.height+20, 0, 0)

        @root.append('g')
            .attr('class', 'grid')
            .attr('width', @options.width)
            # TODO compute the 20px translation
            .attr('transform', "translate(0, #{@options.height - 20})")
            .call(@grid.x)

        # brush
        @brush = d3.svg.brush()
            .x(@scales.x)
            .on('brushend', => 
                element.dispatchEvent(new CustomEvent('selectionChanged', { 
                    detail: {
                        start: @brush.extent()[0],
                        end: @brush.extent()[1]
                    }
                    bubbles: true, 
                    cancelable: true 
                }))
            )
            .extent([@options.brush.start, @options.brush.end])

        @root.append('g')
            .attr('class', 'brush')
            .call(@brush)
            .selectAll('rect')
                # TODO remove hardcoded height
                .attr('height', "#{@options.height - 20 - 2}px")
                .attr('y', 0)

        # dragging
        drag = =>
            # init
            element.dragging = { position: [0, 0] } unless element.dragging

            # set last position of the curser
            element.dragging.lastPosition = [d3.event.pageX, d3.event.pageY]

            # register event handlers for mousemove (to handle the real dragging logic) and mouseup
            # to deregister unneeded handlers
            d3.select(document)
                .on('mousemove', =>
                    element.dragging.position[0] += d3.event.pageX - element.dragging.lastPosition[0]
                    element.dragging.position[1] += d3.event.pageY - element.dragging.lastPosition[1]
                    element.dragging.lastPosition = [d3.event.pageX, d3.event.pageY]

                    width = Math.ceil(d3.select(@element).select('svg').style('width').slice(0, -2))

                    # TODO Allow dragging over the boundaries, but snap back afterwards
                    if element.dragging.position[0] > 0
                        element.dragging.position[0] = 0
                    else if ((Number) element.dragging.position[0] + @scales.x.range()[1]) < width
                        element.dragging.position[0] = width - @scales.x.range()[1]
                        console.log("Dragging Position #{element.dragging.position}")
                    @root.attr('transform', "translate(#{element.dragging.position[0]}, 0)") 

                )
                .on('mouseup', =>
                    d3.select(document).on('mousemove', null).on('mouseup', null)
                )

            # prevent default events
            d3.event.preventDefault()
            d3.event.stopPropagation()

        d3.select(element).on('mousedown', drag)

        # resizing (the window)
        resize = =>
            # update the width of the element
            @options.width = @element.clientWidth

            # calculate new size of a day
            @options.pixelPerDay = (@options.width - 20) / @numberOfDays
            @options.pixelPerDay = @options.minPixelPerDay if @options.pixelPerDay < @options.minPixelPerDay

            # update scale 
            @scales.x.range([0, @numberOfDays * @options.pixelPerDay])

            # update brush 
            @brush.x(@scales.x).extent(@brush.extent())

            # repaint the axis, scales and the brush
            d3.select(@element).select('g.axis').call(@axis.x)
            d3.select(@element).select('g.grid').call(@grid.x)
            d3.select(@element).select('g.brush').call(@brush)

        d3.select(window).on('resize', resize)

        # zooming 
        # (done via a seperate function, because we need to bind to two differen event listeners)
        zoom = =>
            if @debug
                time = {}
                time.start = new Date()

            direction = d3.event.wheelDelta if d3.event.wheelDelta
            direction = d3.event.detail * -1 if d3.event.detail

            if direction > 0
                if @element.zoomLevel < 10
                    @options.pixelPerDay *= 1.5
                    @element.zoomLevel += 1
            else
                if @element.zoomLevel > -10
                    @options.pixelPerDay /= 1.5
                    @element.zoomLevel -= 1

            console.log("Zooming to level #{@element.zoomLevel}") if @debug

            # update scale 
            @scales.x.range([0, @numberOfDays * @options.pixelPerDay])

            # update axis
            # TODO make cleaner
            switch 
                when @element.zoomLevel < -7
                    @axis.x.ticks(d3.time.months.utc, 2).tickFormat(d3.time.format.utc('%Y-%m'))
                    @grid.x.ticks(d3.time.months.utc, 1)
                when @element.zoomLevel < -5
                    @axis.x.ticks(d3.time.months.utc, 1).tickFormat(d3.time.format.utc('%Y-%m'))
                    @grid.x.ticks(d3.time.months.utc, 1)
                when @element.zoomLevel < -3
                    @axis.x.ticks(d3.time.mondays.utc, 2).tickFormat(d3.time.format.utc('%Y-%m-%d'))
                    @grid.x.ticks(d3.time.mondays.utc, 1)
                when @element.zoomLevel < -1
                    @axis.x.ticks(d3.time.mondays.utc, 1).tickFormat(d3.time.format.utc('%Y-%m-%d'))
                    @grid.x.ticks(d3.time.days.utc, 1)
                when @element.zoomLevel < 1
                    @axis.x.ticks(d3.time.days.utc, 3).tickFormat(d3.time.format.utc('%Y-%m-%d'))
                    @grid.x.ticks(d3.time.days.utc, 1)
                when @element.zoomLevel < 3
                    @axis.x.ticks(d3.time.days.utc, 1).tickFormat(d3.time.format.utc('%Y-%m-%d'))
                    @grid.x.ticks(d3.time.days.utc, 1)
                when @element.zoomLevel < 4
                    @axis.x.ticks(d3.time.days.utc, 1).tickFormat(d3.time.format.utc('%Y-%m-%d'))
                    @grid.x.ticks(d3.time.hours.utc, 6)                
                when @element.zoomLevel <= 5
                    @axis.x.ticks(d3.time.hours.utc, 12).tickFormat(d3.time.format.utc('%Y-%m-%d %I:%M'))
                    @grid.x.ticks(d3.time.hours.utc, 3)
                when @element.zoomLevel <= 7
                    @axis.x.ticks(d3.time.hours.utc, 6).tickFormat(d3.time.format.utc('%Y-%m-%d %I:%M'))
                    @grid.x.ticks(d3.time.hours.utc, 1)
                when @element.zoomLevel <= 9
                    @axis.x.ticks(d3.time.hours.utc, 3).tickFormat(d3.time.format.utc('%Y-%m-%d %I:%M'))
                    @grid.x.ticks(d3.time.minutes.utc, 30)
                else
                    @axis.x.ticks(d3.time.minutes.utc, 90).tickFormat(d3.time.format.utc('%Y-%m-%d %I:%M'))
                    @grid.x.ticks(d3.time.minutes.utc, 30)

            # update brush 
            @brush.x(@scales.x).extent(@brush.extent())

            # repaint the scales and axis
            d3.select(@element).select('g.axis').call(@axis.x)
            d3.select(@element).select('g.grid').call(@grid.x)
            d3.select(@element).select('g.brush').call(@brush)

            if @debug
                console.log("Done zooming, took #{new Date().getTime() - time.start.getTime()} milliseconds.")

        d3.select(element).on('DOMMouseScroll', zoom)
        d3.select(element).on('mousewheel', zoom)

    # Function pair to allow for easy hiding and showing the time slider
    hide: ->
        @originalDisplay = @element.style.display
        @element.style.display = 'none'
        true

    show: ->
        @element.style.display = @originalDisplay
        true

    select: (params...) ->
        start = new Date(params[0])
        start = @options.start if start < @options.start

        end = new Date(params[1])
        end = @options.end if end > @options.end

        d3.select(@element).select('g.brush').call(@brush.extent([start, end]))
        true
    
# Export the TimeSlider object for use in the browser
this.TimeSlider = TimeSlider
