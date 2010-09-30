#require "su2dslib/exportbase.rb" not needed if SU2DS module used

module SU2DS

class ObjMesh < ExportBase

    def getObjText(polymeshes)
        verts = []
        norms = []
        texuv = []
        tris  = []
        offset = 0
        polymeshes.each { |p|
            nverts = p.count_points
            i = 1
            while i <= nverts
                verts.push(p.point_at(i))
                norms.push(p.normal_at(i))
                texuv.push(p.uv_at(i))
            end
            p.polygons.each { |poly|
                v1 = poly[0] > 0 ? poly[0] : poly[0]*-1
                v2 = poly[1] > 0 ? poly[1] : poly[1]*-1
                v3 = poly[2] > 0 ? poly[2] : poly[2]*-1
                f = [v1+offset, v2+offset, v3=offset]
                ## if there are more than 3 vertices
                if poly.length == 4
                    v4 = poly[3] > 0 ? poly[3] : poly[3]*-1
                    f.push(v4+offset)
                end
                tris.push(f)
            }
            offset += nverts
        }
        lines = []
        verts.each { |v|
            lines.push("v  %.f %.f %.f" % v.to_a)
        }
        norms.each { |vn|
            lines.push("vn %.f %.f %.f" % vn.to_a)
        }
        texuv.each { |vt|
            lines.push("vt %.f %.f %.f" % vt.to_a)
        }
        tris.each { |t|
            line = "f %d/%d/%d %d/%d/%d %d/%d/%d" % [t[0],t[0],t[0],t[1],t[1],t[1],t[2],t[2],t[2]]
            if t.length == 4
                line += " %d/%d/%d" % [t[3],t[3],t[3]]
            end
            lines.push(line)
        }
        return lines.join("\n")
    end
end


class RadianceGroup < ExportBase
   
    def initialize(entity)
        @entity = entity
        uimessage("RadGroup: '%s'" % entity.name)
    end
       
    def export(parenttrans)
        entities = @entity.entities ## @entity should be a Sketchup group; this retrieves the entities from that group
        name = getUniqueName(@entity.name) ## creates unique name for group in case of duplicates
        parenttrans *= @entity.transformation
        $nameContext.push(name)
        $materialContext.push(getMaterial(@entity))
        oldglobal = $globaltrans
        $globaltrans *= @entity.transformation
        ref = exportByGroup(entities, parenttrans)
        $globaltrans = oldglobal
        $materialContext.pop()
        $nameContext.pop()
        return ref
    end
    
    ## new for su2ds
    def exportPoints(parenttrans)
        entities = @entity.entities ## @entity should be a Sketchup group; this retrieves the entities from that group
        name = getUniqueName(@entity.name) ## creates unique name for group in case of duplicates
        parenttrans *= @entity.transformation
        $nameContext.push(name)
        oldglobal = $globaltrans
        $globaltrans *= @entity.transformation
        ref = exportPointsByGroup(entities, parenttrans)
        $globaltrans = oldglobal
        $nameContext.pop()
        return ref
    end
end 


class RadianceComponent < ExportBase

    #attr_reader :replacement, :iesdata, :lampMF, :lampType
    
    def initialize(entity)
        @entity = entity
        uimessage("RadComponent: '%s' [def='%s']" % [entity.name, entity.definition.name])
        #@replacement = ''
        #@iesdata = ''
        #@lampMF = 0.8
        #@lampType = 'default'
    end
            
    # def copyDataFile(transformation)
    #     ## copy existing .dat file to './luminaires' directory
    #     cpath = @entity.path
    #     if cpath == nil or cpath == false
    #         return
    #     end
    #     datapath = cpath.sub('.skp', '.dat')
    #     if FileTest.exists?(datapath)
    #         uimessage("distribution data file '#{datapath}' found", 1)
    #     else
    #         return
    #     end
    #     datafilename = getFilename("luminaires/#{defname}.dat")
    #     if $createdFiles[datafilename] != 1
    #         f = File.new(@iesdata)
    #         datatext = f.read()
    #         f.close()
    #         if createFile(datafilename, datatext) != true
    #             uimessage("## error creating data file '#{datafilename}'")
    #             return false
    #         end
    #     end
    # end
    
    # def setLampMF(mf=0.8)
    #     #TODO: get setting from property
    #     @lampMF = mf
    # end
    
    # def setLampType(ltype='default')
    #     #TODO: check option?
    #     @lampType = ltype
    # end
    
    # def copyIESLuminaire(transformation)
    #     ies2rad = "!ies2rad -s -m %f -t %s" % [@lampMF, @lampType]
    #     ## add filename options
    #     defname = getComponentName(@entity)
    #     ies2rad = ies2rad + " -o luminaires/#{defname} luminaires/#{defname}.ies"
    #     
    #     ## copy IES file if it's not in 'luminaires/'
    #     iesfilename = getFilename("luminaires/#{defname}.ies")
    #     if $createdFiles[iesfilename] != 1
    #         f = File.new(@iesdata)
    #         iestext = f.read()
    #         f.close()
    #         if createFile(iesfilename, iestext) != true
    #             return "## error creating IES file '#{iesfilename}'\n"
    #         end
    #     end
    # 
    #     ## combine ies2rad and transformation 
    #     xform = getXform(iesfilename, transformation)
    #     xform.sub!("!xform", "| xform")
    #     xform.sub!(iesfilename, "")
    #     return ies2rad + " " + xform + "\n"
    # end
    
    # def copyReplFile(filename, transformation)
    #     #XXX
    #     suffix = @replacement[@replacement.length-4,4]
    #     defname = getComponentName(@entity)
    #     filename = getFilename("objects/#{defname}#{suffix}")
    #     
    #     f = File.new(@replacement)
    #     radtext = f.read()
    #     f.close()
    #     
    #     if $createdFiles[filename] != 1 and createFile(filename, radtext) != true
    #         msg = "Error creating replacement file '#{filename}'"
    #         uimessage(msg)
    #         return "\n## #{msg}\n"
    #     else
    #         ref = getXform(filename, transformation)
    #     end
    #     cpdata = copyDataFile(transformation)
    #     if cpdata == false
    #         msg = "Error: could not copy data file for '#{filename}'"
    #         uimessage(msg)
    #         return "\n## #{msg}\n"
    #     else
    #         return "\n" + ref
    #     end
    # end
    
    # def searchReplFile
    #     cpath = @entity.definition.path
    #     if cpath == nil or cpath == false
    #         return
    #     end
    #     if FileTest.exists?(cpath.sub('.skp', '.ies'))
    #         @iesdata = cpath.sub('.skp', '.ies')
    #         uimessage("ies data file '#{@iesdata}' found", 1)
    #     end
    #     if FileTest.exists?(cpath.sub('.skp', '.oct'))
    #         @replacement = cpath.sub('.skp', '.oct')
    #         uimessage("replacement file '#{@replacement}' found", 1)
    #     elsif FileTest.exists?(cpath.sub('.skp', '.rad'))
    #         @replacement = cpath.sub('.skp', '.rad')
    #         uimessage("replacement file '#{@replacement}' found", 1)
    #     end
    # end
    
    def export(parenttrans)
        entities = @entity.definition.entities
        #defname = getComponentName(@entity)
        iname = getUniqueName(@entity.name)
        
        mat = getMaterial(@entity) # returns entity material if it exists, nil if not
        #matname = getMaterialName(mat)  # if nil, returns $materialContext.getCurrentMaterialName();
                                        # if not, returns $materialContext.getSaveMaterialName(mat)
        #alias_name = "%s_material" % defname
        alias_name = "sketchup_default_material" ## changed for su2ds
        $materialContext.setAlias(mat, alias_name)  # sets alias_name key of @aliasHash value to mat, and alias_name key of
                                                    # @materialHash to getSaveMaterialName(mat)
        $materialContext.push(alias_name) # if alias_name isn't nil, gets name using getSaveMaterialName and adds to @nameStack

        #filename = getFilename("objects/#{iname}.rad")
        $nameContext.push(iname) ## use instance name for file
        
        #showTransformation(parenttrans)
        #showTransformation(@entity.transformation)
        parenttrans *= @entity.transformation
        #showTransformation(parenttrans)
        
        # if @iesdata != ''                         ## modified for su2ds; @iesdata and @replacement functionality
        #     ## luminaire from IES data            ## not needed
        #     ref = copyIESLuminaire(parenttrans)
        # elsif @replacement != ''
        #     ## any other replacement file
        #     ref = copyReplFile(filename, parenttrans)
        # else
        #     oldglobal = $globaltrans
        #     $globaltrans *= @entity.transformation
        #     $inComponent.push(true)
        #     #ref = exportByGroup(entities, parenttrans, false)
        #     exportByGroup(entities, parenttrans, false)
        #     $inComponent.pop()
        #     $globaltrans = oldglobal
        # end
        
        oldglobal = $globaltrans
        $globaltrans *= @entity.transformation
        $inComponent.push(true)
        exportByGroup(entities, parenttrans, false)
        $inComponent.pop()
        $globaltrans = oldglobal
        
        $materialContext.pop()
        $nameContext.pop()

        # if @replacement != '' or @iesdata != ''   ## removed for su2ds; no references used
        #     ## no alias for replacement files
        #     ## add to scene level components list
        #     $components.push(ref)
        #     return ref
        # else
        #     ref = ref.sub(defname, iname)
        #     return "\nvoid alias %s %s\n%s" % [alias_name, matname, ref]
        # end
    end
    
    # def getComponentName(e)
    #     ## find name for component instance
    #     d = e.definition
    #     if $componentNames.has_key?(d)
    #         return $componentNames[d]
    #     elsif d.name != '' and d.name != nil
    #         name = remove_spaces(d.name)
    #         $componentNames[d] = name
    #         return name
    #     else
    #         name = getUniqueName('component')
    #         $componentNames[d] = name
    #         return name
    #     end
    # end
