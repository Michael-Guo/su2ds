require "su2dslib/exportbase.rb"
require "wxSU/lib/Startup"

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
        @model = Sketchup.active_model
        @resLayerName = getLayerName('results') ## get unique layer name for results layer
        @resLayer = @model.layers.add(@resLayerName)
        @resLayer.set_attribute("layerData", "results", true)
        @entities = @model.entities
        @resultsGroup = @entities.add_group
        @resultsGroup.layer = @resLayerName
        $nameContext = [] ## added for ExportBase.uimessage to work
        $log = [] ## no log implemented at this point; again, justed added for ExportBase.uimessage
    end
    
    ## read and pre-process DAYSIM results
    def readResults 
        # get file path
        path = UI.openpanel("select results file",'','')
        if not path
            uimessage("import cancelled")
            return false
        end
        # read file
        f = File.new(path)
        @lines = f.readlines
        f.close
        cleanLines
        processLines
        return true
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
        # create @xLines and @yLines
        @xLines = @lines.sort
        @yLines = @lines.sort { |x,y|
            [x[1], x[0], x[2], x[3]] <=> [y[1], y[0], y[2], y[3]]
        }
        x = []
        v = []
        # calculate @minV and @maxV
        @lines.collect { |l|
            v.push(l[3])
        }
        v.sort!
        @minV = v[0]
        @maxV = v[v.length - 1]
        @resLayer.set_attribute("layerData", "resMinMax", [@minV, @maxV]) ## stored for scale generation and adjustment
        # calculate spacing
        @xLines.each_index { |i|
            if @xLines[i][0] != @xLines[i+1][0]
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
            if @xLines[i][0] == @xLines[i+1][0]
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
            if @yLines[i][1] == @yLines[i+1][1]
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
        colorVal = (val - @minV) * 255 / (@maxV - @minV)
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
    
    ## activate ResultsScale if "results" layer selected; if "results" layer active and "non-results"
    ## layer selected, activates nil tool to hide results scale; does nothing if switching between
    ## "non-results" layers
    def onCurrentLayerChanged(layers, activeLayer)
        if activeLayer.get_attribute("layerData", "results")
            @rs = ResultsScale.new
            Sketchup.active_model.select_tool(@rs)
        elsif Sketchup.active_model.tools.active_tool_id == 50004 ## this seems to be the ID for ResultsScale...
                                                                  ## this is kind of rough, because there doesn't
                                                                  ## seem to be a way to get the previously selected
                                                                  ## layer, OR obtain the current tool (pop_tool) returning
                                                                  ## TrueClass for some reason...
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
        @projectName = @model.get_attribute("modelData", "projectName", "Unnamed Project")
        @layerName = @layer.name
        @min = @layer.get_attribute("layerData", "resMinMax")[0]
        @max = @layer.get_attribute("layerData", "resMinMax")[1]
        @minR = (@min * 100).round.to_f / 100
        @maxR = (@max * 100).round.to_f / 100
    end
    
    def draw(view)
        
        ## draw text
        view.draw_text([15, 15, 0], @projectName.upcase)
        view.draw_text([15, 28, 0], @layerName)
        view.draw_text([65, 46, 0], @maxR.to_s)
        view.draw_text([65, 136, 0], @minR.to_s)
        
        # draw scale
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
    end
    
end # class

## this class represents the window "frame" for the the results dialog
class RDFrame < Wx::Frame

    def initialize()
        
        ## set frame characteristics
        title = "Results Controls"
        position = Wx::DEFAULT_POSITION
        size = Wx::Size.new(200,200)
        style = WxSU::PALETTE_FRAME_STYLE | Wx::SIMPLE_BORDER
        
        ## create frame and panel
        super(WxSU.app.sketchup_frame, -1, title, position, size, style)
        
        panel = RDPanel.new(self, -1, position, size)
        ## add functionality
    end
end

## this class represents the "panel" for the Results Dialog, which lives within
## the frame defined above, and contains the buttons and dialogs
class RDPanel < Wx::Panel
    
    def initialize(parent, id, position, size)
        
        @model = Sketchup.active_model
        @layer = @model.active_layer
        @min = @layer.get_attribute("layerData", "resMinMax")[0]
        @max = @layer.get_attribute("layerData", "resMinMax")[1]
        minR = (@min * 1000).round.to_f / 1000
        maxR = (@max * 1000).round.to_f / 1000
        
        ## initialize
        super(parent, id, position, size)
        
        ## max/min rescaling
		maxTCPos = Wx::Point.new(10,10)
		minTCPos = Wx::Point.new(10,35)
		maxMinTCSize = Wx::Size.new(50,20)
		@maxTC = Wx::TextCtrl.new(self, -1, maxR.to_s, maxTCPos, maxMinTCSize, Wx::TE_LEFT)
		@minTC = Wx::TextCtrl.new(self, -1, minR.to_s, minTCPos, maxMinTCSize, Wx::TE_LEFT)
		
		maxSTPos = Wx::Point.new(65,12)
		minSTPos = Wx::Point.new(65,37)
		maxST = Wx::StaticText.new(self, -1, 'max', maxSTPos, Wx::DEFAULT_SIZE, Wx::ALIGN_LEFT)
		minST = Wx::StaticText.new(self, -1, 'min', minSTPos, Wx::DEFAULT_SIZE, Wx::ALIGN_LEFT)		
		
		maxMinBPos = Wx::Point.new(110,34)
		maxMinBSize = Wx::Size.new(70,20)
		maxMinB = Wx::Button.new(self, -1, 'redraw', maxMinBPos, maxMinBSize, Wx::BU_BOTTOM)
		evt_button(maxMinB.get_id()) {|e| on_redraw(e)}
		
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
        $timelog = [] #######
        begin
            @layer = @model.active_layer
            #@model.start_operation("task", true) ## suppress UI updating, for speed
            
            ## ensure active layer is still a results layer; if so proceed
            if @layer.get_attribute("layerData", "results")
            
                # reset layer max and min as per values entered in Results Dialog
                newMin = @minTC.get_value().to_f
                newMax = @maxTC.get_value().to_f
                @layer.set_attribute("layerData", "resMinMax", [newMin, newMax])
                @min = newMin
                @max = newMax
                
                $timelog.push("#{Time.now} - starting interations ") #########
                # iterate through model entities to get to results faces that need to be recoloured
                entities = @model.entities
                entities.each { |e|
                    if (e.layer == @layer) && (e.class == Sketchup::Group)
                        e.entities.each { |f|
                            if f.class == Sketchup::Face
                                processFace(f)
                            end
                        }
                    end
                }
            end
            
            $timelog.push("#{Time.now} - iterations complete ") ########
            #@model.start_operation("task", false) ## turn UI updating back on
            #@model.active_view.refresh ## refresh view
            File.open("/Users/josh/Desktop/time.txt", "w") do |f| #######
                $timelog.each { |l|                              #######
                    f.puts l                                     #######
                }                                                #######
            end                                                  #######
        rescue => ex
            puts ex.class
            puts ex
        end
            
    end
    
    ## method for recolouring face based on adjusted min and max scale values
    def processFace(f)
        $timelog.push("#{Time.now} - getting attribute") #######
        val = f.get_attribute("faceData", "value")
        
        $timelog.push("#{Time.now} - beginning to recolour face") #######
        if val
            colorVal = (val - @min) * 255 / (@max - @min)
            faceCol = Sketchup::Color.new(127, colorVal.to_i, 127)
            f.material = faceCol
            f.back_material = faceCol
        end
        $timelog.push("#{Time.now} - face recoloured") #######
    end
        
    ## method for exporting image; not yet implemented; need to figure out way to include results scale
    # def on_export(e)
    #     view = Sketchup.active_model.active_view
    #     view.write_image("/Users/josh/Desktop/test_image.jpg", 900, 500, true)
    # end
    
end # class

def showMenu
    rd = RDFrame.new
    rd.show
end