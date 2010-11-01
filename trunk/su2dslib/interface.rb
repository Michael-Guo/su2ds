require "wxSU/lib/Startup"

module SU2DS

class UserDialog
    
    attr_reader :results

    def initialize
        @prompts = []
        @vars    = []
        @values  = []
        @choices = []
        @isbool  = []
        @results = []
    end

    def addOption(prompt, var, choice='')
        @prompts.push(prompt)
        @vars.push(var)
        if var.class == TrueClass
            @values.push("yes")
            @choices.push("yes|no")
            @isbool.push(true)
        elsif var.class == FalseClass
            @values.push("no")
            @choices.push("yes|no")
            @isbool.push(true)
        else
            @values.push(var)
            @choices.push(choice)
            @isbool.push(false)
        end
    end

    def show(title='options') # this method creates box, and puts inputs in @results array
        ui = UI.inputbox(@prompts, @values, @choices, title) ## ui is an array of results returned by UI.inputbox
        if not ui ## in Ruby only nil and false evaluate to false; everything else evaluates to true
            return false # if user cancels, the results array will be nil, and show method will return false
        else
            ui.each_index { |i|  ## this bit converts instances of "yes" to true and instances of "no" to false
                if @isbool[i] == true
                    if ui[i] == 'yes' 
                        @results.push(true)
                    else
                        @results.push(false)
                    end
                else
                    @results.push(ui[i])
                end
            }
        end
        return true
    end
end