end


class RadiancePolygon < ExportBase

    attr_reader :material, :layer
    
    def initialize(face, index=0)
        @face = face
        @layer = face.layer
        @material = getMaterial(face)
        @index = index
        @verts = []
        @triangles = []
        if $TRIANGULATE == true
            polymesh = @face.mesh 7 ## creates triangle mesh of face; this functionality is built in to Sketchup
            polymesh.polygons.each { |p| ## each polygon is described by an array of the indices of the points that form it
                verts = []
                [0,1,2].each { |i| ## iterates through each of the polygon's three vertices
                    idx = p[i]
                    if idx < 0 ## Sketchup convention is to make vertex indices negative to indicate hidden edges; this just flips negative edges
                        idx *= -1
                    end
                    verts.push(polymesh.point_at(idx)) ## adds a Point3D object (called by polymesh.point_at) to verts array
                }
                @triangles.push(verts) ## adds array of Point3D objects describing triangle face to @triangles array
            }
        else
            face.loops.each { |l| ## in Sketchup, a loop is a chain of edges describing the boundary of a face
                if l.outer? == true ## checks if loop is "outer;" each face has one outer loop, and a loop for each hole
                    @verts = l.vertices ## adds an array of Point3D objects to @verts array
                end
            }
            face.loops.each { |l|
                if l.outer? == false ## this is for holes
                    addLoop(l) ## see below
                end
            }
        end
    end
            
    def addLoop(l) ##
        ## create hole in polygon
        ## find centre of new loop
        c = getCentre(l)
        ## find closest point and split outer loop
        idx_out  = getNearestPointIndex(c, @verts)
        near_out = @verts[idx_out].position
        verts1 = @verts[0..idx_out]
        verts2 = @verts[idx_out, @verts.length] ## splits outer loop vertices into two sets delineated by vertex closest to center of hole
        ## insert vertices of loop in reverse order to create hole
        idx_in = getNearestPointIndex(near_out, l.vertices)
        verts_h = getHoleVertices(l, idx_in) ## returns array of Point3D objects describing hole
        @verts = verts1 + verts_h + verts2 ## inserts hole vertices between outer loop vertices, adding hole by basically tracing around it
    end

    def getHoleVertices(l, idx_in)
        ## create array of vertices for inner loop
        verts = l.vertices
        ## get normal for loop via cross product
        p0 = verts[idx_in].position
        if idx_in < (verts.length-1)
            p1 = verts[idx_in+1].position
        else
            p1 = verts[0].position
        end
        p2 = verts[idx_in-1].position
        v1 = Geom::Vector3d.new(p1-p0)
        v2 = Geom::Vector3d.new(p2-p0)
        normal = v2 * v1
        normal.normalize!
        ## if normal of face and hole point in same direction
        ## hole vertices must be reversed
        if normal == @face.normal
            reverse = true
        else
            dot = normal % @face.normal
        end
        ## rearrange verts to start at vertex closest to outer face
        verts1 = verts[0..idx_in]
        verts2 = verts[idx_in, verts.length]
        verts = verts2 + verts1
        if reverse == true
            verts = verts.reverse
        end
        return verts
    end
    
    def getCentre(l) ## simply averages each cartesian coordinate
        verts = l.vertices
        x_sum = 0
        y_sum = 0
        z_sum = 0
        verts.each { |v|
            x_sum += v.position.x
            y_sum += v.position.y
            z_sum += v.position.z
        }
        n = verts.length
        if n > 0
            return Geom::Point3d.new(x_sum/n, y_sum/n, z_sum/n)
        else 
            return nil
        end
    end

    def getNearestPointIndex(p, verts)
        dists = verts.collect { |v| p.distance(v.position) }
        min = dists.sort[0]
        idx = 0
        verts.each_index { |i|
            v = verts[i]
            if p.distance(v) == min
                idx = i
                break
            end
        }
        return idx
    end
   
    def getPolyMesh(trans=nil)
        polymesh = @face.mesh 7 
        if trans != nil
            polymesh.transform! trans
        end
        return polymesh
    end
        
    def getText(trans=nil)
        if $TRIANGULATE == true
            if @triangles.length == 0
                uimessage("WARNING: no triangles found for polygon")
                return ""
            end
            text = ''
            count = 0
            @triangles.each { |points|
                text += getPolygon(points, count, trans)
                count += 1
            }
        else
            points = @verts.collect { |v| v.position }
            text = getPolygon(points, 0, trans)
        end
        return text       
    end

    def getPolygon(points, count, trans)
        ## store text for byColor/byLayer export
        worldpoints = points.collect { |p| p.transform($globaltrans) }
        matname = getMaterialName(@material)
        poly = "\n%s polygon f_%d_%d\n" % [matname, @index, count]
        poly += "0\n0\n%d\n" % [worldpoints.length*3]
        worldpoints.each { |wp|
            poly += "    %f  %f  %f\n" % [wp.x*$UNIT,wp.y*$UNIT,wp.z*$UNIT]
        }
        if not $geometryHash.has_key?(matname)
            $geometryHash[matname] = []
            uimessage("new material for 'by Color': '#{matname}'")
        end
        $geometryHash[matname].push(poly)
        
    end
    
    def getNumericPoints
        polymesh = @face.mesh 7 
        polymesh.transform!($globaltrans)
        points = []
        polymesh.polygons.each { |p|
            verts = []
            [0,1,2].each { |i|
                idx = p[i]
                if idx < 0
                    idx *= -1
                end
                verts.push(polymesh.point_at(idx)) ## verts is array of Geom::Point3D objects describing each point in triangle
            }
            bbox = getbbox(*verts)  ## bbox is 4 item array with x and y coordinates of box bounding triangle in xy plane 
            z = (verts[0].z + verts[1].z + verts[2].z) / 3.0    ## surfaces inclined in the yz or xz plane discretized by first 
                                                                ## triangulating then forcing all mesh points for each triangle
                                                                ## to the same z coordinate, calculated here
            d = $point_spacing/$UNIT  ## d can essentially be read as mesh point spacing, in $UNITs 
            x = bbox[0] ## bbox[0] is minimum x value of bounding surface 
            while x <= bbox[2] ## bbox[2] = xmax            ## this is basically stepping through xy plane of surface in icrements
                y = bbox[1] ## bbox[1] = ymin               ## of d, checking if the point is in within the surface and, if so,
                while y <= bbox[3] ## bbox[3] = ymax        ## writing the point's coordinates to variable points (which is returned)
                    p = Geom::Point3d.new(x,y,z)
                    ##if Geom::point_in_polygon_2D p, verts, false ## checks if point that has been stepped to is in surface
                    if Geom::point_in_polygon_2D p, verts, true ## accept points on border to prevent points on border between adjacent polygons from being excluded
                        points.push("%.5f %.5f %.5f 0 0 1" % [p.x*$UNIT, p.y*$UNIT, p.z*$UNIT])
                        cpoint = $points_group.entities.add_cpoint(p) ## adds point to points group
                        cpoint.layer = $points_layer ## puts point on points layer
                    end
                    y += d
                end
                x += d
            end
        }
        return points
    end
    
    def getbbox(p1,p2,p3) ## p1, p2, p3 are Geom::Point3D objects
        xs = [p1.x,p2.x,p3.x]
        ys = [p1.y,p2.y,p3.y]
        xs.sort!
        ys.sort!
        d = $point_spacing
        prec = 1/d
        jitter = 0.001278   ## subtract this from xmin and ymin to make it very unlikely that a point will ever end up on
                                  ## the border of a polygon. The problem is that we want to keep points on the borders that polygons
                                  ## share with adjacent polygons, but not on borders they don't (because then they might be be right 
                                  ## in the middle of a wall polygon). Implementing the logic to check which sort of border it is would
                                  ## probably be very complimented, so instead I've assumed that if I had to pick I'd prefer to keep 
                                  ## border polygons in general (hence the modification of the boolean argument to Geom::point_in_polygon
                                  ## above), but I'd rather never have to deal with it. 
        xmin = xs[0]*$UNIT - d   
        #xmin = ((xmin*4).to_i-1) / 4.0  ## essentially rounds up/down to nearest 0.25 (in export units)
        xmin = ((xmin*prec).to_i-0.5) / prec - jitter  ## changed for su2ds
        xmax = xs[2]*$UNIT + d
        #xmax = ((xmax*4).to_i+1) / 4.0
        xmax = ((xmax*prec).to_i+0.5) / prec
        ymin = ys[0]*$UNIT - d
        #ymin = ((ymin*4).to_i-1) / 4.0
        ymin = ((ymin*prec).to_i-0.5) / prec
        ymax = ys[2]*$UNIT + d
        #ymax = ((ymax*4).to_i+1) / 4.0
        ymax = ((ymax*prec).to_i+0.5) / prec
        return [xmin/$UNIT, ymin/$UNIT, xmax/$UNIT, ymax/$UNIT]
    end
end 

end # SU2DS module