module tree_shopping (
    input clk,
    input rst_n,
    input start,
    input [7:0] tree_heights [0:7],
    output reg [7:0] min_diff,
    output reg done
);
    
    // Define states
    localparam IDLE = 2'b00;
    localparam FETCH = 2'b01; // Compute min/max for current window
    localparam UPDATE = 2'b10; // Update global minimum difference
    localparam NEXT = 2'b11;   // Move to next window index
    localparam DONE = 2'b00;   // Reuse IDLE encoding for DONE state
    
    reg [1:0] state;
    reg [2:0] window_idx; // Index of the start of the window (0 to 5)
    reg [2:0] i;          // Inner loop index for min/max calculation
    reg [7:0] curr_min;
    reg [7:0] curr_max;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_diff <= 8'hFF; // Initialize to max possible difference
            window_idx <= 0;
            i <= 0;
            curr_min <= 0;
            curr_max <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= FETCH;
                        window_idx <= 0;
                        min_diff <= 8'hFF;
                        i <= 0;
                        // Initialize curr_min/curr_max with first element of window
                        curr_min <= tree_heights[0];
                        curr_max <= tree_heights[0];
                    end
                end

                FETCH: begin
                    // Sequentially check elements in the window to find min/max
                    // Window size k=3, indices: window_idx, window_idx+1, window_idx+2
                    // We need to check element at index window_idx + i
                    // i goes from 0 to 2 (for 3 elements)
                    if (i < 2) begin
                        // Check next element in window (tree_heights[window_idx + i + 1])
                        // Only valid if window_idx + i + 1 < 8
                        if (window_idx + i + 1 < 8) begin
                            if (tree_heights[window_idx + i + 1] < curr_min)
                                curr_min <= tree_heights[window_idx + i + 1];
                            if (tree_heights[window_idx + i + 1] > curr_max)
                                curr_max <= tree_heights[window_idx + i + 1];
                        end
                        i <= i + 1;
                    end else begin
                        // Finished checking window
                        state <= UPDATE;
                        i <= 0;
                    end
                end

                UPDATE: begin
                    // Calculate difference
                    // max - min (assuming max >= min)
                    // Update global minimum
                    if (curr_max - curr_min < min_diff) begin
                        min_diff <= curr_max - curr_min;
                    end
                    state <= NEXT;
                end

                NEXT: begin
                    // Move to next window
                    // Max start index is n - k = 8 - 3 = 5
                    if (window_idx < 5) begin
                        window_idx <= window_idx + 1;
                        // Reset min/max for next window using the first element of new window
                        curr_min <= tree_heights[window_idx + 1];
                        curr_max <= tree_heights[window_idx + 1];
                        state <= FETCH;
                        i <= 0;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset
                end
            endcase
        end
    end
endmodule