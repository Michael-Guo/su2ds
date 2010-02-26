require "su2dslib/exportbase.rb"

## this class imports and displays DAYSIM analysis results
## new for su2ds

class ResultsGrid < ExportBase
    
    def initialize
        @lines = []  ## array of DAYSIM results read from Daysim output file
        @spacing = 0 ## analysis grid spacing
        @minV = 0    ## minimum value of results
        @maxV = 0    ## maximum value of results
        @layerName = getLayerName('results') ## get unique layer name for results layer
        @entities = Sketchup.active_model.entities
        @results_group = @entities.add_group ## group for all results objects to be placed in
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
            parts = l.split
            begin
                parts.collect! { |p| p.to_f}
                newlines.push(parts)
            rescue
                uimessage("line ignored: '#{l}'")
            end
            @lines = newlines
        }
    end
    
    ## calculate @spacing, @minV, @maxV
    def processLines
        x = []
        v = []
        # extract and sort x coordinates and point values
        @lines.collect { |l|
            x.push(l[0])
            v.push(l[3])
        }
        x.sort!
        v.sort!
        # calculate spacing
        x.each_index { |i|
            if x[i] != x[i+1]
                if i == (x.length - 1)
                    uimessage("improperly formatted grid; grid spacing could not be calculated")
                    break
                end
                @spacing = x[i+1] - x[i]
                break
            else
                next
            end
        }
        # calculate @minV and @maxV
        @minV = v[0]
        @maxV = v[v.length - 1]
    end
    
    ## draw coloured grid representing results
    def drawGrid
        # add layer for results grid
        Sketchup.active_model.layers.add(@layerName)
        
        # create grid
        search = [[@spacing, 0], [0, -@spacing], [-@spacing, 0], [0, @spacing]]
        
        @lines.each_index { |i|
            search.each_index { |j|
                s = []
                s.push(i) # push index of current point onto array
                s.push(checkPoint(@lines[i], search[j])) # check for point in direction search[j] and push onto array
                if s[1] # if s[1] not nil, proceeds
                    s.push(checkPoint(@lines[i], search[j-1])) # check for point in direction search[j-1] and push onto array
                    if s[2] # if s[2] not nil, proceeds
                        s.push(checkPoint(@lines[i], [(search[j][0] + search[j-1][0]), (search[j][1] + search[j-1][1])])) # check for last point in square
                        if s[3] # if not nil, make square
                            makeSquare(s)
                        end
                    end
                end
            }
        }
        puts ## hack; added to stop @lines array from being output to Ruby console at end of import
    end
    
    ## create grid square
    def makeSquare(s)
        # read coordinates of points from @lines array based on indices in s array, convert units, and create face
        faceCoords = [@lines[s[0]][0..2], @lines[s[1]][0..2], @lines[s[3]][0..2], @lines[s[2]][0..2]]
        faceCoords.each { |c|
            c.collect! { |e| e/$UNIT }
        }
        face = @results_group.entities.add_face(faceCoords)
        face.layer = @layerName
        face.edges.each { |e|
            e.layer = @layerName
            e.hidden = true
            }
        # calculate value face should represent by average values of consituent vertices, and assign appropriate colour
        val = (@lines[s[0]][3] + @lines[s[1]][3] + @lines[s[2]][3] + @lines[s[3]][3]) / 4
        colorVal = (val - @minV) * 255 / (@maxV - @minV)
        faceCol = Sketchup::Color.new
        faceCol.red = 127
        faceCol.blue = 127
        faceCol.green = colorVal
        face.material = faceCol
        face.back_material = face.material
        #string = "red = #{face.material.color.red}\ngreen = #{face.material.color.green}\nblue = #{face.material.color.blue}" #################
        #result = UI.messagebox(string, MB_OK) ############################
    end
    
    ## checks to see if point defined by input point and xy displacement vector exists in @lines
    ## note: this has been written in a very inefficient manner; if it's slow, REWRITE!
    def checkPoint(point, vector)
        
        # calculate locaton of point to check for
        p = [(point[0] + vector[0]), (point[1] + vector[1]), point[2]]
        
        # iterate through lines and check for point -- BRUTE FORCE!
        @lines.each_index{ |i|
            # check x
            if (p[0] * 1000).round == (@lines[i][0] * 1000).round
                # check y
                if (p[1] * 1000).round == (@lines[i][1] * 1000).round
                    # check z
                    if (p[2] * 1000).round == (@lines[i][2] * 1000).round
                        # return index
                        return i
                    else
                        next
                    end
                else
                    next
                end
            else
                next
            end
        }
        
        return
    end
    
end # class