\\ TEST BENCH                    `timescale 1ns / 1ps

module tb_uart_led_sensor;

    // Inputs
    reg i_Clock;
    reg i_Rst;
    reg FPGA_RXD;

    // Outputs
    wire FPGA_TXD;
    wire [7:0] o_LEDs;
// Instantiate the Unit Under Test (UUT)
    uart_led_sensor_top uut (
        .i_Clock(i_Clock), 
        .i_Rst(i_Rst), 
        .FPGA_RXD(FPGA_RXD), 
        .FPGA_TXD(FPGA_TXD), 
        .o_LEDs(o_LEDs)
    );

    // Define clock and baud rate constants to match the design
    localparam CLOCK_PERIOD = 20; // 50 MHz
    localparam BAUD_RATE = 115200;
    localparam BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // in nanoseconds
    // Generate the clock
    initial begin
        i_Clock = 0;
        forever #(CLOCK_PERIOD/2) i_Clock = ~i_Clock;
    end
    
    // Task to send one byte serially
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            FPGA_RXD <= 0; // Start Bit
            #(BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                FPGA_RXD <= data[i];
                #(BIT_PERIOD);
				  end
            FPGA_RXD <= 1; // Stop Bit
            #(BIT_PERIOD);
        end
    endtask
	  // Task to send a full string command
    task send_command;
        input [63:0] cmd_string;
        integer i;
        begin
            for (i=0; i<8; i=i+1) begin
                if (cmd_string[ (7-i)*8 +: 8 ] != 0) // Send chars until null
                    send_byte(cmd_string[ (7-i)*8 +: 8 ]);
            end
            send_byte(8'h0A); // Send newline to terminate command
            #1000; // Small delay between commands
        end
    endtask
	  // The main test procedure
    initial begin
        // Initialize and reset
        FPGA_RXD = 1; // Idle high
        i_Rst = 1;
        #100;
        i_Rst = 0;
        #1000;
         // --- Test Sequence ---
        $display("TEST: Sending ON1 command...");
        send_command("ON1"); // Turn on LED 0
        
        $display("TEST: Sending ON2 command...");
        send_command("ON2"); // Turn on LED 1
        
        $display("TEST: Sending OF1 command...");
        send_command("OF1"); // Turn off LED 0
        
        $display("TEST: Sending STATUS command...");
        send_command("STATUS"); // Request sensor data
		  
		   #500000; // Run for a while to see the response
        
        $display("TEST: Test complete.");
        $stop;
    end
endmodule