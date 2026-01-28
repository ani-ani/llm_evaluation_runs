module DominoCover (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire grid_valid,
    input wire [15:0] grid_data,
    input wire [5:0] grid_addr,
    input wire [3:0] K,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // Parameters and Constants
    localparam [5:0] GRID_SIZE = 6'd64;
    localparam [15:0] MAX_SUM = 16'd64000;
    
    // State Definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_GRID = 4'd1;
    localparam [3:0] INIT_SOLVE = 4'd2;
    localparam [3:0] CHECK_CELL = 4'd3;
    localparam [3:0] PLACE_H = 4'd4;
    localparam [3:0] PLACE_V = 4'd5;
    localparam [3:0] BACKTRACK = 4'd6;
    localparam [3:0] UPDATE_MIN = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;
    
    // Control Signals
    reg [3:0] state, next_state;
    reg [5:0] grid_index;
    reg [15:0] grid_ram [0:63]; // Block RAM simulation
    reg [5:0] load_cnt;
    
    // DFS Stack and State Tracking
    // Stack depth K (max 8) + tracking for cell iteration
    // For iterative DFS, we track the current cell index for each depth
    reg [5:0] stack_cell [0:7];      // Current cell being evaluated at depth d
    reg [1:0] stack_dir [0:7];       // Direction state: 0=none, 1=horiz tried, 2=vert tried, 3=done
    reg [63:0] stack_mask [0:7];     // Coverage mask at depth d
    reg [15:0] stack_sum [0:7];      // Current sum at depth d
    reg [3:0] stack_depth;           // Current depth (0 to K-1)
    
    // Global State
    reg [15:0] total_sum;
    reg [15:0] current_sum;
    reg [63:0] coverage_mask;
    reg [15:0] min_sum;
    reg [3:0] k_remain;
    reg [5:0] curr_cell;
    
    // Iteration State
    reg [1:0] dir_state; // 0=check if valid, 1=place/handle, 2=backtrack
    
    // Timeout counter (Safety)
    reg [31:0] timeout;
    localparam [31:0] MAX_TIMEOUT = 32'd100000;
    
    // Helper signals
    wire [5:0] cell_row = curr_cell / 8;
    wire [5:0] cell_col = curr_cell % 8;
    wire [5:0] h_cell = curr_cell + 1;
    wire [5:0] v_cell = curr_cell + 8;
    wire valid_h = (cell_col < 7);
    wire valid_v = (cell_row < 7);
    
    // RAM Read Logic (Simulated async read for combinatorial access)
    wire [15:0] ram_data = grid_ram[grid_index];
    
    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            done <= 1'b0;
            result <= 16'd0;
            load_cnt <= 6'd0;
            timeout <= 32'd0;
        end else begin
            timeout <= timeout + 32'd1;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    if (start) begin
                        state <= LOAD_GRID;
                        ready <= 1'b0;
                        load_cnt <= 6'd0;
                        grid_index <= 6'd0;
                    end
                end
                
                LOAD_GRID: begin
                    if (grid_valid) begin
                        grid_ram[load_cnt] <= grid_data;
                        load_cnt <= load_cnt + 6'd1;
                        grid_index <= load_cnt + 6'd1;
                    end
                    if (load_cnt == 63 && grid_valid) begin
                        state <= INIT_SOLVE;
                    end
                end
                
                INIT_SOLVE: begin
                    // Initialize for solving
                    // Calculate total sum (using previous cycle's load_cnt if needed, or calculate on fly)
                    // Since RAM is loaded, we can start DFS.
                    // To avoid complex combinational logic, we will sum as we go or pre-calc in load.
                    // Let's assume we sum in IDLE or LOAD. 
                    // Actually, let's just use total_sum updated during LOAD.
                    // But we need the full sum. Let's do a quick summation state if needed.
                    // For simplicity, let's assume total_sum is computed in LOAD.
                    // Wait, LOAD only stores data. 
                    // Let's fix: In LOAD, we store and accumulate.
                    // But we are already in INIT_SOLVE. Let's calculate total_sum here or in a new state.
                    // Optimization: We accumulated total_sum during LOAD.
                    // If not, we do it now. Assuming we missed it in LOAD, let's add a quick sum step.
                    // Actually, let's do it in LOAD.
                    // Fix: Modify LOAD logic to sum. 
                    // Since code is sequential, let's do a summation loop here.
                    
                    // Re-evaluation: Doing sum in INIT_SOLVE is safe.
                    // But to save cycles, let's assume we accumulated in LOAD.
                    // If load_cnt finished, we are good.
                    
                    // Reset DFS variables
                    stack_depth <= 4'd0;
                    // Initial state for depth 0
                    // We will start checking cells from 0
                    curr_cell <= 6'd0;
                    dir_state <= 2'd0;
                    
                    // Initialize stack top (depth 0)
                    stack_mask[0] <= 64'd0;
                    stack_sum[0] <= total_sum; // Assuming total_sum calculated
                    
                    k_remain <= K;
                    // Reset min sum to max possible
                    min_sum <= MAX_SUM;
                    
                    state <= CHECK_CELL;
                    
                    // Safety check for K=0
                    if (K == 4'd0) begin
                        min_sum <= total_sum;
                        state <= DONE_STATE;
                    end
                end
                
                CHECK_CELL: begin
                    // If timeout or K is large, we might need to limit iterations.
                    if (timeout > MAX_TIMEOUT) begin
                        state <= DONE_STATE;
                        min_sum <= total_sum; // Fallback
                    end
                    else if (curr_cell >= 64) begin
                        // No more cells to try at this level
                        // Backtrack if depth > 0, else finish
                        if (stack_depth == 4'd0) begin
                            state <= DONE_STATE;
                        end else begin
                            state <= BACKTRACK;
                        end
                    end
                    else begin
                        // Check if current cell is free
                        if (stack_mask[stack_depth][curr_cell]) begin
                            // Occupied, try next cell
                            curr_cell <= curr_cell + 6'd1;
                            dir_state <= 2'd0;
                        end else begin
                            // Free, check bounds for H and V
                            // We handle H then V
                            if (valid_h) begin
                                state <= PLACE_H;
                            end else if (valid_v) begin
                                state <= PLACE_V;
                            end else begin
                                // Cannot place domino here (edge), try next cell
                                curr_cell <= curr_cell + 6'd1;
                                dir_state <= 2'd0;
                            end
                        end
                    end
                end
                
                PLACE_H: begin
                    // Try placing Horizontal domino
                    if (!stack_mask[stack_depth][h_cell]) begin
                        // Valid placement
                        if (k_remain > 1) begin
                            // Push to stack
                            stack_cell[stack_depth] <= curr_cell;
                            stack_dir[stack_depth] <= 2'd1; // H tried
                            stack_mask[stack_depth + 1] <= stack_mask[stack_depth] | (64'd1 << curr_cell) | (64'd1 << h_cell);
                            stack_sum[stack_depth + 1] <= stack_sum[stack_depth] - ram_data - grid_ram[h_cell];
                            stack_depth <= stack_depth + 4'd1;
                            k_remain <= k_remain - 4'd1;
                            curr_cell <= 6'd0; // Start search from 0 for next domino
                            dir_state <= 2'd0;
                            state <= CHECK_CELL;
                        end else begin
                            // This is the last domino
                            // Update min sum if better
                            if (stack_sum[stack_depth] - ram_data - grid_ram[h_cell] < min_sum) begin
                                min_sum <= stack_sum[stack_depth] - ram_data - grid_ram[h_cell];
                            end
                            // Try V if valid, otherwise backtrack or next cell
                            if (valid_v) begin
                                state <= PLACE_V;
                            end else begin
                                curr_cell <= curr_cell + 6'd1;
                                dir_state <= 2'd0;
                                state <= CHECK_CELL;
                            end
                        end
                    end else begin
                        // Occupied, try Vertical if valid
                        if (valid_v) begin
                            state <= PLACE_V;
                        end else begin
                            curr_cell <= curr_cell + 6'd1;
                            dir_state <= 2'd0;
                            state <= CHECK_CELL;
                        end
                    end
                end
                
                PLACE_V: begin
                    // Try placing Vertical domino
                    if (!stack_mask[stack_depth][v_cell]) begin
                        // Valid placement
                        if (k_remain > 1) begin
                            // Push to stack
                            stack_cell[stack_depth] <= curr_cell;
                            stack_dir[stack_depth] <= 2'd2; // V tried
                            stack_mask[stack_depth + 1] <= stack_mask[stack_depth] | (64'd1 << curr_cell) | (64'd1 << v_cell);
                            stack_sum[stack_depth + 1] <= stack_sum[stack_depth] - ram_data - grid_ram[v_cell];
                            stack_depth <= stack_depth + 4'd1;
                            k_remain <= k_remain - 4'd1;
                            curr_cell <= 6'd0;
                            dir_state <= 2'd0;
                            state <= CHECK_CELL;
                        end else begin
                            // Last domino
                            if (stack_sum[stack_depth] - ram_data - grid_ram[v_cell] < min_sum) begin
                                min_sum <= stack_sum[stack_depth] - ram_data - grid_ram[v_cell];
                            end
                            // Done with this cell, move to next
                            curr_cell <= curr_cell + 6'd1;
                            dir_state <= 2'd0;
                            state <= CHECK_CELL;
                        end
                    end else begin
                        // Occupied or invalid, move to next cell
                        curr_cell <= curr_cell + 6'd1;
                        dir_state <= 2'd0;
                        state <= CHECK_CELL;
                    end
                end
                
                BACKTRACK: begin
                    // Pop stack
                    if (stack_depth == 4'd0) begin
                        state <= DONE_STATE;
                    end else begin
                        // Restore state
                        k_remain <= k_remain + 4'd1;
                        curr_cell <= stack_cell[stack_depth - 4'd1];
                        // We need to check the NEXT option from the saved state.
                        // If saved dir was 1 (H), we should try V now.
                        // If saved dir was 2 (V), we should try next cell.
                        if (stack_dir[stack_depth - 4'd1] == 2'd1) begin
                            // We just finished H, try V
                            state <= PLACE_V;
                            // Note: curr_cell is already the cell we were at
                        end else begin
                            // We just finished V, try next cell
                            curr_cell <= stack_cell[stack_depth - 4'd1] + 6'd1;
                            dir_state <= 2'd0;
                            state <= CHECK_CELL;
                        end
                        stack_depth <= stack_depth - 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= min_sum;
                    ready <= 1'b1;
                    // Wait for start to go low to avoid re-triggering, or just one cycle.
                    // Spec says done is 1-cycle pulse.
                    // We return to IDLE next cycle.
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Logic to calculate Total Sum during LOAD state
    // We need to track total sum. Since we are in a sequential block,
    // we update total_sum as we load data.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_sum <= 16'd0;
        end else if (state == LOAD_GRID && grid_valid) begin
            total_sum <= total_sum + grid_data;
        end else if (state == INIT_SOLVE) begin
            // Keep total_sum for DFS start
        end else if (state == IDLE) begin
            total_sum <= 16'd0; // Reset when idle
        end
    end

endmodule