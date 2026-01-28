module next_tolerable_string (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] p,
    input wire [4:0] s_in [15:0],
    output reg [4:0] result [15:0],
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] FIND_POSITION   = 3'd1;
    localparam [2:0] INCREMENT       = 3'd2;
    localparam [2:0] CHECK_CONSTRAINT = 3'd3;
    localparam [2:0] FILL_REMAINING  = 3'd4;
    localparam [2:0] DONE_STATE      = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] working_str [15:0];  // Internal string buffer
    reg [3:0] pos_idx;              // Current position being examined
    reg [4:0] try_val;              // Value being tried at pos_idx
    reg [3:0] fill_idx;             // Index for filling remaining positions
    reg found_solution;             // Flag to track if solution found
    reg [11:0] cycle_count;         // Cycle counter (max 2000)
    localparam [11:0] MAX_CYCLES = 12'd2000;

    // Combinatorial helper signals
    reg [4:0] next_val;
    reg constraint_ok;
    reg [4:0] fill_val;
    reg fill_ok;

    integer i;

    // Main state machine sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 12'd0;
            // Initialize working_str and result
            for (i = 0; i < 16; i = i + 1) begin
                working_str[i] <= 5'd0;
                result[i] <= 5'd0;
            end
        end else begin
            // Cycle counter increment (except in IDLE unless start is high)
            if (state != IDLE || start) begin
                cycle_count <= cycle_count + 12'd1;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 12'd0;
                    if (start) begin
                        // Load input string into working buffer
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n)
                                working_str[i] <= s_in[i];
                            else
                                working_str[i] <= 5'd0;
                        end
                        state <= FIND_POSITION;
                        pos_idx <= n - 4'd1; // Start from rightmost
                    end
                end

                FIND_POSITION: begin
                    // Check if position is valid for increment
                    // Condition: pos_idx >= 0 and try_val < p
                    if ($signed(pos_idx) >= 0) begin
                        // Start trying values from s[i] + 1
                        try_val <= working_str[pos_idx] + 5'd1;
                        state <= INCREMENT;
                    end else begin
                        // No position found (pos_idx went negative)
                        found_solution <= 1'b0;
                        state <= DONE_STATE;
                    end
                end

                INCREMENT: begin
                    if (try_val < p) begin
                        // Check constraint for this value at pos_idx
                        state <= CHECK_CONSTRAINT;
                    end else begin
                        // Tried all values at this position, move left
                        pos_idx <= pos_idx - 4'd1;
                        state <= FIND_POSITION;
                    end
                end

                CHECK_CONSTRAINT: begin
                    // Constraint: s[i] != s[i-1] and (i < 2 or s[i] != s[i-2])
                    constraint_ok = 1'b1;
                    
                    // Check against s[pos_idx-1]
                    if (pos_idx > 0) begin
                        if (try_val == working_str[pos_idx - 4'd1]) begin
                            constraint_ok = 1'b0;
                        end
                    end
                    
                    // Check against s[pos_idx-2]
                    if (pos_idx > 1) begin
                        if (try_val == working_str[pos_idx - 4'd2]) begin
                            constraint_ok = 1'b0;
                        end
                    end
                    
                    if (constraint_ok) begin
                        // Valid value found, update working string
                        working_str[pos_idx] <= try_val;
                        found_solution <= 1'b1;
                        fill_idx <= pos_idx + 4'd1;
                        state <= FILL_REMAINING;
                    end else begin
                        // Try next value
                        try_val <= try_val + 5'd1;
                        state <= INCREMENT;
                    end
                end

                FILL_REMAINING: begin
                    if (fill_idx < n) begin
                        // Greedy fill: find smallest valid value
                        // Check if fill_val < p
                        if (fill_val < p) begin
                            // Check constraint
                            fill_ok = 1'b1;
                            
                            // Check against previous char
                            if (fill_ok && (working_str[fill_idx - 4'd1] == fill_val)) begin
                                fill_ok = 1'b0;
                            end
                            
                            // Check against two chars before
                            if (fill_ok && (fill_idx > 1) && (working_str[fill_idx - 4'd2] == fill_val)) begin
                                fill_ok = 1'b0;
                            end
                            
                            if (fill_ok) begin
                                // Found valid value, store and move to next
                                working_str[fill_idx] <= fill_val;
                                fill_idx <= fill_idx + 4'd1;
                            end else begin
                                // Try next value
                                fill_val <= fill_val + 5'd1;
                            end
                        end else begin
                            // No valid value found for this position
                            // This shouldn't happen if p >= 3, but handle gracefully
                            found_solution <= 1'b0;
                            state <= DONE_STATE;
                        end
                    end else begin
                        // Finished filling all positions
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (found_solution) begin
                        valid <= 1'b1;
                        // Copy working string to output
                        for (i = 0; i < 16; i = i + 1) begin
                            result[i] <= working_str[i];
                        end
                    end else begin
                        valid <= 1'b0;
                        // result can be anything, keeping previous values
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Handle cycle limit
            if (cycle_count >= MAX_CYCLES && state != DONE_STATE && state != IDLE) begin
                found_solution <= 1'b0;
                state <= DONE_STATE;
            end
        end
    end

    // Combinatorial logic for fill_val calculation
    always @(*) begin
        if (state == FILL_REMAINING) begin
            // Start trying from 0
            fill_val = 5'd0;
        end else begin
            fill_val = 5'd0;
        end
    end

endmodule