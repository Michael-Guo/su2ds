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
        @resLayerName = getLayerName('results') ## get unique layer name for results layer
        @resLayer = Sketchup.active_model.layers.add(@resLayerName)
        @resLayer.set_attribute("layer_attributes", "results", true)
        @entities = Sketchup.active_model.entities
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
        layers = Sketchup.active_model.layers
        layers.each { |l|
            if l.visible? && l.get_attribute("layer_attributes", "results") && l != @resLayer
                l.visible = false 
            end
        }
    end
    
    ## draw coloured grid representing results
    def drawGrid
        
        hideResLayers ## hides any results layers that are visible
        Sketchup.active_model.start_operation("task", true) ## suppress UI updating, for speed
        
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
        
        Sketchup.active_model.start_operation("task", false) ## turn UI updating back on
        Sketchup.active_model.active_view.refresh ## refresh view
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
            e.set_attribute("values", "value", value)
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
                val += e.get_attribute("values", "value") / 4
            }
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

## this class represents the dialog used for interaction with the analysis results
#class ResultsDialog < Wx::Frame
    
    