## this is the WX code for an improved preferences dialog
class PreferencesWXUI < Wx::Dialog
            
    def initialize(values)
                
        ## set dialog characteristics
        title = "Preferences dialog"
        width = 520
        height = 305
        size = Wx::Size.new(width, height)
        screenSize = Wx::get_display_size()
        position = Wx::Point.new((screenSize.get_width() - width) / 2, (screenSize.get_height() - height) / 2)
        #style = Wx::DEFAULT_DIALOG_STYLE
        style = Wx::CAPTION | Wx::SYSTEM_MENU
        name = "preferences dialog"
        
        ## create dialog
        super(WxSU.app.sketchup_frame, -1, title, position, size, style, name)
        
        ## text fields and buttons
        ## daysim version
        dvSTPos = Wx::Point.new(10,10)
        dvSTSize = Wx::Size.new(180,20)
        dvST = Wx::StaticText.new(self, -1, 'Daysim version', dvSTPos, dvSTSize, Wx::ALIGN_RIGHT)
        
        dvCPos = Wx::Point.new(200,10)
        dvCSize = Wx::Size.new(60,20)
        @dvChoices = ['2.1', '3.0']
        @dvC = Wx::Choice.new(self, -1, dvCPos, dvCSize, @dvChoices)
        @dvC.set_selection(@dvChoices.index(values[0]))
        
        ## log level
        logSTPos = Wx::Point.new(10,40)
        logSTSize = Wx::Size.new(180,20)
        logST = Wx::StaticText.new(self, -1, 'log level', logSTPos, logSTSize, Wx::ALIGN_RIGHT)
        
        logCPos = Wx::Point.new(200,40)
        logCSize = Wx::Size.new(60,20)
        @logChoices = ['0', '1', '2', '3']
        @logC = Wx::Choice.new(self, -1, logCPos, logCSize, @logChoices)
        @logC.set_selection(@logChoices.index(values[1].to_s))
        
        ## triangulate?
        triSTPos = Wx::Point.new(10,70)
        triSTSize = Wx::Size.new(180,20)
        triST = Wx::StaticText.new(self, -1, 'triangulate?', triSTPos, triSTSize, Wx::ALIGN_RIGHT)
        
        triCPos = Wx::Point.new(200,70)
        triCSize = Wx::Size.new(60,20)
        @triChoices = ['yes', 'no']
        @triC = Wx::Choice.new(self, -1, triCPos, triCSize, @triChoices)
        values[2] ? @triC.set_selection(0) : @triC.set_selection(1)
        
        ## unit
        unitSTPos = Wx::Point.new(10,100)
        unitSTSize = Wx::Size.new(180,20)
        unitST = Wx::StaticText.new(self, -1, 'unit', unitSTPos, unitSTSize, Wx::ALIGN_RIGHT)
        
        unitTCPos = Wx::Point.new(200,100)
        unitTCSize = Wx::Size.new(200,20)
        @unitTC = Wx::TextCtrl.new(self, -1, values[3].to_s, unitTCPos, unitTCSize, Wx::TE_LEFT)
        
        ## support directory
        sdSTPos = Wx::Point.new(10,130)
        sdSTSize = Wx::Size.new(180,20)
        sdST = Wx::StaticText.new(self, -1, 'support directory', sdSTPos, sdSTSize, Wx::ALIGN_RIGHT)
        
        sdTCPos = Wx::Point.new(200,130)
        sdTCSize = Wx::Size.new(200,20)
        @sdTC = Wx::TextCtrl.new(self, -1, values[4], sdTCPos, sdTCSize, Wx::TE_LEFT)
        
        sdBPos = Wx::Point.new(410,130)
        sdBSize = Wx::Size.new(100,20)
        sdButton = Wx::Button.new(self, -1, 'choose', sdBPos, sdBSize, Wx::BU_BOTTOM)
    	evt_button(sdButton.get_id()) {|e| on_sdButton(e)}
        
        ## update library?
        ulSTPos = Wx::Point.new(10,160)
        ulSTSize = Wx::Size.new(180,20)
        ulST = Wx::StaticText.new(self, -1, 'update library?', ulSTPos, ulSTSize, Wx::ALIGN_RIGHT)
        
        ulCPos = Wx::Point.new(200,160)
        ulCSize = Wx::Size.new(60,20)
        @ulChoices = ['yes', 'no']
        @ulC = Wx::Choice.new(self, -1, ulCPos, ulCSize, @ulChoices)
        values[5] ? @ulC.set_selection(0) : @ulC.set_selection(1)
        
        ## daysim binary directory
        dbSTPos = Wx::Point.new(10,190)
        dbSTSize = Wx::Size.new(180,20)
        dbST = Wx::StaticText.new(self, -1, 'Daysim binary directory', dbSTPos, dbSTSize, Wx::ALIGN_RIGHT)
        
        dbTCPos = Wx::Point.new(200,190)
        dbTCSize = Wx::Size.new(200,20)
        @dbTC = Wx::TextCtrl.new(self, -1, values[6], dbTCPos, dbTCSize, Wx::TE_LEFT)
        
        dbBPos = Wx::Point.new(410,190)
        dbBSize = Wx::Size.new(100,20)
        dbButton = Wx::Button.new(self, -1, 'choose', dbBPos, dbBSize, Wx::BU_BOTTOM)
    	evt_button(dbButton.get_id()) {|e| on_dbButton(e)}
        
        ## daysim materials directory
        mdSTPos = Wx::Point.new(10,220)
        mdSTSize = Wx::Size.new(180,20)
        mdST = Wx::StaticText.new(self, -1, 'Daysim materials directory', mdSTPos, mdSTSize, Wx::ALIGN_RIGHT)
        
        mdTCPos = Wx::Point.new(200,220)
        mdTCSize = Wx::Size.new(200,20)
        @mdTC = Wx::TextCtrl.new(self, -1, values[7], mdTCPos, mdTCSize, Wx::TE_LEFT)
        
        mdBPos = Wx::Point.new(410,220)
        mdBSize = Wx::Size.new(100,20)
        mdButton = Wx::Button.new(self, -1, 'choose', mdBPos, mdBSize, Wx::BU_BOTTOM)
    	evt_button(mdButton.get_id()) {|e| on_mdButton(e)}
        
        ## okay button (adjust vertical position based on version)
        okBPos = Wx::Point.new(200,250)
        okBSize = Wx::Size.new(100,20)
        okButton = Wx::Button.new(self, Wx::ID_OK, 'okay', okBPos, okBSize, Wx::BU_BOTTOM)
    		
    	## cancel button (adjust vertical position based on version)
        canBPos = Wx::Point.new(90,250)
        canBSize = Wx::Size.new(100,20)
        canButton = Wx::Button.new(self, Wx::ID_CANCEL, 'cancel', canBPos, canBSize, Wx::BU_BOTTOM)
        
    end
    
    ## method to be executed when "OK" button selected; returns values in array format
    def getValues
        values = []
        values << @dvChoices[@dvC.get_selection()]
        values << @logChoices[@logC.get_selection()].to_i
        values << (@triC.get_selection == 0) ? true : false
        unit = @unitTC.get_value().to_f
        if unit != 0
            values << unit
        else
            printf "unit setting not a number(#{@unitTC.get_value()}) => ignored\n"
            values << $UNIT
        end
        values << @sdTC.get_value()
        values << (@ulC.get_selection == 0) ? true : false
        values << @dbTC.get_value()
        values << @mdTC.get_value()

        return values
    end
    
    ## method for button that chooses location of support directory
	def on_sdButton(e)
	    	    
	    dd = Wx::DirDialog.new(self, "choose support directory", @sdTC.get_value())
	    if dd.show_modal == 5100
	        @sdTC.set_value(dd.get_path)
        else
            return
        end
        
    end # on_sdButton
    
    ## method for button that chooses location of daysim binary directory
	def on_dbButton(e)
	    	    
	    dd = Wx::DirDialog.new(self, "choose daysim binary directory", @dbTC.get_value())
	    if dd.show_modal == 5100
	        @dbTC.set_value(dd.get_path)
        else
            return
        end
        
    end # on_sdButton
    
    ## method for button that chooses location of daysim binary directory
	def on_mdButton(e)
	    	    
	    dd = Wx::DirDialog.new(self, "choose daysim materials directory", @mdTC.get_value())
	    if dd.show_modal == 5100
	        @mdTC.set_value(dd.get_path)
        else
            return
        end
        
    end # on_sdButton
    
