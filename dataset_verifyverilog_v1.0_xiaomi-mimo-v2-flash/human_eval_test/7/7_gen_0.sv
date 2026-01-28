module string_filter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] strings [0:7],
    input wire [127:0] substring,
    input wire [3:0] str_len,
    output reg result_valid,
    output reg [3:0] result_count,
    output reg [127:0] result_strings [0:7]
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] SETUP_STR    = 3'd1;
    localparam [2:0] CHECK_START  = 3'd2;
    localparam [2:0] CHECK_CHAR   = 3'd3;
    localparam [2:0] MATCH_FOUND  = 3'd4;
    localparam [2:0] NO_MATCH     = 3'd5;
    localparam [2:0] OUTPUT_STATE = 3'd6;
    localparam [2:0] DONE_STATE   = 3'd7;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] str_idx;           // Which string we're processing (0-7)
    reg [3:0] start_pos;         // Starting position in string (0-15)
    reg [3:0] char_idx;          // Character index for comparison
    reg [127:0] current_str;     // Current string being checked
    reg [127:0] current_sub;     // Current substring (aligned)
    reg match_found;             // Flag if current string matches
    reg [3:0] out_count;         // Number of strings matched so far
    reg [7:0] cycle_count;       // Prevent infinite loops
    
    // Result storage
    reg [127:0] result_buf [0:7];
    reg [2:0] result_idx;        // Index for storing results
    
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [3:0] MAX_LEN = 4'd16;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SETUP_STR;
                else
                    next_state = IDLE;
            end
            
            SETUP_STR: begin
                next_state = CHECK_START;
            end
            
            CHECK_START: begin
                if (start_pos >= str_len)
                    next_state = NO_MATCH;
                else if (start_pos > 4'd15)
                    next_state = NO_MATCH;
                else
                    next_state = CHECK_CHAR;
            end
            
            CHECK_CHAR: begin
                if (char_idx >= 4'd16) begin
                    // Reached end of substring
                    if (char_idx >= str_len - start_pos)
                        next_state = NO_MATCH;
                    else
                        next_state = MATCH_FOUND;
                end else begin
                    next_state = CHECK_CHAR;
                end
            end
            
            MATCH_FOUND: begin
                next_state = OUTPUT_STATE;
            end
            
            NO_MATCH: begin
                next_state = OUTPUT_STATE;
            end
            
            OUTPUT_STATE: begin
                if (str_idx >= 4'd7)
                    next_state = DONE_STATE;
                else
                    next_state = SETUP_STR;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            result_count <= 4'd0;
            str_idx <= 3'd0;
            start_pos <= 4'd0;
            char_idx <= 4'd0;
            match_found <= 1'b0;
            out_count <= 4'd0;
            cycle_count <= 8'd0;
            result_idx <= 3'd0;
            // Initialize result strings
            result_strings[0] <= 128'd0;
            result_strings[1] <= 128'd0;
            result_strings[2] <= 128'd0;
            result_strings[3] <= 128'd0;
            result_strings[4] <= 128'd0;
            result_strings[5] <= 128'd0;
            result_strings[6] <= 128'd0;
            result_strings[7] <= 128'd0;
            result_buf[0] <= 128'd0;
            result_buf[1] <= 128'd0;
            result_buf[2] <= 128'd0;
            result_buf[3] <= 128'd0;
            result_buf[4] <= 128'd0;
            result_buf[5] <= 128'd0;
            result_buf[6] <= 128'd0;
            result_buf[7] <= 128'd0;
            current_str <= 128'd0;
            current_sub <= 128'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        str_idx <= 3'd0;
                        out_count <= 4'd0;
                        result_idx <= 3'd0;
                    end
                end
                
                SETUP_STR: begin
                    current_str <= strings[str_idx];
                    start_pos <= 4'd0;
                    match_found <= 1'b0;
                end
                
                CHECK_START: begin
                    char_idx <= 4'd0;
                    // Align substring to current start position
                    current_sub <= substring >> (start_pos * 8);
                end
                
                CHECK_CHAR: begin
                    if (char_idx < 4'd16 && char_idx < str_len - start_pos) begin
                        // Extract current character from string
                        if (current_str[7:0] != current_sub[7:0]) begin
                            // Mismatch found
                            if (char_idx < 4'd15) begin
                                // Try next starting position
                                char_idx <= 4'd16; // Force to check next start
                            end
                        end
                        // Shift for next character
                        current_str <= current_str >> 8;
                        current_sub <= current_sub >> 8;
                        char_idx <= char_idx + 4'd1;
                    end else if (char_idx >= 4'd16 && match_found == 1'b0) begin
                        // End of check without match, try next start position
                        start_pos <= start_pos + 4'd1;
                    end
                    
                    // Update match_found flag
                    if (char_idx >= 4'd16 && char_idx <= str_len - start_pos && start_pos <= 4'd15) begin
                        match_found <= 1'b1;
                    end
                end
                
                MATCH_FOUND: begin
                    match_found <= 1'b1;
                end
                
                NO_MATCH: begin
                    match_found <= 1'b0;
                end
                
                OUTPUT_STATE: begin
                    if (match_found) begin
                        result_buf[result_idx] <= strings[str_idx];
                        result_idx <= result_idx + 3'd1;
                        out_count <= out_count + 4'd1;
                    end
                    str_idx <= str_idx + 3'd1;
                end
                
                DONE_STATE: begin
                    // Copy buffer to output with proper order
                    result_strings[0] <= result_buf[0];
                    result_strings[1] <= result_buf[1];
                    result_strings[2] <= result_buf[2];
                    result_strings[3] <= result_buf[3];
                    result_strings[4] <= result_buf[4];
                    result_strings[5] <= result_buf[5];
                    result_strings[6] <= result_buf[6];
                    result_strings[7] <= result_buf[7];
                    result_count <= out_count;
                    result_valid <= 1'b1;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= DONE_STATE;
            end
        end
    end

endmodule