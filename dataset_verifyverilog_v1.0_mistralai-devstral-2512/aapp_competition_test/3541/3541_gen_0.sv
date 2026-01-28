module candy_splitter(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] a_vals [0:9],
    input signed [7:0] b_vals [0:9],
    input [3:0] N,
    output reg [39:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] BACKTRACK = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    
    // DP state: current and previous rows
    reg [2047:0] dp_prev;
    reg [2047:0] dp_curr;
    
    // Tracking variables
    reg [9:0] candy_idx;
    reg signed [15:0] min_diff;
    reg signed [15:0] current_diff;
    reg [9:0] backtrack_idx;
    reg [39:0] assignment;
    
    // Constants
    localparam [15:0] OFFSET = 16'd512;
    localparam [15:0] MAX_DIFF = 16'd1000;
    localparam [15:0] MIN_DIFF = -16'd1000;
    
    // Cycle counter for timeout
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd2000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 40'd0;
            done <= 1'b0;
            cycle_count <= 11'd0;
            
            // Initialize DP arrays
            dp_prev <= 2048'd0;
            dp_curr <= 2048'd0;
            
            // Initialize tracking variables
            candy_idx <= 10'd0;
            min_diff <= 16'd0;
            current_diff <= 16'd0;
            backtrack_idx <= 10'd0;
            assignment <= 40'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize DP base case
                    dp_prev[OFFSET] <= 1'b1;
                    candy_idx <= 10'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 11'd1;
                    
                    if (candy_idx < N) begin
                        // Compute next DP row
                        dp_curr <= 2048'd0;
                        
                        // Iterate through all possible differences
                        for (integer i = 0; i < 2048; i = i + 1) begin
                            if (dp_prev[i]) begin
                                // Option 1: Assign to Alf
                                current_diff = (i - OFFSET) + a_vals[candy_idx];
                                if (current_diff >= MIN_DIFF && current_diff <= MAX_DIFF) begin
                                    dp_curr[current_diff + OFFSET] <= 1'b1;
                                end
                                
                                // Option 2: Assign to Beata
                                current_diff = (i - OFFSET) - b_vals[candy_idx];
                                if (current_diff >= MIN_DIFF && current_diff <= MAX_DIFF) begin
                                    dp_curr[current_diff + OFFSET] <= 1'b1;
                                end
                            end
                        end
                        
                        // Move to next candy
                        candy_idx <= candy_idx + 10'd1;
                        dp_prev <= dp_curr;
                    end else begin
                        // Find minimum absolute difference
                        min_diff <= 16'd1000;
                        for (integer i = 0; i < 2048; i = i + 1) begin
                            if (dp_prev[i]) begin
                                current_diff = i - OFFSET;
                                if ($abs(current_diff) < $abs(min_diff)) begin
                                    min_diff <= current_diff;
                                end
                            end
                        end
                        
                        // Prepare for backtracking
                        backtrack_idx <= N - 10'd1;
                        assignment <= 40'd0;
                        state <= BACKTRACK;
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                BACKTRACK: begin
                    cycle_count <= cycle_count + 11'd1;
                    
                    if (backtrack_idx >= 0) begin
                        // Check if assigning to Alf is possible
                        current_diff = min_diff - a_vals[backtrack_idx];
                        if (dp_prev[current_diff + OFFSET]) begin
                            assignment[backtrack_idx * 8 +: 8] <= 8'd65; // 'A'
                            min_diff <= current_diff;
                        end else begin
                            // Must assign to Beata
                            current_diff = min_diff + b_vals[backtrack_idx];
                            assignment[backtrack_idx * 8 +: 8] <= 8'd66; // 'B'
                            min_diff <= current_diff;
                        end
                        
                        // Move to previous candy
                        backtrack_idx <= backtrack_idx - 10'd1;
                        
                        // Update DP state for next iteration
                        dp_curr <= 2048'd0;
                        for (integer i = 0; i < 2048; i = i + 1) begin
                            if (dp_prev[i]) begin
                                // Option 1: Assign to Alf
                                current_diff = (i - OFFSET) + a_vals[backtrack_idx];
                                if (current_diff >= MIN_DIFF && current_diff <= MAX_DIFF) begin
                                    dp_curr[current_diff + OFFSET] <= 1'b1;
                                end
                                
                                // Option 2: Assign to Beata
                                current_diff = (i - OFFSET) - b_vals[backtrack_idx];
                                if (current_diff >= MIN_DIFF && current_diff <= MAX_DIFF) begin
                                    dp_curr[current_diff + OFFSET] <= 1'b1;
                                end
                            end
                        end
                        dp_prev <= dp_curr;
                    end else begin
                        result <= assignment;
                        state <= FINISH;
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule