module filter_by_substring(
    input clk,
    input rst_n,
    input start,
    input [7:0][63:0] input_strings,
    input [63:0] substring,
    input [2:0] valid_count,
    output reg [2:0] match_indices [0:7],
    output reg [3:0] match_count,
    output reg done
);

    // FSM states
    localparam IDLE = 2'b00;
    localparam CHECK_STRING = 2'b01;
    localparam NEXT_STRING = 2'b10;
    localparam FINISH = 2'b11;
    
    reg [1:0] state, next_state;
    
    // Loop counters
    reg [2:0] string_idx;      // Current string index (0-7)
    reg [2:0] pos_idx;         // Position in string (0-7)
    reg [2:0] char_idx;        // Character index in substring (0-7)
    
    // Match tracking
    reg current_match_found;
    reg [2:0] match_write_idx; // Index for writing matches
    
    // Helper wires for current string and substring access
    wire [63:0] current_string;
    assign current_string = input_strings[string_idx];
    
    // Extract current characters (8-bit ASCII)
    wire [7:0] string_char;
    wire [7:0] substr_char;
    
    // Character extraction from 64-bit vectors
    // Each character is 8 bits, positions 0-7
    assign string_char = current_string[(pos_idx + char_idx)*8 +: 8];
    assign substr_char = substring[char_idx*8 +: 8];
    
    // Null character detection
    wire is_null;
    assign is_null = (substr_char == 8'h00);
    
    // Character match detection
    wire char_match;
    assign char_match = (string_char == substr_char);
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_STRING;
                else
                    next_state = IDLE;
            end
            
            CHECK_STRING: begin
                // If we've checked all positions for current string
                if (pos_idx == 3'd7) begin
                    next_state = NEXT_STRING;
                end else begin
                    next_state = CHECK_STRING;
                end
            end
            
            NEXT_STRING: begin
                // Check if all valid strings processed
                if (string_idx >= valid_count || string_idx == 3'd7) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_STRING;
                end
            end
            
            FINISH: begin
                // Stay in finish until reset or start goes low and high again
                if (!start)
                    next_state = IDLE;
                else
                    next_state = FINISH;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            string_idx <= 3'b0;
            pos_idx <= 3'b0;
            char_idx <= 3'b0;
            match_count <= 4'b0;
            match_write_idx <= 3'b0;
            done <= 1'b0;
            current_match_found <= 1'b0;
            // Reset match_indices
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                match_indices[i] <= 3'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for processing
                        string_idx <= 3'b0;
                        pos_idx <= 3'b0;
                        char_idx <= 3'b0;
                        match_count <= 4'b0;
                        match_write_idx <= 3'b0;
                        done <= 1'b0;
                        current_match_found <= 1'b0;
                    end
                end
                
                CHECK_STRING: begin
                    // Character-by-character comparison FSM
                    if (char_idx < 3'd7 && !is_null && substr_char != 8'h00) begin
                        // Still checking characters
                        if (char_match) begin
                            char_idx <= char_idx + 1'b1;
                            current_match_found <= 1'b1; // Tentatively match
                        end else begin
                            // Character mismatch - reset and try next position
                            char_idx <= 3'b0;
                            pos_idx <= pos_idx + 1'b1;
                            current_match_found <= 1'b0;
                        end
                    end else begin
                        // End of substring or null reached
                        if (is_null || char_match) begin
                            // Full substring matched
                            if (current_match_found || char_idx == 3'b0) begin
                                // Record match
                                match_indices[match_write_idx] <= string_idx;
                                match_write_idx <= match_write_idx + 1'b1;
                                match_count <= match_count + 1'b1;
                            end
                        end
                        
                        // Move to next position
                        char_idx <= 3'b0;
                        pos_idx <= pos_idx + 1'b1;
                        current_match_found <= 1'b0;
                    end
                end
                
                NEXT_STRING: begin
                    // Prepare for next string
                    string_idx <= string_idx + 1'b1;
                    pos_idx <= 3'b0;
                    char_idx <= 3'b0;
                    current_match_found <= 1'b0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

// Alternative simplified version with single-cycle character comparison
// This version uses combinational comparison for each position
module filter_by_substring_v2(
    input clk,
    input rst_n,
    input start,
    input [7:0][63:0] input_strings,
    input [63:0] substring,
    input [2:0] valid_count,
    output reg [2:0] match_indices [0:7],
    output reg [3:0] match_count,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam MATCH_FOUND = 3'b010;
    localparam NEXT_POS = 3'b011;
    localparam NEXT_STRING = 3'b100;
    localparam COMPLETE = 3'b101;
    
    reg [2:0] state;
    reg [2:0] str_idx;
    reg [2:0] pos;
    reg [2:0] write_idx;
    
    // Find substring in string starting at position 'pos'
    wire [63:0] check_substring;
    wire [63:0] check_string;
    wire [7:0] substring_chars [0:7];
    wire [7:0] string_chars [0:7];
    wire [7:0] compare_chars [0:7];
    wire [7:0] null_check;
    
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : extract
            assign substring_chars[i] = substring[i*8 +: 8];
            assign string_chars[i] = input_strings[str_idx][(pos + i)*8 +: 8];
            assign compare_chars[i] = (substring_chars[i] == string_chars[i]) || (substring_chars[i] == 8'h00);
            assign null_check[i] = (substring_chars[i] == 8'h00);
        end
    endgenerate
    
    wire match_all_chars;
    assign match_all_chars = &{compare_chars[0], compare_chars[1], compare_chars[2], compare_chars[3],
                               compare_chars[4], compare_chars[5], compare_chars[6], compare_chars[7]};
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            str_idx <= 3'b0;
            pos <= 3'b0;
            write_idx <= 3'b0;
            match_count <= 4'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK;
                        str_idx <= 3'b0;
                        pos <= 3'b0;
                        write_idx <= 3'b0;
                        match_count <= 4'b0;
                        done <= 1'b0;
                    end
                end
                
                CHECK: begin
                    if (match_all_chars && (valid_count > str_idx)) begin
                        state <= MATCH_FOUND;
                    end else begin
                        state <= NEXT_POS;
                    end
                end
                
                MATCH_FOUND: begin
                    match_indices[write_idx] <= str_idx;
                    write_idx <= write_idx + 1'b1;
                    match_count <= match_count + 1'b1;
                    state <= NEXT_POS;
                end
                
                NEXT_POS: begin
                    if (pos == 3'd7) begin
                        state <= NEXT_STRING;
                        pos <= 3'b0;
                    end else begin
                        pos <= pos + 1'b1;
                        state <= CHECK;
                    end
                end
                
                NEXT_STRING: begin
                    if (str_idx == 3'd7 || str_idx >= valid_count - 1) begin
                        state <= COMPLETE;
                    end else begin
                        str_idx <= str_idx + 1'b1;
                        state <= CHECK;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule