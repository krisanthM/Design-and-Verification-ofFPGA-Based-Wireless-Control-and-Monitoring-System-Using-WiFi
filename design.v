// =======================================================================
// Top Module: 8 LEDs + Sensor Response Logic (ISE COMPATIBLE) 
// =======================================================================
module uart_led_sensor_top (
    input  wire i_Clock,     // 50 MHz clock
    input  wire i_Rst,       // Active-high reset
    input  wire FPGA_RXD,     // UART RX from ESP
    output wire FPGA_TXD,     // UART TX to ESP
    output reg  [7:0] o_LEDs // Control for 8 on-board LEDs
);
// --- UART Instantiation ---
    wire       w_RX_DV;
    wire [7:0] w_RX_Byte;
    reg        r_TX_DV = 0;
    reg  [7:0] r_TX_Byte = 0;
    wire       w_TX_Active, w_TX_Done;

    uart_top #(.CLOCK_RATE(50000000), .BAUD_RATE(115200)) U_UART (
        .i_Clock(i_Clock), .i_Rst(i_Rst), .i_TX_DV(r_TX_DV), .i_TX_Byte(r_TX_Byte),
        .o_TX_Active(w_TX_Active), .o_TX_Done(w_TX_Done), .o_TX_Serial(FPGA_TXD),
        .o_RX_DV(w_RX_DV), .o_RX_Byte(w_RX_Byte), .i_RX_Serial(FPGA_RXD)
    );
	 // --- Sensor Registers ---
    reg [7:0] sensor1_val = 8'd123;
    reg [7:0] sensor2_val = 8'd205;

    // --- Transmit State Machine ---
    localparam s_TX_IDLE         = 3'b000,
               s_TX_SEND_START   = 3'b001,
               s_TX_SEND_BYTE1   = 3'b010,
               s_TX_SEND_BYTE2   = 3'b011,
               s_TX_SEND_END     = 3'b100;
    reg [2:0]  tx_state = s_TX_IDLE;
	  // --- Command Buffer and Parser ---
    reg [63:0] cmd_buffer; // 8-character buffer
    reg [3:0]  char_count;

    // --- Define command constants for comparison ---
    localparam CMD_ON1 = "ON1";
    localparam CMD_OF1 = "OF1";
    localparam CMD_ON2 = "ON2";
    localparam CMD_OF2 = "OF2";
    localparam CMD_STATUS = "STATUS";
	 
	  always @(posedge i_Clock)
    begin
        if (i_Rst) begin
            o_LEDs     <= 8'b0;
            cmd_buffer <= 0;
            char_count <= 0;
            r_TX_DV    <= 0;
            tx_state   <= s_TX_IDLE;
        end else begin
            r_TX_DV <= 0; // Default
				// 1. RECEIVE LOGIC
            if (w_RX_DV) begin
                if (w_RX_Byte == 8'h0A) begin // Check for Enter key
                    // --- PARSE Command ---
                    if (cmd_buffer[23:0] == CMD_ON1) o_LEDs[0] <= 1;
                    if (cmd_buffer[23:0] == CMD_OF1) o_LEDs[0] <= 0;
                    if (cmd_buffer[23:0] == CMD_ON2) o_LEDs[1] <= 1;
                    if (cmd_buffer[23:0] == CMD_OF2) o_LEDs[1] <= 0;
						   if (cmd_buffer[47:0] == CMD_STATUS) begin
                        if (tx_state == s_TX_IDLE) begin
                            sensor1_val <= sensor1_val + 1;
                            sensor2_val <= sensor2_val - 1;
                            tx_state <= s_TX_SEND_START;
                        end
                    end
						  cmd_buffer <= 0;
                    char_count <= 0;
                end else begin
                    cmd_buffer <= {cmd_buffer[55:0], w_RX_Byte};
                    char_count <= char_count + 1;
                end
            end
				 // 2. TRANSMIT LOGIC
            case (tx_state)
                s_TX_IDLE: begin end
                s_TX_SEND_START: begin
                    if (!w_TX_Active) begin
                        r_TX_Byte <= ">"; // Start character
                        r_TX_DV   <= 1;
                        tx_state  <= s_TX_SEND_BYTE1;
                    end
                end
					   s_TX_SEND_BYTE1: begin
                    if (w_TX_Done && !w_TX_Active) begin
                        r_TX_Byte <= sensor1_val;
                        r_TX_DV   <= 1;
                        tx_state  <= s_TX_SEND_BYTE2;
                    end
                end
					 s_TX_SEND_BYTE2: begin
                    if (w_TX_Done && !w_TX_Active) begin
                        r_TX_Byte <= sensor2_val;
                        r_TX_DV   <= 1;
                        tx_state  <= s_TX_SEND_END;
                    end
                end
					s_TX_SEND_END: begin
                    if (w_TX_Done && !w_TX_Active) begin
                        r_TX_Byte <= 8'h0A; // End character (newline)
                        r_TX_DV   <= 1;
                        tx_state  <= s_TX_IDLE;
                    end
                end
            endcase
        end
    end
endmodule