end ## PreferencesDialog


## this is the WX code for an improved point mesh options dialog
class PointsWXUI < Wx::Dialog
    
    def initialize(values)
        
        title = "point mesh options"
        width = 230
        height = 125
        size = Wx::Size.new(width, height)
        screenSize = Wx::get_display_size()
        position = Wx::Point.new((screenSize.get_width() - width) / 2, (screenSize.get_height() - height) / 2)
        style = Wx::CAPTION | Wx::SYSTEM_MENU
        name = "point mesh options dialog"
        
        ## create dialog
        super(WxSU.app.sketchup_frame, -1, title, position, size, style, name)
        
        ## text fields and buttons
        ## layer
        layerSTPos = Wx::Point.new(10,10)
        layerSTSize = Wx::Size.new(100,20)
        layerST = Wx::StaticText.new(self, -1, 'points layer', layerSTPos, layerSTSize, Wx::ALIGN_RIGHT)
        
        layerTCPos = Wx::Point.new(120,10)
        layerTCSize = Wx::Size.new(100,20)
        @layerTC = Wx::TextCtrl.new(self, -1, values[0], layerTCPos, layerTCSize, Wx::TE_LEFT)
    	
    	## point density
    	densSTPos = Wx::Point.new(10,40)
        densSTSize = Wx::Size.new(100,20)
        densST = Wx::StaticText.new(self, -1, 'spacing (m)', densSTPos, densSTSize, Wx::ALIGN_RIGHT)
        
        densTCPos = Wx::Point.new(120,40)
        densTCSize = Wx::Size.new(100,20)
        @densTC = Wx::TextCtrl.new(self, -1, values[1].to_s, densTCPos, densTCSize, Wx::TE_LEFT)
    	
    	## okay and cancel buttons
        okBPos = Wx::Point.new(120,70)
        okBSize = Wx::Size.new(100,20)
        okButton = Wx::Button.new(self, Wx::ID_OK, 'okay', okBPos, okBSize, Wx::BU_BOTTOM)
    		
    	## cancel button
        canBPos = Wx::Point.new(10,70)
        canBSize = Wx::Size.new(100,20)
        canButton = Wx::Button.new(self, Wx::ID_CANCEL, 'cancel', canBPos, canBSize, Wx::BU_BOTTOM)
    	
	end   
	
	## method to be executed when "OK" button selected; returns values in array format
    def getValues
        values = []
        values << @layerTC.get_value()
        values << @densTC.get_value().to_f
        return values
    end 
	
end # PointsWXUI

