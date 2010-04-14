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

end # SU2DS module    