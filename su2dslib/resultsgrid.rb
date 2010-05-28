#require "su2dslib/exportbase.rb" ## not needed if SU2DS module used
require "wxSU/lib/Startup"

module SU2DS

## this class imports and displays DAYSIM analysis results
## new for su2ds

class ResultsGrid < ExportBase
    
    def initialize
        @lines = []  ## array of DAYSIM results read from Daysim output file
        @xLines = [] ## @lines array sorted in order of ascending x coordinates
        @yLines = [] ## @lines array sorted in order of ascending y coordinates
        @spacing = 0 ## analysis grid spacing
        @minV = 0    ## minimum value of results
        @maxV = 0    ## maximum value of results
        @aveV = 0    ## average value of results
        @model = Sketchup.active_model
        # @resLayerName = getLayerName('results') ## get unique layer name for results layer
        # @resLayer = @model.layers.add(@resLayerName)
        # @resLayer.set_attribute("layerData", "results", true)
        @entities = @model.entities
        # @resultsGroup = @entities.add_group
        # @resultsGroup.layer = @resLayerName
        $nameContext = [] ## added for ExportBase.uimessage to work
        $log = [] ## no log implemented at this point; again, justed added for ExportBase.uimessage
    end
    
    ## read and pre-process DAYSIM results
    def readResults 
        ## get file path
        resPath = "#{@model.get_attribute("modelData", "exportDir")}\\#{@model.get_attribute("modelData", "projectName")}\\res\\"
        begin
            @path = UI.openpanel("select results file", resPath, "*.DA")
        rescue
            @path = UI.openpanel("select results file",'','')
        end
        if not @path
            uimessage("import cancelled")
            return false
        end
        ## read file
        f = File.new(@path)
        @lines = f.readlines
        f.close
        ## create results layers and groups
        makeLayersGroups
        ## process line data
        cleanLines
        processLines
        return true
    end
    
    ## check for scene rotation angle
    def rotCheck
        # check if exporting for Daysim v3.0; if so, rotating points not necessary, so return false
        if $DS_VERSION == '3.0'
            return false
        end
        
        # get path of rotated geometry file, from which rotation angle will be read
        rotRadName = "#{File.basename(@path).split(/\./)[0]}.rad.rotated.rad"
        rotRadPath = "#{File.expand_path("./..", File.dirname(@path))}/#{rotRadName}"
        
        # read rotation angle
        if File.exists?(rotRadPath)
            f = File.new(rotRadPath)
            lines = f.readlines
            f.close
            @rotation = lines[0].split[-1].strip.to_f
            return true
        else
            return false
        end
    end
    
    ## create groups and layers for import
    def makeLayersGroups
        @resLayerName = getLayerName('results') ## get unique layer name for results layer
        @resLayer = @model.layers.add(@resLayerName)
        @resLayer.set_attribute("layerData", "results", true)
        @resultsGroup = @entities.add_group
        @resultsGroup.layer = @resLayerName
    end 
    
    ## convert numbers to floats, remove comments lines and such
    def cleanLines
        newlines = []
        @lines.each { |l|
            # skip comment lines
            if l.strip[0,1] == "#"
                next
            end
            parts = l.split
            begin
                parts.collect! { |p| p.to_f}
                newlines.push(parts)
            rescue
                uimessage("line ignored: '#{l}'")
            end
        }
        @lines = newlines
    end
    
    ## calculate @xLines, @yLines, @spacing, @minV, @maxV
    def processLines
        # rotate points if necessary
        if rotCheck
            rotLines
        end
        # create @xLines and @yLines
        @xLines = @lines.sort
        @yLines = @lines.sort { |x,y|
            [x[1], x[0], x[2], x[3]] <=> [y[1], y[0], y[2], y[3]]
        }
        x = []
        v = []
        sum = 0
        # calculate @minV, @maxV, and @aveV
        @lines.collect { |l|
            v.push(l[3])
            sum += l[3]
        }
        v.sort!
        @minV = v[0]
        @maxV = v[v.length - 1]
        @aveV = sum / v.length
        @resLayer.set_attribute("layerData", "resMinMax", [@minV, @maxV]) ## stored for scale generation and adjustment
        @resLayer.set_attribute("layerData", "resAve", @aveV)
        # calculate spacing
        @xLines.each_index { |i|
            if (@xLines[i][0] * 1000).round != (@xLines[i+1][0] * 1000).round
                if i == (@xLines.length - 1)
                    uimessage("improperly formatted grid; grid spacing could not be calculated")
                    break
                end
                @spacing = @xLines[i+1][0] - @xLines[i][0]
                break
            else
                next
            end
        }
    end
    
    ## rotates results grids (needed for when importing results from a model rotated
    ## by modifying the north angle; results need to be brought back to model coordinates)
    def rotLines
        # create Transformation
        origin = [0,0,0]
        axis = Geom::Vector3d.new(0,0,1)
        angle = -@rotation * Math::PI / 180
        rot = Geom::Transformation.rotation(origin, axis, angle)
        
        # rotate points
        @lines.each { |l|
            pt = [l[0]/$UNIT, l[1]/$UNIT, l[2]/$UNIT]
            pt.transform!(rot)
            l[0] = (pt.x.to_f * $UNIT * 1000).round.to_f / 1000
            l[1] = (pt.y.to_f * $UNIT * 1000).round.to_f / 1000
            l[2] = (pt.z.to_f * $UNIT * 1000).round.to_f / 1000
        }
    end
    
    ## hides any results layers that are visible
    def hideResLayers
        layers = @model.layers
        layers.each { |l|
            if l.visible? && l.get_attribute("layerData", "results") && l != @resLayer
                l.visible = false 
            end
        }
    end
    
    ## draw coloured grid representing results
    def drawGrid
        hideResLayers ## hides any results layers that are visible
        @model.start_operation("task", true) ## suppress UI updating, for speed
        
        # create "north-south" grid lines
        #t = Time.now ## for benchmarking
        @xLines.each_index { |i|    
            if i == (@xLines.length - 1)
                next
            end
            # check if next point on same "north-south" line
            if (@xLines[i][0] * 1000).round == (@xLines[i+1][0] * 1000).round
                # check if next point spaced at @spacing
                if ((@xLines[i][1] + @spacing) * 1000).round == (@xLines[i+1][1] * 1000).round
                    # check if z-coordinate equal
                    if @xLines[i][2] == @xLines[i+1][2]
                        # create geometry
                        createEdge(@xLines[i], @xLines[i+1], false)
                    end
                end
            end        
        }
        #puts "North-south time: #{Time.now - t}" ## for benchmarking
        
        # create "east-west" grid lines
        t = Time.now ## for benchmarking     
        @yLines.each_index { |i|
            if i == (@yLines.length - 1)
                next
            end
            # check if next point on same "east-west" line
            if (@yLines[i][1] * 1000).round == (@yLines[i+1][1] * 1000).round
                # check if next point spaced at @spacing
                if ((@yLines[i][0] + @spacing) * 1000).round == (@yLines[i+1][0] * 1000).round
                    # check if z-coordinate equal
                    if @yLines[i][2] == @yLines[i+1][2]
                        # create geometry
                        createEdge(@yLines[i], @yLines[i+1], true)
                    end
                end
            end        
        }
        #puts "East-west time: #{Time.now - t}" ## for benchmarking
        
        @model.start_operation("task", false) ## turn UI updating back on
        @model.active_layer = @resLayer ## sets results layer to current layer
        @model.active_view.refresh ## refresh view
        puts ## hack -- stops @yLines from being output to Ruby console   
    end
    
    ## create Sketchup::Edge object between two points, create any possible faces and
    ## colour faces appropriately
    def createEdge(pt1, pt2, checkFace = true)
        # convert coordinates to Sketchup units
        ptc = [pt1[0..2], pt2[0..2]].each { |p| p.collect! { |e| e/$UNIT}}
        # create edge
        edges = @resultsGroup.entities.add_edges(ptc[0], ptc[1])
        # set edge characteristics, and draw faces
        edges.each { |e|
            e.layer = @resLayerName
            e.hidden = true
            value = (pt1[3] + pt2[3]) / 2
            e.set_attribute("edgeData", "value", value)
            # draw faces
            if checkFace
                if e.find_faces > 0
                    faces = e.faces
                    faces.each { |f|
                        processFace(f)
                    }
                end
            end
        } 
    end
    
    ## process Faces (ie, set characteristics)
    def processFace(f)
        if f.edges.length > 4
            f.erase!
        else
            f.layer = @resLayerName
            val = 0
            f.edges.each { |e|
                val += e.get_attribute("edgeData", "value") / 4
            }
            f.set_attribute("faceData", "value", val)
            setColor(f, val)
        end
        
    end
    
    ## set Face color
    def setColor(f, val)
        if @maxV != @minV
            colorVal = (val - @minV) * 255 / (@maxV - @minV)
        else
            colorVal = 255/2.to_i
        end
        faceCol = Sketchup::Color.new
        faceCol.red = 127
        faceCol.blue = 127
        faceCol.green = colorVal
        f.material = faceCol
        f.back_material = f.material
    end
    