## this is the WX code for an improved export options dialog
class ExportOptionsWXUI < Wx::Dialog
    
    def initialize(values)
        
        title = "Export options"
        width = 480
        height = 215
        size = Wx::Size.new(width, height)
        screenSize = Wx::get_display_size()
        position = Wx::Point.new((screenSize.get_width() - width) / 2, (screenSize.get_height() - height) / 2)
        style = Wx::CAPTION | Wx::SYSTEM_MENU
        name = "export options dialog"
        
        ## create dialog
        super(WxSU.app.sketchup_frame, -1, title, position, size, style, name)
        
        ## text fields and buttons
        ## project directory
        pdSTPos = Wx::Point.new(10,10)
        pdSTSize = Wx::Size.new(140,20)
        pdST = Wx::StaticText.new(self, -1, 'project directory', pdSTPos, pdSTSize, Wx::ALIGN_RIGHT)
        
        pdTCPos = Wx::Point.new(160,10)
        pdTCSize = Wx::Size.new(200,20)
        @pdTC = Wx::TextCtrl.new(self, -1, values["projectDirectory"], pdTCPos, pdTCSize, Wx::TE_LEFT)
        
        pdBPos = Wx::Point.new(370,10)
        pdBSize = Wx::Size.new(100,20)
        pdButton = Wx::Button.new(self, -1, 'choose', pdBPos, pdBSize, Wx::BU_BOTTOM)
    	evt_button(pdButton.get_id()) {|e| on_pdButton(e)}
    	
    	## project name
    	pnSTPos = Wx::Point.new(10,40)
        pnSTSize = Wx::Size.new(140,20)
        pnST = Wx::StaticText.new(self, -1, 'project name', pnSTPos, pnSTSize, Wx::ALIGN_RIGHT)
        
        pnTCPos = Wx::Point.new(160,40)
        pnTCSize = Wx::Size.new(200,20)
        @pnTC = Wx::TextCtrl.new(self, -1, values["projectName"], pnTCPos, pnTCSize, Wx::TE_LEFT)
        
        ## weather file
    	weaSTPos = Wx::Point.new(10,70)
        weaSTSize = Wx::Size.new(140,20)
        weaST = Wx::StaticText.new(self, -1, 'weather file', weaSTPos, weaSTSize, Wx::ALIGN_RIGHT)
        
        weaTCPos = Wx::Point.new(160,70)
        weaTCSize = Wx::Size.new(200,20)
        @weaTC = Wx::TextCtrl.new(self, -1, values["weatherFilePath"], weaTCPos, weaTCSize, Wx::TE_LEFT)
        
        weaBPos = Wx::Point.new(370,70)
        weaBSize = Wx::Size.new(100,20)
        weaButton = Wx::Button.new(self, -1, 'choose', weaBPos, weaBSize, Wx::BU_BOTTOM)
    	evt_button(weaButton.get_id()) {|e| on_weaButton(e)}
    	
    	## use present location?
    	plSTPos = Wx::Point.new(10,100)
        plSTSize = Wx::Size.new(140,20)
        plST = Wx::StaticText.new(self, -1, 'use present location?', plSTPos, plSTSize, Wx::ALIGN_RIGHT)
    	
    	plCPos = Wx::Point.new(160,100)
        plCSize = Wx::Size.new(70,20)
        @plChoices = ['yes', 'no']
        @plC = Wx::Choice.new(self, -1, plCPos, plCSize, @plChoices)
        values["usePresentLocation"] ? @plC.set_selection(0) : @plC.set_selection(1)
    	
    	## triangulate?
    	triSTPos = Wx::Point.new(10,130)
        triSTSize = Wx::Size.new(140,20)
        triST = Wx::StaticText.new(self, -1, 'triangulate?', triSTPos, triSTSize, Wx::ALIGN_RIGHT)
    	
    	triCPos = Wx::Point.new(160,130)
        triCSize = Wx::Size.new(70,20)
        @triChoices = ['yes', 'no']
        @triC = Wx::Choice.new(self, -1, triCPos, triCSize, @triChoices)
        values["triangulate"] ? @triC.set_selection(0) : @triC.set_selection(1)
    	
    	## okay and cancel buttons
        okBPos = Wx::Point.new(160,160)
        okBSize = Wx::Size.new(100,20)
        okButton = Wx::Button.new(self, Wx::ID_OK, 'okay', okBPos, okBSize, Wx::BU_BOTTOM)
    		
    	## cancel button
        canBPos = Wx::Point.new(50,160)
        canBSize = Wx::Size.new(100,20)
        canButton = Wx::Button.new(self, Wx::ID_CANCEL, 'cancel', canBPos, canBSize, Wx::BU_BOTTOM)
    	
	end
	
	## method for button that chooses location of project directory
	def on_pdButton(e)
	    	    
	    dd = Wx::DirDialog.new(self, "choose project directory", @pdTC.get_value())
	    if dd.show_modal == 5100
	        @pdTC.set_value(dd.get_path)
        else
            return
        end
        
    end # on_pdButton
	
	## method for button that chooses location of weather file
	def on_weaButton(e)
	    
	    begin ##############
	    
	    weaPath = @weaTC.get_value()
	    fileName = File.basename(weaPath)
	    (fileName.split(/\./).length > 1) ? (fileExt = fileName.split(/\./)[1].strip) : fileExt = ''
	    if fileExt == 'epw'
	        fileTypes = "EPW files (*.epw)|*.epw|WEA files (*.wea)|*.wea"
        else
            fileTypes = "WEA files (*.wea)|*.wea|EPW files (*.epw)|*.epw"
        end
	    dirName = File.dirname(weaPath)
	    	    
	    fd = Wx::FileDialog.new(self, "choose weather file", dirName, fileName, fileTypes)
	    if fd.show_modal == 5100
	        @weaTC.set_value(fd.get_path)
        else
            return
        end
        
        rescue => e ########
            puts e #########
        end ################
        
    end # on_weaButton    
	
	## method to be executed when "OK" button selected; returns values in array format
    def getValues
        #values = []
        #values << @pdTC.get_value()
        #values << @pnTC.get_value()
        #values << @weaTC.get_value()
        #values << (@plC.get_selection == 0) ? true : false
        #values << (@triC.get_selection == 0) ? true : false
        values = {  "projectDirectory" => @pdTC.get_value(),
                    "projectName" => @pnTC.get_value(),
                    "weatherFilePath" => @weaTC.get_value(),
                    "usePresentLocation" => (@plC.get_selection == 0) ? true : false,
                    "triangulate" => (@triC.get_selection == 0) ? true : false }
        return values
    end 
	
end # ExportOptionsWXUI

