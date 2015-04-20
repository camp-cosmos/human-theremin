require 'ht_osc_client'

# Hack: ht_serial_port_listener.rb requires the ruby-serialport gem, which is a hassle to install.  The serial
#  port support can be switched off using a command line option, so if that option is set we prevent this file
#  from being required so that a user can avoid installing ruby-serialport if they don't actually need that support.
unless $no_serial == true
  require 'ht_serial_port_listener'
end

module HumanTheremin

  class HTServer
    DEFAULT_NUM_RANGEFINDERS = 5
    DEFAULT_INITIAL_RANGEFINDER_VALUE = 0
    DEFAULT_AUTOMATED = false
    DEFAULT_SERIAL_PORT = 0
    DEFAULT_OSC_PORT = 57120
    DEFAULT_SERVER = '127.0.0.1'

    attr_accessor :automated
    attr_reader :rangefinders, :osc_clients, :serial_port_listener

    def initialize(init_num_rf = DEFAULT_NUM_RANGEFINDERS, init_rf_value = DEFAULT_INITIAL_RANGEFINDER_VALUE,
                   init_auto = DEFAULT_AUTOMATED, init_serial = DEFAULT_SERIAL_PORT, init_osc = DEFAULT_OSC_PORT)
      @rangefinders = Array.new(init_num_rf, init_rf_value)
      @automated = init_auto
      @rf_callbacks = []

      server0 = if $osc_server_0.nil? then DEFAULT_SERVER else $osc_server_0 end
      server1 = if $osc_server_1.nil? then DEFAULT_SERVER else $osc_server_1 end
      @osc_clients = [] << HTOSCClient.new(self, server0, init_osc) << HTOSCClient.new(self, server1, init_osc + 1);

      # Hack: See note above about serial port support
      unless $no_serial == true
        @serial_port_listener = HTSerialPortListener.new(self)
      end
    end

    def register_rf_callback(&block)
      @rf_callbacks << block
    end

    def set_rf_value(rf_id, new_value)
      unless rf_id >= @rangefinders.size || rf_id < 0
        @rangefinders[rf_id] = new_value
        on_rf_set(rf_id, new_value)
      end
    end

    def on_rf_set(rf_id, new_val)
      @rf_callbacks.each do |callback|
        callback.call(rf_id, new_val)
      end
    end
    protected :on_rf_set
  end

end
