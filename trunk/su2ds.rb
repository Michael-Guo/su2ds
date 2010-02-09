# Sketchup To Daysim Exporter
#
# su2ds.rb
#
# Written by Josh Kjenner for Manasc Isaac
# based on su2rad by Thomas Bleicher
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA 02111-1307, USA, or go to
# http://www.gnu.org/copyleft/lesser.txt.


# revisions:


if PLATFORM =~ /darwin/
    $OS = 'MAC'
else
    $OS = 'WIN'
end

require "su2dslib/preferences.rb"
require "su2dslib/exportbase.rb"
require "su2dslib/interface.rb"
require "su2dslib/numeric.rb"
require "su2dslib/material.rb"
require "su2dslib/radiance_entities.rb"
require "su2dslib/radiancescene.rb"
require "su2dslib/location.rb"

$RADPRIMITIVES = {  "plastic"    => 1,
                    "glass"      => 1,
                    "trans"      => 1, "trans2" => 1,
                    "metal"      => 1, "metal2" => 1,
                    "glow"       => 1,
                    "light"      => 1,
                    "source"     => 1,
                    "mirror"     => 1,
                    "dielectric" => 1, "dielectric2" => 1,
                    "void"       => 1}

$testdir = ""

## reload all script files for debugging
if $DEBUG
    load "su2dslib/preferences.rb"
    load "su2dslib/exportbase.rb"
    load "su2dslib/interface.rb"
    load "su2dslib/numeric.rb"
    load "su2dslib/material.rb"
    load "su2dslib/radiance_entities.rb"
    load "su2dslib/radiancescene.rb"
    load "su2dslib/location.rb"
end

## simple method for reloading all script files from console
def loadScripts
    load "su2dslib/preferences.rb"
    load "su2dslib/exportbase.rb"
    load "su2dslib/interface.rb"
    load "su2dslib/numeric.rb"
    load "su2dslib/material.rb"
    load "su2dslib/radiance_entities.rb"
    load "su2dslib/radiancescene.rb"
    load "su2dslib/location.rb"
end


## define defaults if config file is messed up
$BUILD_MATERIAL_LIB = false
#$EXPORTALLVIEWS     = false    ## removed for su2ds
#$MAKEGLOBAL         = false    ## removed for su2ds     
$LOGLEVEL           = 0                ## don't report details
$MODE               = 'by layer'       ## "by group"|"by layer"|"by color"
$RAD                = ''
#$REPLMARKS          = '/usr/local/bin/replmarks' ## removed for su2ds
#$PREVIEW            = false       ## removed for su2ds 
#$SHOWRADOPTS        = true         ## removed for su2ds
$SUPPORTDIR         = '/Library/Application Support/Google Sketchup 7/Sketchup'
$TRIANGULATE        = false    
$UNIT               = 0.0254           ## inch (SU native unit) to meters (Radiance)
#$UTC_OFFSET         = nil          ## removed for su2ds
$ZOFFSET            = nil     

## try to load configuration from file
loadPreferences()

## define scale matrix for unit conversion
$SCALETRANS = Geom::Transformation.new(1/$UNIT)


#def startExport(selected_only=0)
def startExport ## modified for su2ds
    begin
        $MatLib = MaterialLibrary.new() # reads Sketchup material library and creates hashes mapping each material name to its path and radiance description (if available)
        rs = RadianceScene.new()
        #rs.export(selected_only)
        rs.export ## modified for su2ds
    rescue => e 
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg            
    end 
end

## new for su2ds
def startPointsExport
    begin
        rs = RadianceScene.new()
        rs.exportPoints
    rescue => e
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg
    end
end

$matConflicts = nil

def countConflicts
    if $matConflicts == nil
        $matConflicts = MaterialConflicts.new()
    end
    $matConflicts.count()
end

def resolveConflicts
    if $matConflicts == nil
        $matConflicts = MaterialConflicts.new()
    end
    $matConflicts.resolve()
end



def startImport(f='')
    ni = NumericImport.new()
    if $DEBUG
        ni.loadFile(f)
        ni.createMesh
        ni.addContourLines
        ni.addLabels
    else
        ni.loadFile
        ni.confirmDialog
    end
end

def locationDialog ## added for su2ds
    begin
        ld = LocationDialog.new()
        ld.show()
    rescue => e 
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg            
    end 
end

def preferencesDialog
    pd = PreferencesDialog.new()
    pd.showDialog()
end



def runTest
    sky = RadianceSky.new()
    sky.test()
end


if $DEBUG
    printf "debug mode\n"
else
    ## create menu entry
    begin
        if (not file_loaded?("su2ds.rb"))
            pmenu = UI.menu("Plugin")
            radmenu = pmenu.add_submenu("su2ds")
            #radmenu.add_item("export scene") { startExport(0) } ## modified for su2ds
            radmenu.add_item("create DAYSIM header file") { startExport }
            radmenu.add_item("create sensor point mesh") { startPointsExport }
            radmenu.add_item("set location") { locationDialog } ## added for su2ds
            #radmenu.add_item("export selection") { startExport(1) } ## removed for su2ds
            matmenu = radmenu.add_submenu("Material")
            matmenu.add_item("count conflicts") { countConflicts }
            matmenu.add_item("resolve conflicts") { resolveConflicts }
            importmenu = radmenu.add_submenu("Import")
            importmenu.add_item("numeric results") { startImport }
            radmenu.add_item("Preferences") { preferencesDialog() }
        end
    rescue => e
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg
        printf "su2ds: entry to menu 'Plugin' failed:\n\n%s\n" % msg
    end
    file_loaded("su2ds.rb")
end
