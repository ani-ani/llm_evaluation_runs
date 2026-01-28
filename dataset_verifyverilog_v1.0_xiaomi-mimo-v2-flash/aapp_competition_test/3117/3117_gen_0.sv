module longest_duplicate_substring (
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

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] BINARY_SEARCH = 4'd2;
    localparam [3:0] CHECK_LENGTH = 4'd3;
    localparam [3:0] SCAN_POSITIONS = 4'd4;
    localparam [3:0] COMPARE = 4'd5;
    localparam [3:0] UPDATE_RESULT = 4'd6;
    localparam [3:0] FINISH = 4'd7;
    localparam [3:0] RESET_STATE = 4'd8;

    reg [3:0] state, next_state;
    
    // Internal registers
    reg [5:0] length_reg;          // Store string length
    reg [6:0] string_buf [0:63];   // 64 x 7-bit buffer for string
    reg [5:0] load_counter;
    
    // Binary search registers
    reg [5:0] min_len, max_len, mid_len;
    reg [5:0] current_len;
    
    // Position scanning registers
    reg [5:0] pos_i;
    reg [5:0] pos_j;
    reg [5:0] cmp_offset;
    reg match_found;
    reg [2:0] scan_state;
    
    // Cycle counter for timeout protection
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2048;
    
    // Temporary comparison registers
    reg [6:0] char_a, char_b;
    reg cmp_result;
    
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            busy <= 1'b0;
            length_reg <= 6'd0;
            load_counter <= 6'd0;
            min_len <= 6'd0;
            max_len <= 6'd0;
            mid_len <= 6'd0;
            current_len <= 6'd0;
            pos_i <= 6'd0;
            pos_j <= 6'd0;
            cmp_offset <= 6'd0;
            match_found <= 1'b0;
            scan_state <= 3'd0;
            cycle_count <= 12'd0;
            char_a <= 7'd0;
            char_b <= 7'd0;
            cmp_result <= 1'b0;
            for (i = 0; i < 64; i = i + 1) begin
                string_buf[i] <= 7'd0;
            end
        end else begin
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    cycle_count <= 12'd0;
                    result <= 6'd0;
                    if (start && str_len <= 6'd64) begin
                        length_reg <= str_len;
                        load_counter <= 6'd0;
                        busy <= 1'b1;
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    if (char_valid && load_counter < length_reg) begin
                        string_buf[load_counter] <= char_in;
                        load_counter <= load_counter + 6'd1;
                    end
                    if (char_valid && (load_counter + 6'd1) >= length_reg && load_counter < length_reg) begin
                        // Last character loaded
                        next_state <= BINARY_SEARCH;
                    end else if (load_counter >= length_reg) begin
                        next_state <= BINARY_SEARCH;
                    end else begin
                        next_state <= LOAD;
                    end
                end
                
                BINARY_SEARCH: begin
                    cycle_count <= cycle_count + 12'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        // Timeout protection
                        result <= 6'd0;
                        next_state <= FINISH;
                    end else if (max_len <= min_len) begin
                        // Binary search complete
                        result <= min_len;
                        next_state <= FINISH;
                    end else begin
                        mid_len <= (min_len + max_len) >> 1;
                        current_len <= (min_len + max_len) >> 1;
                        pos_i <= 6'd0;
                        pos_j <= 6'd0;
                        cmp_offset <= 6'd0;
                        match_found <= 1'b0;
                        scan_state <= 3'd0;
                        next_state <= CHECK_LENGTH;
                    end
                end
                
                CHECK_LENGTH: begin
                    if (current_len == 6'd0) begin
                        // Empty substring always matches
                        match_found <= 1'b1;
                        next_state <= UPDATE_RESULT;
                    end else if (current_len > length_reg) begin
                        // Length too large, no match
                        match_found <= 1'b0;
                        next_state <= UPDATE_RESULT;
                    end else begin
                        pos_i <= 6'd0;
                        next_state <= SCAN_POSITIONS;
                    end
                end
                
                SCAN_POSITIONS: begin
                    if (pos_i + current_len <= length_reg) begin
                        // Try to find match starting from pos_i
                        pos_j <= pos_i + 6'd1;
                        scan_state <= 3'd0;
                        cmp_offset <= 6'd0;
                        match_found <= 1'b0;
                        next_state <= COMPARE;
                    end else begin
                        // No more positions to check
                        next_state <= UPDATE_RESULT;
                    end
                end
                
                COMPARE: begin
                    if (current_len == 6'd0) begin
                        match_found <= 1'b1;
                        next_state <= UPDATE_RESULT;
                    end else if (pos_j + current_len > length_reg) begin
                        // Move to next i
                        pos_i <= pos_i + 6'd1;
                        next_state <= SCAN_POSITIONS;
                    end else if (cmp_offset < current_len) begin
                        // Compare characters at pos_i + cmp_offset and pos_j + cmp_offset
                        char_a <= string_buf[pos_i + cmp_offset];
                        char_b <= string_buf[pos_j + cmp_offset];
                        if (string_buf[pos_i + cmp_offset] != string_buf[pos_j + cmp_offset]) begin
                            // No match at this position pair
                            pos_j <= pos_j + 6'd1;
                            cmp_offset <= 6'd0;
                        end else begin
                            cmp_offset <= cmp_offset + 6'd1;
                        end
                    end else begin
                        // Full match found
                        match_found <= 1'b1;
                        next_state <= UPDATE_RESULT;
                    end
                end
                
                UPDATE_RESULT: begin
                    if (match_found) begin
                        // This length works, try longer
                        min_len <= current_len;
                    end else begin
                        // This length doesn't work, try shorter
                        if (current_len > 6'd0) begin
                            max_len <= current_len - 6'd1;
                        end else begin
                            max_len <= 6'd0;
                        end
                    end
                    next_state <= BINARY_SEARCH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
    
    // Initialize min_len and max_len when entering BINARY_SEARCH from LOAD
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_len <= 6'd0;
            max_len <= 6'd0;
        end else if (state == LOAD && next_state == BINARY_SEARCH) begin
            min_len <= 6'd0;
            max_len <= length_reg;
        end
    end

endmodule