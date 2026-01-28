module LongestDuplicateSubstring(
    input clk,
    input rst_n,
    input start,
    input [5:0] str_len,
    input [6:0] char_in,
    input char_valid,
    output reg [5:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // String buffer (64x8-bit BRAM)
    reg [7:0] str_buffer [0:63];
    reg [5:0] char_index;
    
    // Binary search variables
    reg [5:0] min_len, max_len, mid_len;
    reg [5:0] pos_i, pos_j, char_pos;
    reg match_found;
    
    // Cycle counter
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2048;
    
    // Internal signals
    reg char_loaded;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            busy <= 1'b0;
            char_index <= 6'd0;
            min_len <= 6'd0;
            max_len <= 6'd0;
            mid_len <= 6'd0;
            pos_i <= 6'd0;
            pos_j <= 6'd0;
            char_pos <= 6'd0;
            match_found <= 1'b0;
            cycle_count <= 12'd0;
            char_loaded <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    char_loaded <= 1'b0;
                    cycle_count <= 12'd0;
                    if (start) begin
                        next_state <= LOAD;
                        busy <= 1'b1;
                        char_index <= 6'd0;
                    end
                end
                
                LOAD: begin
                    if (char_valid) begin
                        str_buffer[char_index] <= char_in;
                        char_index <= char_index + 6'd1;
                        if (char_index == str_len) begin
                            char_loaded <= 1'b1;
                            next_state <= COMPUTE;
                            min_len <= 6'd0;
                            max_len <= str_len;
                            mid_len <= (min_len + max_len) / 2;
                            pos_i <= 6'd0;
                            pos_j <= 6'd0;
                            char_pos <= 6'd0;
                            match_found <= 1'b0;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 12'd1;
                    
                    // Binary search logic
                    if (min_len >= max_len) begin
                        result <= min_len;
                        next_state <= FINISH;
                    end else begin
                        // Check if current mid_len has duplicate
                        if (!match_found) begin
                            // Compare substrings at pos_i and pos_j
                            if (char_pos < mid_len) begin
                                if (str_buffer[pos_i + char_pos] == str_buffer[pos_j + char_pos]) begin
                                    if (char_pos == mid_len - 1) begin
                                        match_found <= 1'b1;
                                    end
                                    char_pos <= char_pos + 6'd1;
                                end else begin
                                    // Mismatch, move to next pair
                                    char_pos <= 6'd0;
                                    pos_j <= pos_j + 6'd1;
                                    if (pos_j >= str_len - mid_len) begin
                                        pos_j <= 6'd0;
                                        pos_i <= pos_i + 6'd1;
                                        if (pos_i >= str_len - mid_len) begin
                                            // No match found for this length
                                            max_len <= mid_len - 6'd1;
                                            mid_len <= (min_len + max_len) / 2;
                                            pos_i <= 6'd0;
                                            pos_j <= 6'd0;
                                            char_pos <= 6'd0;
                                            match_found <= 1'b0;
                                        end
                                    end
                                end
                            end else begin
                                // Match found, increase min_len
                                min_len <= mid_len + 6'd1;
                                mid_len <= (min_len + max_len) / 2;
                                pos_i <= 6'd0;
                                pos_j <= 6'd0;
                                char_pos <= 6'd0;
                                match_found <= 1'b0;
                            end
                        end else begin
                            // Match found, increase min_len
                            min_len <= mid_len + 6'd1;
                            mid_len <= (min_len + max_len) / 2;
                            pos_i <= 6'd0;
                            pos_j <= 6'd0;
                            char_pos <= 6'd0;
                            match_found <= 1'b0;
                        end
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 6'd0;
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Default assignments
    always @(*) begin
        next_state = state;
    end

endmodule