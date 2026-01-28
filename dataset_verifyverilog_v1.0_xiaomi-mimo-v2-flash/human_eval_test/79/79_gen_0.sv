module BinaryStringConverter(
    input clk,
    input rst_n,
    input start,
    input [7:0] decimal_in,
    output reg done,
    output reg [15:0][7:0] binary_str,
    output reg valid
);

// State definitions
localparam [3:0] IDLE           = 4'd0;
localparam [3:0] START_CONVERSION = 4'd1;
localparam [3:0] DIVIDE_LOOP    = 4'd2;
localparam [3:0] CONVERT_BITS   = 4'd3;
localparam [3:0] BUILD_STRING   = 4'd4;
localparam [3:0] COMPLETE       = 4'd5;

// Registers
reg [3:0] state, next_state;
reg [7:0] temp_value;
reg [7:0] bit_position;
reg [3:0] bit_index;
reg [7:0] bits_reg [0:7]; // Store extracted bits (0 or 1)
reg [7:0] cycle_count;

// Constants
localparam [7:0] SPACE_CHAR = 8'd32;  // ASCII space
localparam [7:0] CHAR_0     = 8'd48;  // ASCII '0'
localparam [7:0] CHAR_1     = 8'd49;  // ASCII '1'
localparam [7:0] CHAR_D     = 8'd100; // ASCII 'd'
localparam [7:0] CHAR_B     = 8'd98;  // ASCII 'b'
localparam [7:0] MAX_CYCLES = 8'd255; // Max cycle limit

// Temporary variables for combinatorial logic
reg [7:0] quotient;
reg [7:0] remainder;
reg [7:0] temp_val_next;
reg [7:0] bit_count;
reg [7:0] i;

// State transition and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        temp_value <= 8'd0;
        bit_position <= 8'd0;
        bit_index <= 4'd0;
        cycle_count <= 8'd0;
        // Initialize binary_str
        for (i = 0; i < 16; i = i + 1) begin
            binary_str[i] <= 8'd0;
        end
        // Initialize bits_reg
        for (i = 0; i < 8; i = i + 1) begin
            bits_reg[i] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                cycle_count <= 8'd0;
                // Clear binary_str on idle (optional, but good practice)
                for (i = 0; i < 16; i = i + 1) begin
                    binary_str[i] <= SPACE_CHAR;
                end
                if (start) begin
                    state <= START_CONVERSION;
                    temp_value <= decimal_in;
                    bit_index <= 4'd0;
                    bit_position <= 8'd0;
                    // Clear bits_reg
                    for (i = 0; i < 8; i = i + 1) begin
                        bits_reg[i] <= 8'd0;
                    end
                end
            end

            START_CONVERSION: begin
                state <= DIVIDE_LOOP;
                cycle_count <= cycle_count + 8'd1;
                // Setup for division
                temp_val_next <= temp_value;
                bit_count <= 8'd0;
            end

            DIVIDE_LOOP: begin
                cycle_count <= cycle_count + 8'd1;
                
                // Perform division by 2
                quotient = temp_val_next >> 1;  // Divide by 2
                remainder = temp_val_next & 8'd1; // Get LSB
                
                // Store remainder as extracted bit
                if (bit_count < 8'd8) begin
                    bits_reg[7 - bit_count] <= remainder; // Store MSB first
                    temp_val_next <= quotient;
                    bit_count <= bit_count + 8'd1;
                    state <= DIVIDE_LOOP;
                    if (quotient == 8'd0 && bit_count >= 8'd7) begin
                        // Complete extraction if quotient is 0
                        state <= CONVERT_BITS;
                        bit_index <= 4'd0;
                    end
                end else begin
                    state <= CONVERT_BITS;
                    bit_index <= 4'd0;
                end
            end

            CONVERT_BITS: begin
                cycle_count <= cycle_count + 8'd1;
                // Convert bits to ASCII and build string
                // First, write 'db' prefix
                binary_str[0] <= CHAR_D;
                binary_str[1] <= CHAR_B;
                
                // Write bits at positions 2-9
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < 8'd8) begin
                        if (bits_reg[i] == 8'd1) begin
                            binary_str[2 + i] <= CHAR_1;
                        end else begin
                            binary_str[2 + i] <= CHAR_0;
                        end
                    end
                end
                
                // Write 'db' suffix at positions 10, 11
                binary_str[10] <= CHAR_D;
                binary_str[11] <= CHAR_B;
                
                // Fill remaining with spaces (12-15)
                for (i = 12; i < 16; i = i + 1) begin
                    binary_str[i] <= SPACE_CHAR;
                end
                
                state <= COMPLETE;
            end

            COMPLETE: begin
                done <= 1'b1;
                valid <= 1'b1;
                state <= IDLE;
                cycle_count <= 8'd0;
            end

            default: begin
                state <= IDLE;
                done <= 1'b0;
                valid <= 1'b0;
            end
        endcase
        
        // Cycle limit check (optional safety)
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != COMPLETE) begin
            state <= COMPLETE; // Force completion to prevent infinite loops
        end
    end
end

endmodule