## this is the WX code for a simulation options dialog
class SimOptionsWXUI < Wx::Dialog
    
    def initialize(values)
        
        title = "Simulation options"
        width = 550
        height = 635
        size = Wx::Size.new(width, height)
        screenSize = Wx::get_display_size()
        position = Wx::Point.new((screenSize.get_width() - width) / 2, (screenSize.get_height() - height) / 2)
        style = Wx::CAPTION | Wx::SYSTEM_MENU
        name = "Simulation options dialog"
        
        ## create dialog
        super(WxSU.app.sketchup_frame, -1, title, position, size, style, name)
        
        ## text fields and buttons
        
        ## project information box
        piBoxPos = Wx::Point.new(10,10)
        piBoxSize = Wx::Size.new(530,120)
        piBox = Wx::StaticBox.new(self, -1, "project information", piBoxPos, piBoxSize, 0, "piBox")
        
        ## project directory
        pdSTPos = Wx::Point.new(10,35)
        pdSTSize = Wx::Size.new(200,20)
        pdST = Wx::StaticText.new(self, -1, 'project directory', pdSTPos, pdSTSize, Wx::ALIGN_RIGHT)
        
        pdTCPos = Wx::Point.new(220,35)
        pdTCSize = Wx::Size.new(200,20)
        @pdTC = Wx::TextCtrl.new(self, -1, values["projectDirectory"], pdTCPos, pdTCSize, Wx::TE_LEFT)
        
        pdBPos = Wx::Point.new(430,35)
        pdBSize = Wx::Size.new(100,20)
        pdButton = Wx::Button.new(self, -1, 'choose', pdBPos, pdBSize, Wx::BU_BOTTOM)
    	evt_button(pdButton.get_id()) {|e| on_pdButton(e)}
    	
    	## project name
    	pnSTPos = Wx::Point.new(10,65)
        pnSTSize = Wx::Size.new(200,20)
        pnST = Wx::StaticText.new(self, -1, 'project name', pnSTPos, pnSTSize, Wx::ALIGN_RIGHT)
        
        pnTCPos = Wx::Point.new(220,65)
        pnTCSize = Wx::Size.new(200,20)
        @pnTC = Wx::TextCtrl.new(self, -1, values["projectName"], pnTCPos, pnTCSize, Wx::TE_LEFT)
        
        ## triangulate?
    	triSTPos = Wx::Point.new(10,95)
        triSTSize = Wx::Size.new(200,20)
        triST = Wx::StaticText.new(self, -1, 'triangulate?', triSTPos, triSTSize, Wx::ALIGN_RIGHT)
    	
    	triCPos = Wx::Point.new(220,95)
        triCSize = Wx::Size.new(70,20)
        @triChoices = ['yes', 'no']
        @triC = Wx::Choice.new(self, -1, triCPos, triCSize, @triChoices)
        values["triangulate"] ? @triC.set_selection(0) : @triC.set_selection(1)
        
        ## site information box
        siBoxPos = Wx::Point.new(10,140)
        siBoxSize = Wx::Size.new(530,120)
        siBox = Wx::StaticBox.new(self, -1, "site information", siBoxPos, siBoxSize, 0, "siBox")
        
        ## weather file
    	weaSTPos = Wx::Point.new(10,165)
        weaSTSize = Wx::Size.new(200,20)
        weaST = Wx::StaticText.new(self, -1, 'weather file', weaSTPos, weaSTSize, Wx::ALIGN_RIGHT)
        
        weaTCPos = Wx::Point.new(220,165)
        weaTCSize = Wx::Size.new(200,20)
        @weaTC = Wx::TextCtrl.new(self, -1, values["weatherFilePath"], weaTCPos, weaTCSize, Wx::TE_LEFT)
        
        weaBPos = Wx::Point.new(430,165)
        weaBSize = Wx::Size.new(100,20)
        weaButton = Wx::Button.new(self, -1, 'choose', weaBPos, weaBSize, Wx::BU_BOTTOM)
    	evt_button(weaButton.get_id()) {|e| on_weaButton(e)}
    	
    	## use present location?
    	plSTPos = Wx::Point.new(10,195)
        plSTSize = Wx::Size.new(200,20)
        plST = Wx::StaticText.new(self, -1, 'use present location?', plSTPos, plSTSize, Wx::ALIGN_RIGHT)
    	
    	plCPos = Wx::Point.new(220,195)
        plCSize = Wx::Size.new(70,20)
        @plChoices = ['yes', 'no']
        @plC = Wx::Choice.new(self, -1, plCPos, plCSize, @plChoices)
        values["usePresentLocation"] ? @plC.set_selection(0) : @plC.set_selection(1)
    	
        ## timestep?
    	tsSTPos = Wx::Point.new(10,225)
        tsSTSize = Wx::Size.new(200,20)
        tsST = Wx::StaticText.new(self, -1, 'timestep (minutes)', tsSTPos, tsSTSize, Wx::ALIGN_RIGHT)
    	
    	tsCPos = Wx::Point.new(220,225)
        tsCSize = Wx::Size.new(70,20)
        @tsChoices = ["60", "30", "15", "5", "1"]   
        @tsC = Wx::Choice.new(self, -1, tsCPos, tsCSize, @tsChoices)
        #values[3] ? @plC.set_selection(0) : @plC.set_selection(1)
    	
    	## simulation and analysis settings box
        sasBoxPos = Wx::Point.new(10,270)
        sasBoxSize = Wx::Size.new(530,300)
        sasBox = Wx::StaticBox.new(self, -1, "simulation and analysis settings", sasBoxPos, sasBoxSize, 0, "sasBox")
    	
    	## radiance settings
    	rsSTPos = Wx::Point.new(10,295)
        rsSTSize = Wx::Size.new(200,20)
        rsST = Wx::StaticText.new(self, -1, 'simulation detail', rsSTPos, rsSTSize, Wx::ALIGN_RIGHT)
    	
    	rsCPos = Wx::Point.new(220,295)
        rsCSize = Wx::Size.new(100,20)
        @rsChoices = ["low", "medium", "high", "very high"]   
        @rsC = Wx::Choice.new(self, -1, rsCPos, rsCSize, @rsChoices)
    	
    	## occupant arrival time
    	oatSTPos = Wx::Point.new(10,325)
        oatSTSize = Wx::Size.new(200,20)
        oatST = Wx::StaticText.new(self, -1, 'occupant arrival time', oatSTPos, oatSTSize, Wx::ALIGN_RIGHT)
        
        oatTCPos = Wx::Point.new(220,325)
        oatTCSize = Wx::Size.new(45,20)
        @oatTC = Wx::TextCtrl.new(self, -1, "08.00", oatTCPos, oatTCSize, Wx::TE_LEFT)
    	
    	## occupant departure time
    	odtSTPos = Wx::Point.new(10,355)
        odtSTSize = Wx::Size.new(200,20)
        odtST = Wx::StaticText.new(self, -1, 'occupant departure time', odtSTPos, odtSTSize, Wx::ALIGN_RIGHT)
        
        odtTCPos = Wx::Point.new(220,355)
        odtTCSize = Wx::Size.new(45,20)
        @odtTC = Wx::TextCtrl.new(self, -1, "17.00", odtTCPos, odtTCSize, Wx::TE_LEFT)
    	    	
    	## lunch and breaks?
    	labSTPos = Wx::Point.new(10,385)
        labSTSize = Wx::Size.new(200,20)
        labST = Wx::StaticText.new(self, -1, 'occupant lunch and breaks?', labSTPos, labSTSize, Wx::ALIGN_RIGHT)
    	
    	labCPos = Wx::Point.new(220,385)
        labCSize = Wx::Size.new(70,20)
        @labChoices = ['yes', 'no']
        @labC = Wx::Choice.new(self, -1, labCPos, labCSize, @labChoices)
    	
    	## daylight savings time?
    	dstSTPos = Wx::Point.new(10,415)
        dstSTSize = Wx::Size.new(200,20)
        dstST = Wx::StaticText.new(self, -1, 'daylight savings time?', dstSTPos, dstSTSize, Wx::ALIGN_RIGHT)
    	
    	dstCPos = Wx::Point.new(220,415)
        dstCSize = Wx::Size.new(70,20)
        @dstChoices = ['yes', 'no']
        @dstC = Wx::Choice.new(self, -1, dstCPos, dstCSize, @dstChoices)
    	
    	## minimum illuminance level
    	miSTPos = Wx::Point.new(10,445)
        miSTSize = Wx::Size.new(200,20)
        miST = Wx::StaticText.new(self, -1, 'minimum illumninance (lux)', miSTPos, miSTSize, Wx::ALIGN_RIGHT)
        
        miTCPos = Wx::Point.new(220,445)
        miTCSize = Wx::Size.new(45,20)
        @miTC = Wx::TextCtrl.new(self, -1, "500", miTCPos, miTCSize, Wx::TE_LEFT)
    	
    	## shading device type
    	sdSTPos = Wx::Point.new(10,475)
        sdSTSize = Wx::Size.new(200,20)
        sdST = Wx::StaticText.new(self, -1, 'shading device type', sdSTPos, sdSTSize, Wx::ALIGN_RIGHT)
    	
    	sdCPos = Wx::Point.new(220,475)
        sdCSize = Wx::Size.new(280,20)
        @sdChoices = ["static (included in building geometry)", "dynamic (simple model)"]   
        @sdC = Wx::Choice.new(self, -1, sdCPos, sdCSize, @sdChoices)
    	
    	## user blind use
    	ubSTPos = Wx::Point.new(10,505)
        ubSTSize = Wx::Size.new(200,20)
        ubST = Wx::StaticText.new(self, -1, 'occupant blind use', ubSTPos, ubSTSize, Wx::ALIGN_RIGHT)
    	
    	ubCPos = Wx::Point.new(220,505)
        ubCSize = Wx::Size.new(90,20)
        @ubChoices = ["mixed", "active", "passive"]   
        @ubC = Wx::Choice.new(self, -1, ubCPos, ubCSize, @ubChoices)
    	
    	## blind controL?
    	bcSTPos = Wx::Point.new(10,535)
        bcSTSize = Wx::Size.new(200,20)
        bcST = Wx::StaticText.new(self, -1, 'blind control type', bcSTPos, bcSTSize, Wx::ALIGN_RIGHT)
    	
    	bcCPos = Wx::Point.new(220,535)
        bcCSize = Wx::Size.new(105,20)
        @bcChoices = ["no blinds", "manual", "automatic"]   
        @bcC = Wx::Choice.new(self, -1, bcCPos, bcCSize, @bcChoices)
    	
    	
    	## okay and cancel buttons
        okBPos = Wx::Point.new(220,580)
        okBSize = Wx::Size.new(100,20)
        okButton = Wx::Button.new(self, Wx::ID_OK, 'okay', okBPos, okBSize, Wx::BU_BOTTOM)
    		
    	## cancel button
        canBPos = Wx::Point.new(110,580)
        canBSize = Wx::Size.new(100,20)
        canButton = Wx::Button.new(self, Wx::ID_CANCEL, 'cancel', canBPos, canBSize, Wx::BU_BOTTOM)
    	
	end
	
	## method for button that chooses location of project directory
	def on_pdButton(e)
	    	    
	    dd = Wx::DirDialog.new(self, "choose project directory", @pdTC.get_value())
	    if dd.show_modal == 5100
	        @pdTC.set_value(dd.get_path)
        else
            return
        end
        
    end # on_pdButton
	
	## method for button that chooses location of weather file
	def on_weaButton(e)
	    
	    begin ##############
	    
	    weaPath = @weaTC.get_value()
	    fileName = File.basename(weaPath)
	    (fileName.split(/\./).length > 1) ? (fileExt = fileName.split(/\./)[1].strip) : fileExt = ''
	    if fileExt == 'epw'
	        fileTypes = "EPW files (*.epw)|*.epw|WEA files (*.wea)|*.wea"
        else
            fileTypes = "WEA files (*.wea)|*.wea|EPW files (*.epw)|*.epw"
        end
	    dirName = File.dirname(weaPath)
	    	    
	    fd = Wx::FileDialog.new(self, "choose weather file", dirName, fileName, fileTypes)
	    if fd.show_modal == 5100
	        @weaTC.set_value(fd.get_path)
        else
            return
        end
        
        rescue => e ########
            puts e #########
        end ################
        
    end # on_weaButton    
	
	## method to be executed when "OK" button selected; returns values in array format
    def getValues
        #values = []
        #values << @pdTC.get_value()
        #values << @pnTC.get_value()
        #values << @weaTC.get_value()
        #values << (@plC.get_selection == 0) ? true : false
        #values << (@triC.get_selection == 0) ? true : false
        
        values = {  "projectDirectory" => @pdTC.get_value(),
                    "projectName" => @pnTC.get_value(),
                    "weatherFilePath" => @weaTC.get_value(),
                    "usePresentLocation" => (@plC.get_selection == 0) ? true : false,
                    "triangulate" => (@triC.get_selection == 0) ? true : false, 
                    "timestep" => @tsChoices[@tsC.get_selection],
                    "radSettings" => @rsC.get_selection,
                    "occupantArrival" => @oatTC.get_value(),
                    "occupantDeparture" => @odtTC.get_value(),
                    "lunchAndBreaks" => (@labC.get_selection == 0) ? "0" : "1",
                    "minIllLevel" => @miTC.get_value(),
                    "dst" => (@dstC.get_selection == 0) ? "1" : "0",
                    "blindUse" => @ubC.get_selection,
                    "shading" => @sdC.get_selection,
                    "blindControl" => @bcC.get_selection }
        return values
    end 
	
