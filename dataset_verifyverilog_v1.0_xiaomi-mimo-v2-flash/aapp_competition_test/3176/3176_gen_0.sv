module barica_frog(
    input clk,
    input rst_n,
    input start,
    input [15:0] plant_x [0:15],
    input [15:0] plant_y [0:15],
    input [9:0] plant_f [0:15],
    input [4:0] num_plants,
    input [9:0] jump_cost,
    output reg [15:0] result_energy,
    output reg [4:0] path_count,
    output reg [3:0] path_idx [0:15],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] UPDATE = 3'd2;
    localparam [2:0] BACKTRACK = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Registers for DP arrays
    reg [15:0] energy_dp [0:15];
    reg [3:0] prev_dp [0:15];
    reg valid_dp [0:15];
    
    // Working arrays for sorting
    reg [15:0] work_x [0:15];
    reg [15:0] work_y [0:15];
    reg [9:0] work_f [0:15];
    reg [3:0] work_idx [0:15];  // Original indices for reconstruction
    
    // Counters and indices
    reg [4:0] i;
    reg [4:0] j;
    reg [4:0] k;
    reg [3:0] sorted_count;
    reg [3:0] backtrack_idx;
    reg [3:0] path_idx_counter;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;
    
    // Temporary variables for updates
    reg [15:0] current_energy;
    reg [15:0] new_energy;
    reg jump_valid;
    
    // For backtracking
    reg [3:0] temp_path [0:15];
    reg [3:0] temp_count;
    
    integer p;
    integer q;
    integer r;
    integer s;
    integer t;
    
    // State transition and register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_energy <= 16'd0;
            path_count <= 5'd0;
            cycle_count <= 5'd0;
            
            // Initialize DP arrays
            for (p = 0; p < 16; p = p + 1) begin
                energy_dp[p] <= 16'd0;
                prev_dp[p] <= 4'd15;  // Invalid index
                valid_dp[p] <= 1'b0;
            end
            
            // Initialize working arrays
            for (q = 0; q < 16; q = q + 1) begin
                work_x[q] <= 16'd0;
                work_y[q] <= 16'd0;
                work_f[q] <= 10'd0;
                work_idx[q] <= 4'd0;
                path_idx[q] <= 4'd0;
            end
            
            sorted_count <= 4'd0;
            backtrack_idx <= 4'd0;
            path_idx_counter <= 4'd0;
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    
                    if (start) begin
                        // Initialize for new computation
                        for (r = 0; r < 16; r = r + 1) begin
                            energy_dp[r] <= 16'd0;
                            prev_dp[r] <= 4'd15;
                            valid_dp[r] <= 1'b0;
                        end
                        sorted_count <= 4'd0;
                    end
                end
                
                SORT: begin
                    // Copy input to working arrays for processing
                    for (s = 0; s < 16; s = s + 1) begin
                        work_x[s] <= plant_x[s];
                        work_y[s] <= plant_y[s];
                        work_f[s] <= plant_f[s];
                        work_idx[s] <= s[3:0];
                    end
                end
                
                UPDATE: begin
                    // Dynamic programming update
                    // Process each plant (i) from sorted list
                    if (i < num_plants) begin
                        // Initialize from plant 0
                        if (i == 4'd0) begin
                            energy_dp[work_idx[0]] <= work_f[0];
                            valid_dp[work_idx[0]] <= 1'b1;
                        end else begin
                            current_energy <= 16'd0;
                            new_energy <= 16'd0;
                            jump_valid <= 1'b0;
                            
                            // Check all previous plants j
                            if (j < i) begin
                                if (valid_dp[work_idx[j]]) begin
                                    // Check if horizontal jump (y same, x increases)
                                    if (work_y[i] == work_y[j] && work_x[i] > work_x[j]) begin
                                        if (energy_dp[work_idx[j]] >= jump_cost) begin
                                            new_energy <= energy_dp[work_idx[j]] - jump_cost + work_f[i];
                                            jump_valid <= 1'b1;
                                        end
                                    end
                                    // Check if vertical jump (x same, y increases)
                                    else if (work_x[i] == work_x[j] && work_y[i] > work_y[j]) begin
                                        if (energy_dp[work_idx[j]] >= jump_cost) begin
                                            new_energy <= energy_dp[work_idx[j]] - jump_cost + work_f[i];
                                            jump_valid <= 1'b1;
                                        end
                                    end
                                end
                            end else if (j == i) begin
                                // Update DP table
                                if (j == 4'd0 || !valid_dp[work_idx[i]]) begin
                                    // First reach or not reached yet
                                    if (jump_valid || i == 4'd0) begin
                                        if (i == 4'd0) begin
                                            energy_dp[work_idx[i]] <= work_f[i];
                                            prev_dp[work_idx[i]] <= 4'd15;
                                            valid_dp[work_idx[i]] <= 1'b1;
                                        end else begin
                                            energy_dp[work_idx[i]] <= new_energy;
                                            prev_dp[work_idx[i]] <= work_idx[j];
                                            valid_dp[work_idx[i]] <= 1'b1;
                                        end
                                    end
                                end else begin
                                    // Already reached, update if better
                                    if (jump_valid && new_energy > energy_dp[work_idx[i]]) begin
                                        energy_dp[work_idx[i]] <= new_energy;
                                        prev_dp[work_idx[i]] <= work_idx[j];
                                    end
                                end
                                jump_valid <= 1'b0;
                            end
                        end
                    end
                end
                
                BACKTRACK: begin
                    // Reconstruct path from destination
                    if (backtrack_idx == 4'd0) begin
                        path_idx_counter <= 4'd0;
                        // Start from last plant (num_plants - 1)
                        if (valid_dp[work_idx[num_plants - 1]]) begin
                            temp_path[0] <= work_idx[num_plants - 1];
                            temp_count <= 4'd1;
                            backtrack_idx <= 4'd1;
                            
                            // Initialize path_idx for output
                            for (t = 0; t < 16; t = t + 1) begin
                                path_idx[t] <= 4'd0;
                            end
                        end
                    end else if (backtrack_idx < num_plants) begin
                        // Continue backtracking
                        if (temp_path[backtrack_idx - 1] != 4'd15) begin
                            temp_path[backtrack_idx] <= prev_dp[temp_path[backtrack_idx - 1]];
                            temp_count <= temp_count + 4'd1;
                            backtrack_idx <= backtrack_idx + 4'd1;
                        end else begin
                            // Reached start of path
                            backtrack_idx <= num_plants;
                        end
                    end else begin
                        // Finalize path output (reverse order)
                        if (path_idx_counter < temp_count) begin
                            path_idx[path_idx_counter] <= temp_path[temp_count - path_idx_counter - 1];
                            path_idx_counter <= path_idx_counter + 4'd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (valid_dp[work_idx[num_plants - 1]]) begin
                        result_energy <= energy_dp[work_idx[num_plants - 1]];
                    end else begin
                        result_energy <= 16'd0;
                    end
                    path_count <= temp_count;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic with cycle counter
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = SORT;
            end
            
            SORT: begin
                // Move to UPDATE immediately after sorting (already sorted by index)
                next_state = UPDATE;
            end
            
            UPDATE: begin
                // Complex control logic for DP update
                if (i >= num_plants - 1 && j >= i) begin
                    next_state = BACKTRACK;
                end else begin
                    next_state = UPDATE;
                end
            end
            
            BACKTRACK: begin
                if (backtrack_idx >= num_plants && path_idx_counter >= temp_count) begin
                    next_state = FINISH;
                end else begin
                    next_state = BACKTRACK;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Update loop counters in always block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 5'd0;
            j <= 5'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                UPDATE: begin
                    if (i < num_plants - 1) begin
                        if (j < i) begin
                            j <= j + 5'd1;
                        end else if (j == i) begin
                            j <= 5'd0;
                            i <= i + 5'd1;
                        end
                    end else if (i == num_plants - 1) begin
                        if (j < i) begin
                            j <= j + 5'd1;
                        end else if (j == i) begin
                            i <= i + 5'd1;
                        end
                    end
                    cycle_count <= cycle_count + 5'd1;
                end
                
                BACKTRACK: begin
                    // Counters handled in main always block
                end
                
                IDLE: begin
                    if (start) begin
                        i <= 5'd0;
                        j <= 5'd0;
                        cycle_count <= 5'd0;
                    end
                end
            endcase
        end
    end

endmodule