end # class

## this class is the observer that calls results scale utilies when current layer is changed
class ResultsScaleObserver < Sketchup::LayersObserver
    
    ## activate ResultsScale and ResultsPalette if "results" layer selected; if "results" layer active and 
    ## "non-results" layer selected, activates nil tool to hide results scale; does nothing if switching 
    ## between "non-results" layers
    def onCurrentLayerChanged(layers, activeLayer)
        if activeLayer.get_attribute("layerData", "results")
            if $rs == nil
                $rs = ResultsScale.new
            end
            Sketchup.active_model.select_tool($rs)
            if $rp == nil
                $rp = ResultsPalette.new
                $rp.show
            else
                $rp.refresh
            end
        elsif Sketchup.active_model.tools.active_tool_id == 50004 ## this seems to be the ID for ResultsScale...
                                                                  ## this is kind of rough, because there doesn't
                                                                  ## seem to be a way to get the previously selected
                                                                  ## layer, OR obtain the current tool (pop_tool returning
                                                                  ## TrueClass for some reason...)
            Sketchup.active_model.select_tool(nil)
        end     
    end
    
end # class
    
## this class controls the scale that gets printed to the screen when a
## results layer is selected. It is constructed as per the Sketchup API
## Tool interface
class ResultsScale  
    
    def activate
        ## get current layer name, and results min and maxes stored within layer
        @model = Sketchup.active_model
        @layer = @model.active_layer
        ## if current layer is a results layer, read attributes and set @draw to true
        ## the point of this is to prevent errors if the scale is told to draw when a 
        ## non-results layer is selected
        if @layer.get_attribute("layerData", "results") 
            @projectName = @model.get_attribute("modelData", "projectName", "Unnamed Project")
            @layerName = @layer.name
            @min = @layer.get_attribute("layerData", "resMinMax")[0]
            @max = @layer.get_attribute("layerData", "resMinMax")[1]
            @ave = @layer.get_attribute("layerData", "resAve")
            @draw = true
        else
            @draw = false
        end
    end
    
    def draw(view)
        
        if @draw
        
            ## draw text
            view.draw_text([15, 15, 0], @projectName.upcase)
            view.draw_text([15, 28, 0], @layerName)
            view.draw_text([65, 46, 0], "%3.1f" % @max)
            view.draw_text([65, 136, 0],"%3.1f" % @min)
        
            ## draw scale
            (0..9).to_a.each { |i|
                pt1 = [15, (47 + i*10), 0]
                pt2 = [60, (47 + i*10), 0]
                pt3 = [60, (57 + i*10), 0]
                pt4 = [15, (57 + i*10), 0]
                pts = [pt1, pt2, pt3, pt4]
                step = (@max - @min) / 9
                colorVal = ((@max - i*step) - @min) * 255 / (@max - @min)
                drawColor = Sketchup::Color.new(127, colorVal.to_i, 127)
                view.drawing_color = drawColor
                view.draw2d(GL_QUADS, pts)
            }
        
            ## draw average value
            if $dab != nil
                if $dab.get_value()
                    view.draw_text([15, 154, 0], 'average:')
                    view.draw_text([65, 154, 0], "%3.1f" % @ave)
                end
            end
        end
    end
    