end # SimOptionsWXUI

## this is the WX code for an improved location dialog
class LocationWXUI < Wx::Dialog
            
    def initialize(values)
        
        ## set boolean variable based on version
        ($DS_VERSION == '2.1') ? (vn = true) : (vn = false)
                
        ## set dialog characteristics
        title = "Location dialog"
        width = 250
        vn ? (height = 305) : (height = 245) ## change height of menu based on version
        size = Wx::Size.new(width, height)
        screenSize = Wx::get_display_size()
        position = Wx::Point.new((screenSize.get_width() - width) / 2, (screenSize.get_height() - height) / 2)
        #style = Wx::DEFAULT_DIALOG_STYLE
        style = Wx::CAPTION | Wx::SYSTEM_MENU
        name = "location dialog"
        
        ## create dialog
        super(WxSU.app.sketchup_frame, -1, title, position, size, style, name)
        
        ## text fields and buttons
        ## city
        citySTPos = Wx::Point.new(10,10)
        citySTSize = Wx::Size.new(110,20)
        cityST = Wx::StaticText.new(self, -1, 'city', citySTPos, citySTSize, Wx::ALIGN_RIGHT)
        
        cityTCPos = Wx::Point.new(130,10)
        cityTCSize = Wx::Size.new(100,20)
        @cityTC = Wx::TextCtrl.new(self, -1, values[0], cityTCPos, cityTCSize, Wx::TE_LEFT)
        
        ## country
        countrySTPos = Wx::Point.new(10,40)
        countrySTSize = Wx::Size.new(110,20)
        countryST = Wx::StaticText.new(self, -1, 'country', countrySTPos, countrySTSize, Wx::ALIGN_RIGHT)
        
        countryTCPos = Wx::Point.new(130,40)
        countryTCSize = Wx::Size.new(100,20)
        @countryTC = Wx::TextCtrl.new(self, -1, values[1], countryTCPos, countryTCSize, Wx::TE_LEFT)
        
        ## latitude
        latSTPos = Wx::Point.new(10,70)
        latSTSize = Wx::Size.new(110,20)
        latST = Wx::StaticText.new(self, -1, 'latitude', latSTPos, latSTSize, Wx::ALIGN_RIGHT)
        
        latTCPos = Wx::Point.new(130,70)
        latTCSize = Wx::Size.new(100,20)
        @latTC = Wx::TextCtrl.new(self, -1, values[2].to_s, latTCPos, latTCSize, Wx::TE_LEFT)
        
        ## longitude
        longSTPos = Wx::Point.new(10,100)
        longSTSize = Wx::Size.new(110,20)
        longST = Wx::StaticText.new(self, -1, 'longitude', longSTPos, longSTSize, Wx::ALIGN_RIGHT)
        
        longTCPos = Wx::Point.new(130,100)
        longTCSize = Wx::Size.new(100,20)
        @longTC = Wx::TextCtrl.new(self, -1, values[3].to_s, longTCPos, longTCSize, Wx::TE_LEFT)
        
        ## timezone offset
        tzSTPos = Wx::Point.new(10,130)
        tzSTSize = Wx::Size.new(110,20)
        tzST = Wx::StaticText.new(self, -1, 'timezone offset', tzSTPos, tzSTSize, Wx::ALIGN_RIGHT)
        
        tzCPos = Wx::Point.new(130,130)
        tzCSize = Wx::Size.new(70,20)
        @tzChoices = (-12..12).to_a.collect{ |e| e.to_s }
        @tzC = Wx::Choice.new(self, -1, tzCPos, tzCSize, @tzChoices)
        @tzC.set_selection(@tzChoices.index(values[4].to_i.to_s))
        
        ## elevation
        elevSTPos = Wx::Point.new(10,160)
        elevSTSize = Wx::Size.new(110,20)
        elevST = Wx::StaticText.new(self, -1, 'elevation', elevSTPos, elevSTSize, Wx::ALIGN_RIGHT)
        
        elevTCPos = Wx::Point.new(130,160)
        elevTCSize = Wx::Size.new(100,20)
        @elevTC = Wx::TextCtrl.new(self, -1, values[5].to_s, elevTCPos, elevTCSize, Wx::TE_LEFT)
        
        ## only display rotation options if Daysim version = 2.1
        if vn
            ## north angle
            northSTPos = Wx::Point.new(10,190)
            northSTSize = Wx::Size.new(110,20)
            northST = Wx::StaticText.new(self, -1, 'north angle', northSTPos, northSTSize, Wx::ALIGN_RIGHT)
        
            northTCPos = Wx::Point.new(130,190)
            northTCSize = Wx::Size.new(100,20)
            @northTC = Wx::TextCtrl.new(self, -1, values[6].to_s, northTCPos, northTCSize, Wx::TE_LEFT)
        
            ## show north
            snSTPos = Wx::Point.new(10,220)
            snSTSize = Wx::Size.new(110,20)
            snST = Wx::StaticText.new(self, -1, 'display north?', snSTPos, snSTSize, Wx::ALIGN_RIGHT)
        
            snCPos = Wx::Point.new(130,220)
            snCSize = Wx::Size.new(70,20)
            @snChoices = ['yes', 'no']
            @snC = Wx::Choice.new(self, -1, snCPos, snCSize, @snChoices)
            values[7] ? @snC.set_selection(0) : @snC.set_selection(1)
        end
        
        ## calculate vertical position of buttons based on version
        vn ? (bY = 255) : (bY = 195)
        
        ## okay button (adjust vertical position based on version)
        okBPos = Wx::Point.new(130,bY)
        okBSize = Wx::Size.new(100,20)
        okButton = Wx::Button.new(self, Wx::ID_OK, 'okay', okBPos, okBSize, Wx::BU_BOTTOM)
    	#evt_button(okButton.get_id()) {|e| on_okButton(e)}
    		
    	## cancel button (adjust vertical position based on version)
        canBPos = Wx::Point.new(20,bY)
        canBSize = Wx::Size.new(100,20)
        canButton = Wx::Button.new(self, Wx::ID_CANCEL, 'cancel', canBPos, canBSize, Wx::BU_BOTTOM)
        
    end
    
    ## method to be executed when "OK" button selected; returns values in array format
    def getValues
        values = []
        values << @cityTC.get_value()
        values << @countryTC.get_value()
        values << @latTC.get_value().to_f
        values << @longTC.get_value().to_f
        values << @tzChoices[@tzC.get_selection()].to_f
        values << @elevTC.get_value().to_f
        if ($DS_VERSION == '2.1')
            values << @northTC.get_value().to_f
            values << (@snC.get_selection == 0) ? true : false
        else
            values << 0
            values << false
        end
        return values
    end
    
end ## LocationDialog


end # SU2DS module    