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
require "su2dslib/resultsgrid.rb"

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
    load "su2dslib/resultsgrid.rb"
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
    load "su2dslib/resultsgrid.rb"
end


## define defaults if config file is messed up
$DS_VERSION         = '2.1'
$BUILD_MATERIAL_LIB = false  
$LOGLEVEL           = 0                ## don't report details
$RAD                = ''
if $OS == 'WIN'
    $SUPPORTDIR = 'C:/Program Files/Google/Google SketchUp 7'
else
    $SUPPORTDIR = '/Library/Application Support/Google Sketchup 7/Sketchup'
end
$TRIANGULATE        = false    
$UNIT               = 0.0254           ## inch (SU native unit) to meters (Radiance)
$ZOFFSET            = nil     
$DAYSIM_BIN_DIR     = 'C:/DAYSIM/bin_windows'
$DAYSIM_MAT_DIR     = 'C:/DAYSIM/materials'


## try to load configuration from file
pl = SU2DS::PrefLoader.new
pl.loadPreferences()

## add observers
Sketchup.active_model.layers.add_observer(SU2DS::ResultsScaleObserver.new)

## define scale matrix for unit conversion
$SCALETRANS = Geom::Transformation.new(1/$UNIT)


def startDSExport 
    begin
        $MatLib = SU2DS::MaterialLibrary.new() # reads Sketchup material library and creates hashes mapping each material name to its path and radiance description (if available)
        rs = SU2DS::RadianceScene.new()
        rs.export ## modified for su2ds
    rescue => e 
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg            
    end 
end

## new for su2ds
def startPointsExport
    begin
        rs = SU2DS::RadianceScene.new()
        rs.exportPoints
    rescue => e
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg
    end
end

$matConflicts = nil

def countDSConflicts
    if $matConflicts == nil
        $matConflicts = SU2DS::MaterialConflicts.new()
    end
    $matConflicts.count()
end

def resolveDSConflicts
    if $matConflicts == nil
        $matConflicts = SU2DS::MaterialConflicts.new()
    end
    $matConflicts.resolve()
end



# def startImport(f='')             ## removed for su2ds
#     ni = NumericImport.new()
#     if $DEBUG
#         ni.loadFile(f)
#         ni.createMesh
#         ni.addContourLines
#         ni.addLabels
#     else
#         ni.loadFile
#         ni.confirmDialog
#     end
# end

def startDSImport
    rg = SU2DS::ResultsGrid.new
    if rg.readResults
        rg.drawGrid
    end
end

def locationDialog ## added for su2ds
    begin
        ld = SU2DS::LocationDialog.new()
        ld.show()
    rescue => e 
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg            
    end 
end

def preferencesDialogDS
    pd = SU2DS::PreferencesDialog.new()
    pd.showDialog()
end

def showResultsPalette
    if $rp == nil
        $rp = SU2DS::ResultsPalette.new
        $rp.show
    end
end    


if $DEBUG
    printf "debug mode\n"
else
    ## create menu entry
    begin
        if (not file_loaded?("su2ds.rb"))
            pmenu = UI.menu("Plugin")
            radmenu = pmenu.add_submenu("su2ds")
            radmenu.add_item("Set location") { locationDialog } ## added for su2ds            
            radmenu.add_item("Create sensor point mesh") { startPointsExport }
            radmenu.add_separator
            radmenu.add_item("Export DAYSIM header file") { startDSExport }
            radmenu.add_separator
            radmenu.add_item("Import DAYSIM results") { startDSImport }
            radmenu.add_item("Show results palette") {showResultsPalette}
            radmenu.add_separator
            matmenu = radmenu.add_submenu("Material")
            matmenu.add_item("count conflicts") { countDSConflicts }
            matmenu.add_item("resolve conflicts") { resolveDSConflicts }
            #importmenu = radmenu.add_submenu("Import")
            #importmenu.add_item("DAYSIM results") { startImport }
            radmenu.add_item("Preferences") { preferencesDialogDS }
        end
    rescue => e
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg
        printf "su2ds: entry to menu 'Plugin' failed:\n\n%s\n" % msg
    end
    file_loaded("su2ds.rb")
end
