module extract_last_char (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_strings,
    input wire [3:0] string_len,
    input wire [1023:0] strings, // 8 * 128 bits = 1024 bits total
    output reg [63:0] result, // 8 * 8 bits = 64 bits total
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [63:0] next_result;
    reg next_valid;
    
    // Internal registers for output
    reg [63:0] result_reg;
    reg valid_reg;
    
    // Combinational logic for extraction
    wire [7:0] extracted_chars [0:7];
    wire [3:0] clamped_len;
    
    // Clamp length to 1-16
    // If len == 0, clamp to 1. If len > 16, clamp to 16.
    assign clamped_len = (string_len == 4'd0) ? 4'd1 : 
                         (string_len > 4'd16) ? 4'd16 : string_len;
    
    // Extract last character from each string slot in parallel
    // Each string is 128 bits (16 chars * 8 bits)
    // Last char index = clamped_len - 1
    // Bits for char i: [i*8 + 7 : i*8]
    
    generate
        genvar i;
        for (i = 0; i < 8; i = i + 1) begin : extract_loop
            wire [7:0] last_char;
            wire [3:0] pos;
            
            assign pos = clamped_len - 4'd1;
            
            // Extract character at position (clamped_len - 1) from string i
            // String i starts at bits i*128, ends at (i+1)*128 - 1
            // Character j is at bits (i*128 + j*8 + 7) : (i*128 + j*8)
            assign last_char = strings[(i*128 + pos*8 + 7) : (i*128 + pos*8)];
            assign extracted_chars[i] = last_char;
        end
    endgenerate
    
    // Combinational output packing
    // Only pack results for valid strings based on num_strings
    wire [63:0] packed_result;
    assign packed_result = {
        (num_strings > 4'd7 || num_strings == 4'd0) ? extracted_chars[7] : 8'd0,
        (num_strings > 4'd6 || num_strings == 4'd0) ? extracted_chars[6] : 8'd0,
        (num_strings > 4'd5 || num_strings == 4'd0) ? extracted_chars[5] : 8'd0,
        (num_strings > 4'd4 || num_strings == 4'd0) ? extracted_chars[4] : 8'd0,
        (num_strings > 4'd3 || num_strings == 4'd0) ? extracted_chars[3] : 8'd0,
        (num_strings > 4'd2 || num_strings == 4'd0) ? extracted_chars[2] : 8'd0,
        (num_strings > 4'd1 || num_strings == 4'd0) ? extracted_chars[1] : 8'd0,
        (num_strings > 4'd0) ? extracted_chars[0] : 8'd0
    };
    
    // State transition logic
    always @(*) begin
        next_state = state;
        next_result = result_reg;
        next_valid = valid_reg;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    next_valid = 1'b0;
                end
            end
            
            PROCESS: begin
                // Combinational processing completes in same cycle
                next_result = packed_result;
                next_valid = 1'b1;
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
                next_valid = 1'b0;
            end
            
            default: begin
                next_state = IDLE;
                next_result = 64'd0;
                next_valid = 1'b0;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result_reg <= 64'd0;
            valid_reg <= 1'b0;
            result <= 64'd0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
            result_reg <= next_result;
            valid_reg <= next_valid;
            result <= next_result;
            valid <= next_valid;
        end
    end
    
endmodule