end # class

## this class represents the window "frame" for the the Results Palette
## the Results Palette is meant to control options for the display of simulation
## results imported from DAYSIM
class ResultsPalette < Wx::Frame

    def initialize()
        
        ## set frame characteristics
        title = "Results Controls"
        #position = Wx::DEFAULT_POSITION
        screenSize = Wx::get_display_size()
        position = Wx::Point.new((screenSize.get_width() - 300), 30)
        size = Wx::Size.new(190,145)
        style = WxSU::PALETTE_FRAME_STYLE | Wx::SIMPLE_BORDER
        
        ## create frame and panel
        super(WxSU.app.sketchup_frame, -1, title, position, size, style)
        @panel = RDPanel.new(self, -1, position, size)
        
        ## define on_close method (controls window behaviour when 
        ## "close" button clicked)
        evt_close { |e| on_close(e) }
    end
    
    ## resets $rd to nil
    def on_close(e)
        self.destroy
        $rp = nil
    end
    
    # refreshes panel
    def refresh
        @panel.refMinMax
    end
end

## this class represents the "panel" for the Results Palette, which lives within
## the frame defined above, and contains the buttons and dialogs
class RDPanel < Wx::Panel
    
    def initialize(parent, id, position, size)
        
        @model = Sketchup.active_model
        layer = @model.active_layer
        begin ## note: used begin/rescue structure so that "show results palette" option could be added to menu
            @min = layer.get_attribute("layerData", "resMinMax")[0]
            @max = layer.get_attribute("layerData", "resMinMax")[1]
        rescue
            @min = 0
            @max = 0
        end
        
        ## initialize
        super(parent, id, position, size)
        
        ## max/min rescaling
		maxTCPos = Wx::Point.new(10,10)
		minTCPos = Wx::Point.new(10,35)
		maxMinTCSize = Wx::Size.new(50,20)
		@maxTC = Wx::TextCtrl.new(self, -1, "%3.1f" % @max, maxTCPos, maxMinTCSize, Wx::TE_LEFT)
		@minTC = Wx::TextCtrl.new(self, -1, "%3.1f" % @min, minTCPos, maxMinTCSize, Wx::TE_LEFT)
		
		maxSTPos = Wx::Point.new(65,12)
		minSTPos = Wx::Point.new(65,37)
		maxST = Wx::StaticText.new(self, -1, 'max', maxSTPos, Wx::DEFAULT_SIZE, Wx::ALIGN_LEFT)
		minST = Wx::StaticText.new(self, -1, 'min', minSTPos, Wx::DEFAULT_SIZE, Wx::ALIGN_LEFT)		
		
		mmbPos = Wx::Point.new(110,34)
		mmbSize = Wx::Size.new(70,20)
		mmb = Wx::Button.new(self, -1, 'redraw', mmbPos, mmbSize, Wx::BU_BOTTOM)
		evt_button(mmb.get_id()) {|e| on_redraw(e)}
		
		## "display average" option
		dabPos = Wx::Point.new(10,65)
		dabSize = Wx::Size.new(130,20)
		$dab = Wx::ToggleButton.new(self, -1, 'display average value', dabPos, dabSize)
		evt_togglebutton($dab.get_id()) { |e| on_toggle_average(e)}
		
		## "show scale" button
		ssbPos = Wx::Point.new(10,96)
		ssbSize = Wx::Size.new(110,20)
		ssb = Wx::Button.new(self, -1, 'show scale', ssbPos, ssbSize, Wx::BU_BOTTOM)
		evt_button(ssb.get_id()) { |e| on_show_scale(e)}
		
		## export image ## one day -- haven't got this figured out quite yet
        # exBPos = Wx::Point.new(10,65)
        # exBSize = Wx::Size.new(120,20)
        # exB = Wx::Button.new(self, -1, 'export image', exBPos, exBSize, Wx::BU_BOTTOM)
        # evt_button(exB.get_id()) { |e| on_export(e)}		
    end
    
    ## method to run when redraw button in Results Options palette is pressed;
    ## redraws results grid on selected layer according to max and min values entered
    ## in Results Options palette
    def on_redraw(e) ## NOTE: for some reason, you need to pass the argument, even if it isn't used
        begin
            layer = @model.active_layer
            @model.start_operation("task", true) ## suppress UI updating, for speed
            ## ensure active layer is still a results layer; if so proceed
            if layer.get_attribute("layerData", "results")
                ## reset layer max and min as per values entered in Results Palette
                newMin = @minTC.get_value().to_f
                newMax = @maxTC.get_value().to_f
                layer.set_attribute("layerData", "resMinMax", [newMin, newMax])
                @min = newMin
                @max = newMax
                
                ## iterate through model entities to get to results faces that need to be recoloured
                entities = @model.entities
                entities.each { |e|
                    if (e.layer == layer) && (e.class == Sketchup::Group)
                        e.entities.each { |f|
                            if f.class == Sketchup::Face
                                processFace(f)
                            end
                        }
                    end
                }
                
                ## reselect ResultsScale as current tool to refresh max and min
                if $rs == nil
                    $rs == ResultsScale.new
                end
                Sketchup.active_model.select_tool($rs)
                
                @model.start_operation("task", false) ## turn UI updating back on
                @model.active_view.refresh ## refresh view
            end
        rescue => ex
            puts ex.class
            puts ex
        end
            
    end
    
    ## method for recolouring face based on adjusted min and max scale values
    def processFace(f)
        val = f.get_attribute("faceData", "value")
        
        if val
            colorVal = (val - @min) * 255 / (@max - @min)
            faceCol = Sketchup::Color.new(127, colorVal.to_i, 127)
            f.material = faceCol
            f.back_material = f.material
        end
    end
    
    ## method for when "display average" buton is toggled; although the actual display of the average is
    ## controlled within ResultsScale, this refreshes the display so the user sees the change immediately
    def on_toggle_average(e)
        @model.active_view.refresh
    end
    
    ## method for showing scale (intended for when Results Pallete is up, but another tool has been
    ## selected so the results scale is no longer visible)
    def on_show_scale(e)
        if @model.active_layer.get_attribute("layerData", "results")
            if $rs == nil
                $rs = ResultsScale.new
            end
            @model.select_tool($rs)
            @model.active_view.refresh ## refresh view
        end
    end            
    
    ## refreshes panel min and max
    def refMinMax
        min = @model.active_layer.get_attribute("layerData", "resMinMax")[0]
        max = @model.active_layer.get_attribute("layerData", "resMinMax")[1]
        @minTC.set_value("%3.1f" % min)
        @maxTC.set_value("%3.1f" % max)
    end
        
    ## method for exporting image; not yet implemented; need to figure out way to include results scale
    # def on_export(e)
    #     view = Sketchup.active_model.active_view
    #     view.write_image("/Users/josh/Desktop/test_image.jpg", 900, 500, true)
    # end
    
end # class

def showMenu
    if $rp == nil
        $rp = ResultsPalette.new
        $rp.show
    end
end

end # SU2DS module