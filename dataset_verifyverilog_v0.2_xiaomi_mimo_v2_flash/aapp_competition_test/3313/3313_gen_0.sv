module gem_collector (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [5:0] w,
    input [7:0] h,
    input [2:0] gem_index,
    input [5:0] gem_x,
    input [7:0] gem_y,
    input gem_wr,
    output reg [2:0] max_gems,
    output reg done
);

    // Gem storage: max 8 gems, each with x (6b) and y (8b)
    reg [5:0] store_x [0:7];
    reg [7:0] store_y [0:7];
    
    // DP storage: max gems collected ending at gem i
    reg [2:0] dp [0:7];
    
    // State encoding
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam LOAD_GEMS = 3'b001;
    localparam SORT_GEMS = 3'b010;
    localparam DP_PROCESS = 3'b011;
    localparam DONE = 3'b100;
    
    // Sorting counters
    reg [2:0] i_cnt; // outer loop index
    reg [2:0] j_cnt; // inner loop index
    reg sort_done;
    
    // DP counters
    reg [2:0] dp_i; // current gem being processed (outer loop)
    reg [2:0] dp_j; // previous gem checking reachability (inner loop)
    reg [2:0] current_max;
    
    // Temporary variables for reachability calculation
    wire signed [7:0] dx; // x difference
    wire signed [8:0] dy; // y difference
    wire [6:0] abs_dx;     // absolute x difference
    wire [7:0] dy_shifted; // dy * r (r=1, so just dy)
    
    // Reachability condition: |x_i - x_j| <= (y_i - y_j) * r
    // Assuming r=1 as per problem statement
    assign dx = $signed({1'b0, store_x[dp_i]}) - $signed({1'b0, store_x[dp_j]});
    assign dy = $signed({1'b0, store_y[dp_i]}) - $signed({1'b0, store_y[dp_j]});
    
    // Calculate absolute value of dx
    assign abs_dx = (dx[7]) ? (~dx[6:0] + 1'b1) : dx[6:0];
    
    // dy * r, r=1 so just ensure non-negative and within range
    assign dy_shifted = (dy[8]) ? 8'hFF : dy[7:0]; // clamp if negative (shouldn't happen in sorted order)

    // Gem write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset storage
            // No need to clear storage_x and storage_y specifically as we track 'n'
        end else if (gem_wr && state == LOAD_GEMS) begin
            store_x[gem_index] <= gem_x;
            store_y[gem_index] <= gem_y;
        end
    end

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_gems <= 3'b0;
            done <= 1'b0;
            i_cnt <= 3'b0;
            j_cnt <= 3'b0;
            dp_i <= 3'b0;
            dp_j <= 3'b0;
            current_max <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD_GEMS;
                        i_cnt <= 3'b0; // Use i_cnt to track how many gems loaded
                    end
                end

                LOAD_GEMS: begin
                    if (gem_wr) begin
                        // Increment a counter if we want to track loaded gems, 
                        // but here we rely on user providing correct 'n' and gem_index.
                        // Alternatively, we can transition based on external control or just wait.
                        // Since requirements say "Accept gem coordinates... when gem_wr is asserted",
                        // we stay in this state until some condition. 
                        // But start is one-shot. We need a way to exit LOAD.
                        // Let's assume we stay here until 'start' is de-asserted or a fixed time.
                        // Wait, 'start' is asserted to start computation. 
                        // Usually, data comes in parallel or before start.
                        // Let's change strategy: Wait for 'start' to go low, then sort.
                        // OR: The problem says "When start is asserted, sort gems".
                        // This implies data loading happens before or during start.
                        // Let's define: Transition to SORT when start goes low (data loaded).
                        // If start stays high, we need a timer. 
                        // Let's implement: Load gems based on valid 'gem_wr' pulses.
                        // Transition to SORT when a specific input signal indicates load complete 
                        // OR simply transition when 'start' is de-asserted.
                        // To be safe: If start is high, we are in loading phase. 
                        // If start goes low, we transition to sort.
                        if (!start) state <= SORT_GEMS;
                    end else begin
                         if (!start) state <= SORT_GEMS;
                    end
                end

                SORT_GEMS: begin
                    // Bubble sort logic
                    // Outer loop i: 0 to n-2
                    // Inner loop j: 0 to n-i-2
                    // We use i_cnt as the outer loop index (0 to n-1)
                    // We use j_cnt as the inner loop index (0 to n-i-2)
                    
                    if (i_cnt < n - 1) begin
                        if (j_cnt < n - 1 - i_cnt) begin
                            // Compare store_y[j] and store_y[j+1]
                            if (store_y[j_cnt] > store_y[j_cnt + 1]) begin
                                // Swap X
                                store_x[j_cnt] <= store_x[j_cnt + 1];
                                store_x[j_cnt + 1] <= store_x[j_cnt];
                                // Swap Y
                                store_y[j_cnt] <= store_y[j_cnt + 1];
                                store_y[j_cnt + 1] <= store_y[j_cnt];
                            end
                            j_cnt <= j_cnt + 1;
                        end else begin
                            // Inner loop finished
                            j_cnt <= 3'b0;
                            i_cnt <= i_cnt + 1;
                        end
                    end else begin
                        // Sorting finished
                        state <= DP_PROCESS;
                        i_cnt <= 3'b0;
                        j_cnt <= 3'b0;
                        dp_i <= 3'b0;
                        dp_j <= 3'b0;
                        current_max <= 3'b0;
                        // Initialize first DP value
                        if (n > 0) dp[0] <= 3'd1;
                    end
                end

                DP_PROCESS: begin
                    // Iterate through gems i from 1 to n-1
                    // For each i, iterate j from 0 to i-1
                    // Check reachability: |x_i - x_j| <= (y_i - y_j)
                    // Update dp[i] = max(dp[i], dp[j] + 1)
                    // Finally update current_max
                    
                    if (dp_i < n) begin
                        // Check previous gems
                        if (dp_j < dp_i) begin
                            // Reachability check: abs(x_i - x_j) <= (y_i - y_j)
                            // Since sorted by Y, dy is non-negative.
                            // dy is stored in wire 'dy'.
                            // abs_dx is in wire 'abs_dx'.
                            
                            // Comparisons: abs_dx <= dy[7:0] (since r=1)
                            // Note: dy is signed, but since y_i >= y_j (sorted), it's positive.
                            
                            // Condition check
                            if (abs_dx <= dy[7:0]) begin
                                // Reachable
                                if (dp[dp_j] + 1 > dp[dp_i]) begin
                                    dp[dp_i] <= dp[dp_j] + 1;
                                end
                            end
                            
                            dp_j <= dp_j + 1;
                        end else begin
                            // Inner loop done for this dp_i
                            // Update global max
                            if (dp[dp_i] > current_max) begin
                                current_max <= dp[dp_i];
                            end
                            // Move to next i
                            dp_i <= dp_i + 1;
                            dp_j <= 3'b0;
                            // Initialize next dp value to 1 (reachable from start)
                            if (dp_i + 1 < n) dp[dp_i + 1] <= 3'd1;
                        end
                    end else begin
                        // DP finished
                        max_gems <= current_max;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for start to reset or go to IDLE logic
                    // If start is asserted again, go back to IDLE (or LOAD)
                    if (start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
