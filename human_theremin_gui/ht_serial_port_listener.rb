require 'rubygems'
require 'serialport'
require 'ht_server'

module HumanTheremin

  class HTSerialPortListener

    if !$serial_port.nil?
      DEFAULT_SERIAL_PORT = $serial_port
    else
      DEFAULT_SERIAL_PORT = "/dev/tty.usbserial-A9007VoY"
    end

    DEFAULT_SERIAL_PORT_ACTIVE = true;
    
    BAUD_RATE = 9600
    DATA_BITS = 8
    STOP_BITS = 1
    PARITY = SerialPort::NONE

    attr_reader :serial_port, :active

    def initialize(server, serial_port = DEFAULT_SERIAL_PORT, serial_port_active = DEFAULT_SERIAL_PORT_ACTIVE)
      @server = server
      @serial_port = serial_port
      @active = serial_port_active

      if @active then start_listening end
    end

    def serial_port=(new_serial_port)
      if @active then stop_listening end

      @serial_port = new_serial_port

      if @active then start_listening end
    end

    def active=(new_active)
      if @active && !new_active
        stop_listening
        @active = false
      elsif !@active && new_active
        start_listening
        @active = true
      end
    end

    def start_listening
      @port_obj = SerialPort.new(@serial_port, 
                    {'baud' => BAUD_RATE, 'data_bits' => DATA_BITS, 'stop_bits' => STOP_BITS, 'parity' => PARITY})
      @thread = Thread.new(&method(:thread_loop))
    end
    protected :start_listening

    def stop_listening
      @thread.kill
      @port_obj.close
    end
    protected :stop_listening

    def thread_loop
      loop do
        num_reported = @port_obj.getc
        values = []
        num_reported.times do
          a_value = @port_obj.getc
          values << a_value
        end
        values.each_index {|i| @server.set_rf_value(i, values[i])}
      end
    end
    protected :thread_loop
  end

end
