require 'rubygems'
require 'osc-ruby'
require 'ht_server'
require 'thread'

module HumanTheremin

  class HTOSCClient

    MAX_QUEUE_SIZE = 16

    BASE_ADDRESS = '/HumanTheremin/Sensor'
    METHOD_NAME = '/value'
    
    attr_reader :ht_server, :osc_port, :osc_server

    def initialize(ht_server, osc_server, osc_port)
      @ht_server = ht_server
      @osc_port = osc_port
      @osc_server = osc_server
      @osc_client_lock = Mutex.new
      @queue = Queue.new
      @warning_callbacks = []
      @transmit_fault = false
      @successful_sends = 0

      @update_struct_type = Struct.new(:rf_id, :value)

      start_osc_client(osc_server, osc_port)
      start_thread
      send_all_values

      @ht_server.register_rf_callback(&method(:on_rf_change))
    end

    def osc_port=(new_osc_port)
      @osc_port = new_osc_port
      start_osc_client(@osc_server, new_osc_port)
    end
    
    def send(rf_id, val)
      while @queue.size > MAX_QUEUE_SIZE
        @queue.pop
      end
      @queue << @update_struct_type.new(rf_id, val)
    end

    def send_all_values
      @ht_server.rangefinders.each_index do |index|
        send(index, @ht_server.rangefinders[index])
      end
    end

    def get_osc_address(id)
      BASE_ADDRESS + "/#{id.to_s}" + METHOD_NAME
    end

    def register_warning_callback(&block)
      @warning_callbacks << block
    end

    def start_thread
      @thread = Thread.new(&method(:send_thread))
    end
    protected :start_thread

    def send_thread
      loop do
        update = @queue.pop
        transmit(update)
      end
    end
    protected :send_thread

    def transmit(update)
      @osc_client_lock.synchronize do
        address = get_osc_address(update.rf_id)
        message = OSC::Message.new(address, update.value)
        begin
          @osc_client.send(message)
        rescue
          @successful_sends = 0
          if !@transmit_fault
            @transmit_fault = true
            notify_osc_fault
          end
        else
          if @transmit_fault
            @successful_sends += 1
            if @successful_sends >= 3
              @transmit_fault = false
              notify_fault_cleared
            end
          end
        end
      end
    end
    protected :transmit

    def on_rf_change(rf_id, val)
      send(rf_id, val)
    end
    protected :on_rf_change

    def start_osc_client(osc_server, osc_port)
      @osc_client_lock.synchronize do
        @osc_client = OSC::Client.new(osc_server, osc_port)
        @osc_client_started = true
        @successful_sends = 0
        if @transmit_fault
          @transmit_fault = false
          notify_fault_cleared
        end
      end
    end
    protected :start_osc_client

    def notify_osc_fault
      text = "Warning: failed to transmit OSC on port #{@osc_port}"
      @warning_callbacks.each {|callback| callback.call(text) }
    end
    protected :notify_osc_fault

    def notify_fault_cleared
      @warning_callbacks.each {|callback| callback.call("") }
    end
    protected :notify_fault_cleared
  end

end
