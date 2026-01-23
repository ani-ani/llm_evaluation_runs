module file_pattern_matcher (
    input clk,
    input rst_n,
    input start,
    input [7:0] pattern_char,
    input [7:0] file_char,
    input pattern_valid,
    input file_valid,
    input pattern_end,
    input file_end,
    output reg match_result,
    output reg done,
    output reg need_more_chars
);

    // Internal memory for pattern and filename buffers (max 8 chars)
    reg [7:0] pattern_buf [0:7];
    reg [7:0] file_buf [0:7];
    reg [2:0] p_idx; // pattern index
    reg [2:0] f_idx; // file index
    reg [2:0] pattern_len; // stores length of pattern
    reg [2:0] file_len; // stores length of file
    
    // State definitions
    localparam IDLE = 4'd0;
    localparam READ_PATTERN = 4'd1;
    localparam READ_FILE = 4'd2;
    localparam CHECK_WILDCARD = 4'd3;
    localparam COMPARE = 4'd4;
    localparam WILDCARD_SKIP = 4'd5;
    localparam WILDCARD_BACKTRACK = 4'd6;
    localparam MATCH_FOUND = 4'd7;
    localparam MATCH_FAIL = 4'd8;
    localparam DONE_STATE = 4'd9;
    
    reg [3:0] state, next_state;
    
    // Backtracking registers for '*'
    reg [2:0] star_p_idx; // position after '*'
    reg [2:0] star_f_idx; // position to try matching from
    reg star_active; // flag for active backtracking state
    
    // Track if we need to request more chars
    reg wait_pattern;
    reg wait_file;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            p_idx <= 0;
            f_idx <= 0;
            pattern_len <= 0;
            file_len <= 0;
            star_active <= 0;
            star_p_idx <= 0;
            star_f_idx <= 0;
            wait_pattern <= 0;
            wait_file <= 0;
            match_result <= 0;
            done <= 0;
            need_more_chars <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        p_idx <= 0;
                        f_idx <= 0;
                        pattern_len <= 0;
                        file_len <= 0;
                        star_active <= 0;
                        wait_pattern <= 1;
                        wait_file <= 1;
                        match_result <= 0;
                        done <= 0;
                        need_more_chars <= 1; // request first chars
                    end
                end
                
                READ_PATTERN: begin
                    if (pattern_valid) begin
                        pattern_buf[p_idx] <= pattern_char;
                        p_idx <= p_idx + 1;
                        pattern_len <= p_idx + 1;
                        if (pattern_end) begin
                            wait_pattern <= 0;
                        end else begin
                            // request next char
                            need_more_chars <= 1;
                        end
                    end
                end
                
                READ_FILE: begin
                    if (file_valid) begin
                        file_buf[f_idx] <= file_char;
                        f_idx <= f_idx + 1;
                        file_len <= f_idx + 1;
                        if (file_end) begin
                            wait_file <= 0;
                        end else begin
                            need_more_chars <= 1;
                        end
                    end
                end
                
                WILDCARD_SKIP: begin
                    // Skip file chars for '*'
                    if (f_idx < file_len) begin
                        f_idx <= f_idx + 1;
                        star_active <= 1;
                        star_f_idx <= f_idx + 1;
                        star_p_idx <= p_idx; // position after '*'
                    end
                end
                
                WILDCARD_BACKTRACK: begin
                    // Try matching with more chars consumed by '*'
                    if (star_active && star_f_idx < file_len) begin
                        f_idx <= star_f_idx;
                        p_idx <= star_p_idx;
                        star_f_idx <= star_f_idx + 1;
                    end
                end
                
                COMPARE: begin
                    if (file_buf[f_idx] == pattern_buf[p_idx]) begin
                        f_idx <= f_idx + 1;
                        p_idx <= p_idx + 1;
                    end
                end
                
                MATCH_FOUND: begin
                    match_result <= 1;
                end
                
                MATCH_FAIL: begin
                    match_result <= 0;
                end
                
                DONE_STATE: begin
                    done <= 1;
                    need_more_chars <= 0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = READ_PATTERN;
                else next_state = IDLE;
            end
            
            READ_PATTERN: begin
                if (pattern_valid && pattern_end) next_state = READ_FILE;
                else if (pattern_valid) next_state = IDLE; // wait for next cycle
                else next_state = READ_PATTERN;
            end
            
            READ_FILE: begin
                if (file_valid && file_end) next_state = CHECK_WILDCARD;
                else if (file_valid) next_state = IDLE; // wait for next cycle
                else next_state = READ_FILE;
            end
            
            CHECK_WILDCARD: begin
                if (p_idx >= pattern_len && f_idx >= file_len) begin
                    next_state = MATCH_FOUND;
                end else if (p_idx >= pattern_len) begin
                    next_state = MATCH_FAIL;
                end else if (f_idx >= file_len) begin
                    if (pattern_buf[p_idx] == 8'h2A) begin // '*'
                        p_idx <= p_idx + 1;
                        next_state = CHECK_WILDCARD;
                    end else begin
                        next_state = MATCH_FAIL;
                    end
                end else begin
                    // Pattern and file still have chars
                    if (pattern_buf[p_idx] == 8'h2A) begin // '*'
                        if (p_idx + 1 >= pattern_len) begin
                            // '*' at end matches everything
                            next_state = MATCH_FOUND;
                        end else begin
                            next_state = WILDCARD_SKIP;
                        end
                    end else begin
                        next_state = COMPARE;
                    end
                end
            end
            
            WILDCARD_SKIP: begin
                // Go to compare for this position
                next_state = CHECK_WILDCARD;
            end
            
            COMPARE: begin
                if (file_buf[f_idx] == pattern_buf[p_idx]) begin
                    // Match successful, continue
                    next_state = CHECK_WILDCARD;
                end else begin
                    // Mismatch - backtrack if star was active
                    if (star_active && star_f_idx < file_len) begin
                        next_state = WILDCARD_BACKTRACK;
                    end else begin
                        next_state = MATCH_FAIL;
                    end
                end
            end
            
            WILDCARD_BACKTRACK: begin
                next_state = CHECK_WILDCARD;
            end
            
            MATCH_FOUND: begin
                next_state = DONE_STATE;
            end
            
            MATCH_FAIL: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule