if __FILE__ == $0
  # First, handle some command line options
  no_serial_port = ARGV.find {|elem| elem == "-no-serial"}
  if !no_serial_port.nil?
    $no_serial = true
  else
    $no_serial = false
  end

  $serial_port = nil
  change_serial_port = ARGV.find {|elem| elem =~ /-serial-port=.*/}
  if !change_serial_port.nil?
    new_serial_port = change_serial_port.sub(/-serial-port=/, "");
    if !new_serial_port.empty? then $serial_port = new_serial_port end
  end

  $osc_server_0 = $osc_server_1 = nil
  change_server = ARGV.find_all {|elem| elem =~ /-server[0-9]+=.*/ }
  change_server.each do |parameter|
    command = parameter.match(/-server[0-9]+/)[0]
    value = parameter.sub(command + '=', '')
    case command
      when '-server0'
        $osc_server_0 = value
      when '-server1'
        $osc_server_1 = value
    end
  end
end

require 'rubygems'
require 'fox16'
require 'fox16/colors'
require 'ht_server'

module HumanTheremin

  class HTGUI < Fox::FXMainWindow
    include Fox

    attr_reader :server

    def initialize(app, ht_server)
      super(app, "Human Theremin GUI", :width => 485, :height => 375)
      @server = ht_server
      @rf_controls = []
      initialize_default_widget_state
      initialize_callbacks
    end

    def initialize_default_widget_state
      FXVerticalFrame.new(self, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y, :padding => 0) do |v_frame|
        FXHorizontalFrame.new(v_frame, :padding => 10) do |top_frame|
          FXVerticalFrame.new(top_frame, :vSpacing => 7, :opts => FRAME_SUNKEN, :padding => 10) do |rf_frame|
            rfs = @server.rangefinders
            rfs.each_index do |index|
              FXHorizontalFrame.new(rf_frame, :opts => FRAME_LINE, :padding => 5, :hSpacing => 15) do |box|
                FXLabel.new(box, "Rangefinder #{index} value")
                FXTextField.new(box, 5, :selector => index, :opts => TEXTFIELD_INTEGER|TEXTFIELD_NORMAL) do |text_field|
                  text_field.text = rfs[index].to_s
                  text_field.connect(SEL_CHANGED, method(:on_text_change))
                  @rf_controls << text_field
                end
              end
            end
          end
          FXVerticalFrame.new(top_frame, :padLeft => 15) do |controls_frame|
            FXVerticalFrame.new(controls_frame, :opts => FRAME_GROOVE) do |osc_controls|
              FXLabel.new(osc_controls, "OSC port:  press Set to change")
              FXHorizontalFrame.new(osc_controls, :hSpacing => 15) do |osc_subpanel|
                @osc_set_field = FXTextField.new(osc_subpanel, 5, :opts => TEXTFIELD_INTEGER|TEXTFIELD_NORMAL)
                FXButton.new(osc_subpanel, "Set") do |button|
                  button.connect(SEL_COMMAND, method(:set_osc_port))
                end
              end
              @osc_port_label = FXLabel.new(osc_controls, "Current OSC port:  #{@server.osc_clients[0].osc_port}")
            end
          end
        end
        FXVerticalFrame.new(v_frame, :padLeft => 15) do |bottom_frame|
          @osc_warning_label0 = FXLabel.new(bottom_frame, "") {|label| label.textColor = FXColor::Red }
          @osc_warning_label1 = FXLabel.new(bottom_frame, "") {|label| label.textColor = FXColor::Red }
          @serial_warning_label = FXLabel.new(bottom_frame, "") {|label| label.textColor = FXColor::Red }
        end
      end
    end
    protected :initialize_default_widget_state

    def initialize_callbacks
      @server.register_rf_callback(&method(:on_rf_change))
      @server.osc_clients[0].register_warning_callback {|message| on_osc_warning(0, message) }
      @server.osc_clients[1].register_warning_callback {|message| on_osc_warning(1, message) }
    end
    protected :initialize_callbacks

    def create
      super
      show(PLACEMENT_DEFAULT)
    end

    def set_osc_port(sender, sel, data)
      new_port = @osc_set_field.text.to_i
      @server.osc_clients[0].osc_port = new_port
      @server.osc_clients[1].osc_port = new_port + 1
      @osc_port_label.text = "Current OSC port:  #{new_port}"
    end
    protected :set_osc_port

    def on_osc_warning(osc_client_id, warning_text)
      case osc_client_id
        when 0
          @osc_warning_label0.text = warning_text
        when 1
          @osc_warning_label1.text = warning_text
      end
    end
    protected :on_osc_warning

    def on_rf_change(rf_id, new_value)
      if rf_id < @rf_controls.length
        @rf_controls[rf_id].text = new_value.to_s
      end
    end
    protected :on_rf_change

    def on_text_change(sender, sel, data)
      @server.set_rf_value(FXSELID(sel), data.to_i)
    end
    protected :on_text_change

    def self::run_app(ht_server)
      FXApp.new("Human Theremin GUI") do |app|
        self.new(app, ht_server)
        app.create
        app.run
      end
    end
  end

end

if __FILE__ == $0
  HumanTheremin::HTGUI.run_app(HumanTheremin::HTServer.new)
end
