module hanoi_min_cost(
    input clk,
    input rst_n,
    input start,
    input [2:0] matrix_in [2:0],
    input [5:0] n,
    input [2:0] rod_index,
    input load_matrix,
    output reg [63:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b001;
    localparam LOAD_MATRIX = 3'b010;
    localparam PROCESSING = 3'b100;
    localparam DONE = 3'b000; // Done uses IDLE logic effectively but distinct state

    reg [2:0] state;
    
    // Matrix Storage (3x3)
    reg [63:0] cost_matrix [2:0][2:0];
    
    // DP Table Storage (Double Buffering)
    // dp[rod_from][rod_to]
    reg [63:0] dp_old [2:0][2:0];
    reg [63:0] dp_new [2:0][2:0];
    
    // Counters and Indices
    reg [5:0] disk_cnt;       // Counts 1 to n
    reg [2:0] row_idx;        // 0 to 2 (from rod)
    reg [2:0] col_idx;        // 0 to 2 (to rod)
    reg [2:0] other_rod;      // Computed other rod
    
    // Intermediate calculation registers
    reg [63:0] strat1_cost;
    reg [63:0] strat2_cost;
    reg [63:0] min_cost;
    
    // Loading counter
    reg [1:0] load_cnt;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= LOAD_MATRIX;
                end
                LOAD_MATRIX: begin
                    if (load_cnt == 2'b10 && load_matrix) state <= PROCESSING;
                end
                PROCESSING: begin
                    // Logic will transition to DONE when finished
                    // We handle this based on counters in combinational logic below
                    if (disk_cnt > n && row_idx == 0 && col_idx == 0) state <= DONE;
                end
                DONE: begin
                    if (start) state <= LOAD_MATRIX; // Allow restart
                end
                default: state <= IDLE;
            endcase
        end
    end

    // Matrix Loading Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_cnt <= 2'b0;
        end else if (state == IDLE && start) begin
            load_cnt <= 2'b0;
        end else if (state == LOAD_MATRIX && load_matrix) begin
            // Load row based on rod_index
            // We assume rod_index 0,1,2 come in order or arbitrary
            // Instruction says "one row per cycle", implies sequential loading or indexed
            // Let's use the rod_index input to know which row to load
            cost_matrix[rod_index][0] <= {32'b0, matrix_in[0]}; // Input is [2:0], expand to 64b
            cost_matrix[rod_index][1] <= {32'b0, matrix_in[1]};
            cost_matrix[rod_index][2] <= {32'b0, matrix_in[2]};
            
            // Count loaded rows
            if (load_cnt < 2'b10) load_cnt <= load_cnt + 1'b1;
        end
    end

    // Processing Logic (Counters and State Updates)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            disk_cnt <= 6'b1; // Start with disk 1
            row_idx <= 3'b0;
            col_idx <= 3'b0;
        end else if (state == IDLE && start) begin
            disk_cnt <= 6'b1;
            row_idx <= 3'b0;
            col_idx <= 3'b0;
            // Initialize DP for disk 0 (0 cost)
            // Actually disk 1 uses dp[0] which is 0. 
            // We need to ensure dp_old is initialized to 0 for first iteration.
        end else if (state == PROCESSING) begin
            // Update indices every clock cycle (fully pipelined)
            // If we are done with all disks and all pairs, stop (transition handled in state logic)
            if (!(disk_cnt > n && row_idx == 0 && col_idx == 0)) begin
                if (col_idx == 3'd2) begin
                    col_idx <= 3'd0;
                    if (row_idx == 3'd2) begin
                        row_idx <= 3'd0;
                        // Switch buffers
                        // dp_old <= dp_new; 
                        // Since Verilog doesn't support array assignment directly, we swap logic
                        // We update dp_old physically at the end of the cycle
                        
                        if (disk_cnt >= n) begin
                            disk_cnt <= disk_cnt + 1'b1; // Will go to n+1 to trigger finish
                        end else begin
                            disk_cnt <= disk_cnt + 1'b1;
                        end
                    end else begin
                        row_idx <= row_idx + 1'b1;
                    end
                end else begin
                    col_idx <= col_idx + 1'b1;
                end
            end
        end else if (state == LOAD_MATRIX && start) begin
             // Reset if start asserted during load (optional)
             disk_cnt <= 6'b1;
             row_idx <= 3'b0;
             col_idx <= 3'b0;
        end
    end

    // Buffer Swapping and Result Storage
    always @(posedge clk) begin
        if (state == PROCESSING) begin
            // Calculate other rod
            // other = 3 - frm - to
            // For synthesis, subtraction is fine
            
            // Perform Calculations
            // Strategy 1: 
            // dp[k-1][frm][other] + cost[frm][to] + dp[k-1][other][to]
            
            // Strategy 2:
            // dp[k-1][frm][to] + cost[frm][other] + dp[k-1][to][frm] + 
            // cost[other][to] + dp[k-1][frm][to]
            
            // We update dp_new for current (row_idx, col_idx)
            // Note: We must use the OLD dp values before they are overwritten.
            // In a pipelined design, we read dp_old (the buffer from previous disk)
            // Wait, the problem says "double buffer" or "current/next".
            // Let's use dp_old for reads (previous disk size k-1)
            // and dp_new for writes (current disk size k).
            // However, the description implies dp_new is updated based on dp_old.
            // But dp_new starts as undefined or 0.
            // Correct logic:
            // At disk k, dp_old holds results for k-1.
            // We write to dp_new.
            // At the end of disk k (when row/col are done), we swap pointers.
            
            // Actually, simpler: 
            // We need to initialize dp for k=0 (0 disks) as all 0.
            // Then for k=1...n, compute.
            
            // Since we iterate in sequence, we can read from dp_old and write to dp_new.
            // BUT: Strategy 2 reads dp[k-1][frm][to] which is dp_old[frm][to].
            // It also reads dp[k-1][to][frm] (dp_old[to][frm]).
            // Strategy 1 reads dp_old[frm][other] and dp_old[other][to].
            
            // If we write to dp_new[row_idx][col_idx] every cycle,
            // we must be careful not to overwrite values needed by other pairs in the SAME disk iteration.
            // However, the problem description suggests updating the table for disk k.
            // The recurrence for disk k relies ONLY on disk k-1 values.
            // So we can have two separate memory blocks (True Dual Port or Simple Dual Port).
            // Read from Block A (disk k-1), Write to Block B (disk k).
            
            // Let's implement the swap logic by toggling a pointer.
            // But since we are in a single always block for registers,
            // let's explicitly define the read/write logic.
            
            // Logic update 10/24: 
            // To avoid complexity of two memory banks in generated code,
            // we rely on the fact that we read 4 values and write 1.
            // The values read are from 'dp_old' (the previous disk set).
            // The value written goes to 'dp_new' (the current disk set).
            // Since dp_old and dp_new are distinct arrays, this is safe.
            // The swap happens conceptually at the end of the disk loop.
            // We need to copy dp_new to dp_old or swap pointers.
            // Hardware efficient: 
            // We use a flag 'valid_calc'.
            
            // Let's pre-calculate indices to avoid timing issues.
            // Read values from dp_old
            // Write values to dp_new
        end
    end

    // Combinational Logic for Calculation
    // This block runs continuously. It calculates the min cost for the CURRENT (row_idx, col_idx)
    // based on dp_old.
    always @(*) begin
        integer o;
        reg [63:0] p1, p2;
        
        o = 3 - row_idx - col_idx; // other rod
        
        if (o < 0 || o > 2) o = 0; // Safety, though math should be fine
        
        // Strategy 1
        // dp[k-1][row][other] + cost[row][col] + dp[k-1][other][col]
        strat1_cost = dp_old[row_idx][o] + cost_matrix[row_idx][col_idx] + dp_old[o][col_idx];
        
        // Strategy 2
        // dp[k-1][row][col] + cost[row][other] + dp[k-1][col][row] + cost[other][col] + dp[k-1][row][col]
        // Simplified: 2 * dp_old[row_idx][col_idx] + cost_matrix[row_idx][o] + dp_old[col_idx][row_idx] + cost_matrix[o][col_idx];
        strat2_cost = (dp_old[row_idx][col_idx] << 1) + 
                      cost_matrix[row_idx][o] + 
                      dp_old[col_idx][row_idx] + 
                      cost_matrix[o][col_idx];
        
        // Min
        min_cost = (strat1_cost < strat2_cost) ? strat1_cost : strat2_cost;
    end

    // Write Operation
    always @(posedge clk) begin
        if (state == PROCESSING) begin
            // Update dp_new with the calculated min
            dp_new[row_idx][col_idx] <= min_cost;
        end
    end

    // Swap Logic
    // When a full disk is computed (i.e., we move to the next disk count), copy dp_new to dp_old
    // We detect this by checking if we just finished the last column of the last row for the current disk
    // But wait, the code above increments disk_cnt at the END of the row loop.
    // So if we are at the start of a new disk loop (disk_cnt changed), we need dp_old to be dp_new.
    // Easier: 
    // The calculation uses dp_old. 
    // We update dp_new continuously.
    // When disk_cnt increments, we essentially move to the next iteration.
    // At that point, what we just calculated in dp_new becomes the new source (dp_old).
    // Since we can't assign arrays in standard Verilog like that, we use explicit copy or pointers.
    // 
    // Optimization: 
    // Instead of copying 64 bytes of registers, let's use a pointer logic or explicit copy logic.
    // Given the constraints, a simple copy is safest.
    
    reg swap_trigger;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) swap_trigger <= 0;
        else begin
            // Detect end of a disk calculation (end of row 2, col 2)
            if (state == PROCESSING && row_idx == 3'd2 && col_idx == 3'd2) begin
                swap_trigger <= 1;
            end else begin
                swap_trigger <= 0;
            end
        end
    end

    always @(posedge clk) begin
        if (state == PROCESSING && swap_trigger) begin
            // Copy dp_new to dp_old
            dp_old[0][0] <= dp_new[0][0];
            dp_old[0][1] <= dp_new[0][1];
            dp_old[0][2] <= dp_new[0][2];
            dp_old[1][0] <= dp_new[1][0];
            dp_old[1][1] <= dp_new[1][1];
            dp_old[1][2] <= dp_new[1][2];
            dp_old[2][0] <= dp_new[2][0];
            dp_old[2][1] <= dp_new[2][1];
            dp_old[2][2] <= dp_new[2][2];
        end
    end

    // Initial DP setup (Disk 0 cost is 0)
    // Since we use dp_old in calculations, and dp_old needs to be 0 for k=1.
    // We ensure dp_old is 0 at start.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_old[0][0] <= 0; dp_old[0][1] <= 0; dp_old[0][2] <= 0;
            dp_old[1][0] <= 0; dp_old[1][1] <= 0; dp_old[1][2] <= 0;
            dp_old[2][0] <= 0; dp_old[2][1] <= 0; dp_old[2][2] <= 0;
            
            dp_new[0][0] <= 0; dp_new[0][1] <= 0; dp_new[0][2] <= 0;
            dp_new[1][0] <= 0; dp_new[1][1] <= 0; dp_new[1][2] <= 0;
            dp_new[2][0] <= 0; dp_new[2][1] <= 0; dp_new[2][2] <= 0;
        end else if (state == IDLE && start) begin
            // Reset to 0 on start just in case
            dp_old[0][0] <= 0; dp_old[0][1] <= 0; dp_old[0][2] <= 0;
            dp_old[1][0] <= 0; dp_old[1][1] <= 0; dp_old[1][2] <= 0;
            dp_old[2][0] <= 0; dp_old[2][1] <= 0; dp_old[2][2] <= 0;
            dp_new[0][0] <= 0; dp_new[0][1] <= 0; dp_new[0][2] <= 0;
            dp_new[1][0] <= 0; dp_new[1][1] <= 0; dp_new[1][2] <= 0;
            dp_new[2][0] <= 0; dp_new[2][1] <= 0; dp_new[2][2] <= 0;
        end
    end

    // Result Output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 64'b0;
            done <= 1'b0;
        end else begin
            if (state == DONE) begin
                // The result for n disks from 0 to 2 is in the buffer
                // Note: After the last swap_trigger (end of disk n), dp_old holds dp[n]
                // Or dp_new holds dp[n].
                // The swap happens at the END of the cycle when row_idx=2, col_idx=2.
                // So dp_old becomes the result for the completed disk.
                // If we loop until disk_cnt > n, the buffer holds disk n results.
                result <= dp_old[0][2]; // From rod 0 to rod 2
                done <= 1'b1;
            end else if (state == IDLE && start) begin
                done <= 1'b0;
            end
        end
    end

endmodule
