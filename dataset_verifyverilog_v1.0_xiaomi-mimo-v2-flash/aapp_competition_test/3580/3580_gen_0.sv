module find_longest_consecutive_subsequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a_len,
    input wire [7:0] q_idx,
    input wire [7:0] query_i,
    input wire [3:0] query_m,
    input wire [7:0] arr_a [0:15],
    input wire [7:0] arr_b [0:15],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_NEXT = 3'd1;
    localparam [2:0] VERIFY_SUB = 3'd2;
    localparam [2:0] MATCH_FOUND = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] pos;           // Current position in arr_a
    reg [7:0] count;         // Current consecutive length
    reg [3:0] sub_idx;       // Index in arr_b for subset matching
    reg match_flag;          // Flag for subset match
    reg [7:0] cycle_count;   // Cycle counter for timeout
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Convert query_i from 1-based to 0-based (subtract 1)
    wire [7:0] start_idx;
    assign start_idx = (query_i > 8'd0) ? (query_i - 8'd1) : 8'd0;

    // Subset matching logic
    wire is_in_subset;
    assign is_in_subset = (arr_a[pos] == arr_b[sub_idx]);

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_NEXT;
                else
                    next_state = IDLE;
            end
            
            CHECK_NEXT: begin
                // Check if we're still within array bounds
                if (pos < a_len)
                    next_state = VERIFY_SUB;
                else
                    next_state = DONE_STATE;
            end
            
            VERIFY_SUB: begin
                // Continue checking subset
                if (sub_idx < query_m)
                    next_state = VERIFY_SUB;
                else
                    next_state = DONE_STATE;
            end
            
            MATCH_FOUND: begin
                // Continue to next position
                next_state = CHECK_NEXT;
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
            result <= 8'd0;
            done <= 1'b0;
            pos <= 8'd0;
            count <= 8'd0;
            sub_idx <= 4'd0;
            match_flag <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        pos <= start_idx;
                        count <= 8'd0;
                        sub_idx <= 4'd0;
                        match_flag <= 1'b0;
                    end
                end
                
                CHECK_NEXT: begin
                    // Initialize subset search
                    sub_idx <= 4'd0;
                    match_flag <= 1'b0;
                end
                
                VERIFY_SUB: begin
                    if (is_in_subset)
                        match_flag <= 1'b1;
                    
                    sub_idx <= sub_idx + 4'd1;
                    
                    // End of subset check
                    if (sub_idx == query_m - 4'd1) begin
                        if (match_flag || is_in_subset) begin
                            count <= count + 8'd1;
                            pos <= pos + 8'd1;
                        end else begin
                            // Mismatch - stop here
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    result <= count;
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
            
            // Update next state
            if (state != DONE_STATE || next_state == IDLE)
                state <= next_state;
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= DONE_STATE;
            end
        end
    end
endmodule