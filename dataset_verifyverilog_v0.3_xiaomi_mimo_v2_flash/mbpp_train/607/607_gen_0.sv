module PatternMatcher (
    input clk,
    input rst_n,
    input start,
    input [5:0] text_length,
    input [3:0] pattern_length,
    input [7:0] text_char [0:63],
    input [7:0] pattern_char [0:15],
    output reg [5:0] start_index,
    output reg [5:0] end_index,
    output reg found,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SEARCHING  = 3'd1;
    localparam [2:0] COMPARING  = 3'd2;
    localparam [2:0] COMPLETE   = 3'd3;
    
    reg [2:0] state;
    reg [5:0] text_pos;          // Current position in text
    reg [3:0] pattern_pos;       // Current position in pattern
    reg [7:0] temp_text_char;
    reg [7:0] temp_pattern_char;
    reg match_found;
    
    // Maximum cycles to prevent infinite loops
    localparam [10:0] MAX_CYCLES = 11'd2048;
    reg [10:0] cycle_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            start_index <= 6'd0;
            end_index <= 6'd0;
            found <= 1'b0;
            done <= 1'b0;
            text_pos <= 6'd0;
            pattern_pos <= 4'd0;
            match_found <= 1'b0;
            cycle_count <= 11'd0;
            temp_text_char <= 8'd0;
            temp_pattern_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    text_pos <= 6'd0;
                    pattern_pos <= 4'd0;
                    match_found <= 1'b0;
                    cycle_count <= 11'd0;
                    
                    if (start) begin
                        if (pattern_length > text_length) begin
                            // Pattern too long for text
                            start_index <= 6'd64;
                            end_index <= 6'd64;
                            found <= 1'b0;
                            done <= 1'b1;
                            state <= COMPLETE;
                        end else begin
                            state <= SEARCHING;
                        end
                    end
                end
                
                SEARCHING: begin
                    done <= 1'b0;
                    
                    // Check if we've checked all possible positions
                    if (text_pos > (text_length - pattern_length)) begin
                        // No match found
                        start_index <= 6'd64;
                        end_index <= 6'd64;
                        found <= 1'b0;
                        match_found <= 1'b0;
                        done <= 1'b1;
                        state <= COMPLETE;
                    end else begin
                        // Start comparing at current text position
                        pattern_pos <= 4'd0;
                        state <= COMPARING;
                    end
                    
                    // Cycle count safety
                    if (cycle_count >= MAX_CYCLES) begin
                        start_index <= 6'd64;
                        end_index <= 6'd64;
                        found <= 1'b0;
                        done <= 1'b1;
                        state <= COMPLETE;
                    end else begin
                        cycle_count <= cycle_count + 11'd1;
                    end
                end
                
                COMPARING: begin
                    if (pattern_pos < pattern_length) begin
                        // Compare current character
                        temp_text_char <= text_char[text_pos + pattern_pos];
                        temp_pattern_char <= pattern_char[pattern_pos];
                        
                        if (text_char[text_pos + pattern_pos] == pattern_char[pattern_pos]) begin
                            // Characters match, continue to next
                            pattern_pos <= pattern_pos + 4'd1;
                            state <= COMPARING;
                        end else begin
                            // Mismatch, move to next text position
                            text_pos <= text_pos + 6'd1;
                            state <= SEARCHING;
                        end
                    end else begin
                        // All characters matched
                        start_index <= text_pos;
                        end_index <= text_pos + pattern_length;
                        found <= 1'b1;
                        match_found <= 1'b1;
                        done <= 1'b1;
                        state <= COMPLETE;
                    end
                    
                    // Cycle count safety
                    if (cycle_count >= MAX_CYCLES) begin
                        start_index <= 6'd64;
                        end_index <= 6'd64;
                        found <= 1'b0;
                        done <= 1'b1;
                        state <= COMPLETE;
                    end else begin
                        cycle_count <= cycle_count + 11'd1;
                    end
                end
                
                COMPLETE: begin
                    // Stay in complete state for one cycle
                    // The done signal is already asserted
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    start_index <= 6'd0;
                    end_index <= 6'd0;
                    found <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule