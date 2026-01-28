module pattern_searcher (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] text [0:63],
    input wire [5:0] text_len,
    input wire [7:0] pattern [0:7],
    input wire [3:0] pattern_len,
    output reg [5:0] result_start,
    output reg [5:0] result_end,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SEARCH    = 3'd1;
    localparam [2:0] COMPARE   = 3'd2;
    localparam [2:0] FOUND     = 3'd3;
    localparam [2:0] NO_MATCH  = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Position and character counters
    reg [5:0] pos_counter;       // Current position in text
    reg [3:0] char_counter;      // Current character in pattern
    reg [2:0] cycle_counter;     // For timeout protection
    
    // Combinational comparison results
    reg [7:0] text_char;
    reg [7:0] pattern_char;
    reg char_match;
    reg all_chars_match;
    
    // Search limit: text_len - pattern_len (avoid underflow)
    wire [5:0] search_limit;
    assign search_limit = (pattern_len > text_len) ? 6'd0 : text_len - {2'd0, pattern_len};
    
    // Sync state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_start <= 6'd63;
            result_end <= 6'd64;
            done <= 1'b0;
            pos_counter <= 6'd0;
            char_counter <= 4'd0;
            cycle_counter <= 3'd0;
        end else begin
            state <= next_state;
            
            // Increment cycle counter during operations
            if (state == SEARCH || state == COMPARE) begin
                cycle_counter <= cycle_counter + 3'd1;
            end else if (state == IDLE) begin
                cycle_counter <= 3'd0;
            end
            
            // Initialize outputs on start
            if (start && state == IDLE) begin
                result_start <= 6'd63;
                result_end <= 6'd64;
                done <= 1'b0;
                pos_counter <= 6'd0;
                char_counter <= 4'd0;
                cycle_counter <= 3'd0;
            end
            
            // Update counters based on state
            case (state)
                SEARCH: begin
                    // Always increment position to ensure progress
                    if (pos_counter < search_limit) begin
                        pos_counter <= pos_counter + 6'd1;
                    end
                    char_counter <= 4'd0;
                end
                COMPARE: begin
                    if (char_counter < pattern_len) begin
                        char_counter <= char_counter + 4'd1;
                    end
                end
                default: begin
                    // Keep counters stable in other states
                end
            endcase
            
            // Update outputs on match
            if (state == FOUND) begin
                result_start <= pos_counter - 6'd1;  // Previous position
                result_end <= pos_counter - 6'd1 + {2'd0, pattern_len};
            end
            
            // Set done pulse in FINISH state
            if (state == FINISH) begin
                done <= 1'b1;
            end else if (state == IDLE) begin
                done <= 1'b0;
            end
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) begin
                    // Check for valid search conditions
                    if (pattern_len > 4'd0 && text_len >= pattern_len && pattern_len <= 4'd8) begin
                        next_state = SEARCH;
                    end else begin
                        // Invalid input, go to finish immediately
                        next_state = FINISH;
                    end
                end
            end
            
            SEARCH: begin
                // Check for timeout or completion
                if (cycle_counter >= 3'd6) begin
                    next_state = FINISH;
                end else if (pos_counter > search_limit) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                // Get current characters for comparison
                if (char_counter < pattern_len) begin
                    // Still comparing characters
                    next_state = COMPARE;
                end else begin
                    // Finished comparing all pattern chars
                    if (all_chars_match) begin
                        next_state = FOUND;
                    end else begin
                        next_state = SEARCH;
                    end
                end
            end
            
            FOUND: begin
                next_state = FINISH;
            end
            
            NO_MATCH: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Combinational character comparison logic
    always @(*) begin
        // Default values
        char_match = 1'b0;
        all_chars_match = 1'b0;
        text_char = 8'd0;
        pattern_char = 8'd0;
        
        // Get current characters for comparison
        if (char_counter < pattern_len && char_counter < 4'd8) begin
            // Safely access arrays with bounds checking
            text_char = text[pos_counter + {2'd0, char_counter}];
            pattern_char = pattern[char_counter];
            
            // Character-by-character comparison
            if (text_char == pattern_char) begin
                char_match = 1'b1;
            end
        end
        
        // Check if all pattern characters matched
        if (state == COMPARE && char_counter >= pattern_len) begin
            // Need to check if all previous comparisons matched
            // For now, we'll use a simple approach: check all characters
            // This will be evaluated based on previous state
            all_chars_match = 1'b1;
            for (integer i = 0; i < 8; i = i + 1) begin
                if (i < pattern_len) begin
                    if (text[pos_counter + {2'd0, i}] != pattern[i]) begin
                        all_chars_match = 1'b0;
                    end
                end
            end
        end
    end

endmodule