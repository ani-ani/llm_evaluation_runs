module filter_by_prefix(
    input clk,
    input rst_n,
    input start,
    input [7:0] prefix [0:7],
    input [7:0] strings [0:7][0:7],
    input [2:0] num_strings,
    input [2:0] prefix_len,
    output reg [7:0] results [0:7][0:7],
    output reg [2:0] result_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_STRING = 3'd1;
    localparam [2:0] COMPARE_CHAR = 3'd2;
    localparam [2:0] ADD_RESULT   = 3'd3;
    localparam [2:0] DONE_STATE   = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Control registers
    reg [2:0] string_idx;          // Current string being checked
    reg [2:0] char_idx;            // Current character being compared
    reg match_flag;                // Flag if current string matches prefix
    reg [2:0] result_idx;          // Where to store next matching result
    reg [7:0] cycle_count;         // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal arrays for comparison
    reg [7:0] current_string [0:7];
    reg [7:0] current_prefix [0:7];
    integer i, j;

    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_STRING;
                else
                    next_state = IDLE;
            end
            
            CHECK_STRING: begin
                if (string_idx < num_strings)
                    next_state = COMPARE_CHAR;
                else
                    next_state = DONE_STATE;
            end
            
            COMPARE_CHAR: begin
                if (char_idx < prefix_len) begin
                    // Continue comparing
                    next_state = COMPARE_CHAR;
                end else begin
                    // Finished comparing this string
                    if (match_flag)
                        next_state = ADD_RESULT;
                    else
                        next_state = CHECK_STRING;
                end
            end
            
            ADD_RESULT: begin
                // String added, check next
                next_state = CHECK_STRING;
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
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result_count <= 3'd0;
            string_idx <= 3'd0;
            char_idx <= 3'd0;
            match_flag <= 1'b0;
            result_idx <= 3'd0;
            cycle_count <= 8'd0;
            
            // Initialize results array
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    results[i][j] <= 8'd0;
                end
            end
            
            // Initialize internal arrays
            for (i = 0; i < 8; i = i + 1) begin
                current_string[i] <= 8'd0;
                current_prefix[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    result_count <= 3'd0;
                    string_idx <= 3'd0;
                    char_idx <= 3'd0;
                    match_flag <= 1'b1; // Assume match until proven otherwise
                    result_idx <= 3'd0;
                    
                    if (start) begin
                        // Load prefix into internal register
                        for (i = 0; i < 8; i = i + 1) begin
                            current_prefix[i] <= prefix[i];
                        end
                    end
                end
                
                CHECK_STRING: begin
                    cycle_count <= cycle_count + 8'd1;
                    char_idx <= 3'd0;
                    match_flag <= 1'b1; // Reset for new string
                    
                    // Load current string into internal register
                    if (string_idx < num_strings) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            current_string[i] <= strings[string_idx][i];
                        end
                    end
                end
                
                COMPARE_CHAR: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compare character at char_idx
                    if (char_idx < prefix_len) begin
                        if (current_string[char_idx] != current_prefix[char_idx]) begin
                            match_flag <= 1'b0;
                        end
                        char_idx <= char_idx + 3'd1;
                    end
                end
                
                ADD_RESULT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Copy matching string to results array
                    for (i = 0; i < 8; i = i + 1) begin
                        results[result_idx][i] <= current_string[i];
                    end
                    
                    result_idx <= result_idx + 3'd1;
                    result_count <= result_count + 3'd1;
                    string_idx <= string_idx + 3'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    string_idx <= 3'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= DONE_STATE;
            end
        end
    end

endmodule