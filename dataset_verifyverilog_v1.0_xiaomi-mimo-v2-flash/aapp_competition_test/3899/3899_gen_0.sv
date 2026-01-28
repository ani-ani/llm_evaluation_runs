module TaskOptimizer (
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [7:0] power [0:49],
    input [7:0] processors [0:49],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_PROCESS = 3'd3;
    localparam [2:0] CALCULATE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [5:0] i, j, k;
    reg [5:0] n_reg;
    reg [7:0] sorted_power [0:49];
    reg [7:0] sorted_procs [0:49];
    
    // DP tables: dp_power[proc_sum] = min total power for that processor sum
    // proc_sum max = 50*100 = 5000, so need 13 bits
    // power max = 50*100000 = 5,000,000, need 23 bits
    localparam DP_SIZE = 5001;
    reg [22:0] dp_power [0:5000];  // min power for each processor sum
    reg dp_valid [0:5000];          // whether this sum is achievable
    
    // Temporary storage for DP updates
    reg [22:0] temp_power;
    reg [12:0] temp_proc;
    reg [22:0] new_power;
    reg [12:0] new_proc;
    reg [5:0] task_idx;
    reg [2:0] sort_stage;
    
    // Variables for calculation
    reg [22:0] best_power;
    reg [12:0] best_procs;
    reg [53:0] calc_temp;  // 23+31 = 54 bits for division
    reg [31:0] calc_result;
    reg [2:0] calc_stage;
    
    // Comparator for sorting
    wire cmp_result;
    assign cmp_result = (sorted_power[i] < sorted_power[j]);
    
    // Loop counters
    integer loop_i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n_reg <= 6'd0;
            i <= 6'd0;
            j <= 6'd0;
            k <= 6'd0;
            task_idx <= 6'd0;
            sort_stage <= 3'd0;
            calc_stage <= 3'd0;
            best_power <= 23'd0;
            best_procs <= 13'd0;
            calc_temp <= 54'd0;
            calc_result <= 32'd0;
            temp_power <= 23'd0;
            temp_proc <= 13'd0;
            new_power <= 23'd0;
            new_proc <= 13'd0;
            
            for (loop_i = 0; loop_i < 50; loop_i = loop_i + 1) begin
                sorted_power[loop_i] <= 8'd0;
                sorted_procs[loop_i] <= 8'd0;
            end
            
            for (loop_i = 0; loop_i <= 5000; loop_i = loop_i + 1) begin
                dp_power[loop_i] <= 23'h7FFFFF;  // Large value
                dp_valid[loop_i] <= 1'b0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SORT;
                        n_reg <= n;
                        i <= 6'd0;
                        j <= 6'd0;
                        sort_stage <= 3'd0;
                        
                        // Initialize sorted arrays
                        for (loop_i = 0; loop_i < 50; loop_i = loop_i + 1) begin
                            if (loop_i < n) begin
                                sorted_power[loop_i] <= power[loop_i];
                                sorted_procs[loop_i] <= processors[loop_i];
                            end else begin
                                sorted_power[loop_i] <= 8'd0;
                                sorted_procs[loop_i] <= 8'd0;
                            end
                        end
                    end
                end
                
                SORT: begin
                    // Bubble sort for simplicity (50 elements worst case ~2500 cycles)
                    case (sort_stage)
                        3'd0: begin
                            // Initialize for bubble sort
                            i <= 6'd0;
                            j <= 6'd0;
                            sort_stage <= 3'd1;
                        end
                        3'd1: begin
                            if (i < n_reg - 1) begin
                                if (j < n_reg - 1 - i) begin
                                    if (sorted_power[j] < sorted_power[j+1]) begin
                                        // Swap power and processors
                                        sorted_power[j] <= sorted_power[j+1];
                                        sorted_power[j+1] <= sorted_power[j];
                                        sorted_procs[j] <= sorted_procs[j+1];
                                        sorted_procs[j+1] <= sorted_procs[j];
                                    end
                                    j <= j + 6'd1;
                                end else begin
                                    j <= 6'd0;
                                    i <= i + 6'd1;
                                end
                            end else begin
                                sort_stage <= 3'd2;
                                i <= 6'd0;
                            end
                        end
                        3'd2: begin
                            state <= DP_INIT;
                            i <= 6'd0;
                            k <= 6'd0;
                        end
                        default: sort_stage <= 3'd0;
                    endcase
                end
                
                DP_INIT: begin
                    // Initialize DP tables
                    if (i <= 5000) begin
                        dp_power[i] <= 23'h7FFFFF;
                        dp_valid[i] <= 1'b0;
                        i <= i + 6'd1;
                    end else begin
                        dp_power[0] <= 23'd0;
                        dp_valid[0] <= 1'b1;
                        i <= 6'd0;
                        task_idx <= 6'd0;
                        state <= DP_PROCESS;
                    end
                end
                
                DP_PROCESS: begin
                    if (task_idx < n_reg) begin
                        // Process task task_idx
                        // Task can be: first in pair, second in pair, or alone
                        
                        case (k)
                            3'd0: begin
                                // Phase 0: Update for being second task
                                // Second task must be paired with a previous task that has higher power
                                // We iterate backwards to avoid using updated values
                                temp_proc <= {5'd0, sorted_procs[task_idx]};
                                temp_power <= {15'd0, sorted_power[task_idx]};
                                i <= 5000;
                                k <= 3'd1;
                            end
                            3'd1: begin
                                // Check if we can be second task (need previous first task with higher power)
                                if (i > {5'd0, sorted_procs[task_idx]}) begin
                                    // Look at dp state at i - current_proc
                                    if (dp_valid[i - {5'd0, sorted_procs[task_idx]}]) begin
                                        new_power <= dp_power[i - {5'd0, sorted_procs[task_idx]}];
                                        new_proc <= i;
                                        k <= 3'd2;
                                    end else begin
                                        i <= i - 6'd1;
                                    end
                                end else begin
                                    k <= 3'd3;
                                end
                            end
                            3'd2: begin
                                // Update DP if better (for second task, power doesn't increase)
                                if (!dp_valid[new_proc] || new_power < dp_power[new_proc]) begin
                                    dp_power[new_proc] <= new_power;
                                    dp_valid[new_proc] <= 1'b1;
                                end
                                i <= i - 6'd1;
                                k <= 3'd1;
                            end
                            3'd3: begin
                                // Phase 1: Update for being first task or alone
                                // Need to iterate backwards to avoid using current task's update
                                i <= 5000;
                                k <= 3'd4;
                            end
                            3'd4: begin
                                if (i >= {5'd0, sorted_procs[task_idx]}) begin
                                    if (dp_valid[i - {5'd0, sorted_procs[task_idx]}]) begin
                                        // Can be first task (alone or paired later)
                                        new_power <= dp_power[i - {5'd0, sorted_procs[task_idx]}] + {15'd0, sorted_power[task_idx]};
                                        new_proc <= i;
                                        k <= 3'd5;
                                    end else begin
                                        i <= i - 6'd1;
                                    end
                                end else begin
                                    task_idx <= task_idx + 6'd1;
                                    k <= 3'd0;
                                end
                            end
                            3'd5: begin
                                // Update DP for first task
                                if (!dp_valid[new_proc] || new_power < dp_power[new_proc]) begin
                                    dp_power[new_proc] <= new_power;
                                    dp_valid[new_proc] <= 1'b1;
                                end
                                i <= i - 6'd1;
                                k <= 3'd4;
                            end
                            default: k <= 3'd0;
                        endcase
                        
                    end else begin
                        state <= CALCULATE;
                        i <= 6'd1;  // Start from proc sum 1
                        best_power <= 23'h7FFFFF;
                        best_procs <= 13'd0;
                        calc_stage <= 3'd0;
                    end
                end
                
                CALCULATE: begin
                    case (calc_stage)
                        3'd0: begin
                            // Find minimum average
                            if (i <= 5000) begin
                                if (dp_valid[i]) begin
                                    // Check if this gives better average
                                    // Compare: dp_power[i]/i vs best_power/best_procs
                                    // Use cross multiplication to avoid division
                                    // dp_power[i] * best_procs vs best_power * i
                                    
                                    if (best_power == 23'h7FFFFF) begin
                                        best_power <= dp_power[i];
                                        best_procs <= i;
                                        i <= i + 6'd1;
                                    end else begin
                                        calc_temp <= {22'd0, dp_power[i]};
                                        calc_temp <= calc_temp * {19'd0, best_procs};
                                        calc_temp <= calc_temp >> 13;  // Adjust
                                        // Actually, let's do proper comparison
                                        calc_stage <= 3'd1;
                                    end
                                end else begin
                                    i <= i + 6'd1;
                                end
                            end else begin
                                calc_stage <= 3'd2;
                            end
                        end
                        3'd1: begin
                            // Compare dp_power[i]/i vs best_power/best_procs
                            // dp_power[i] * best_procs < best_power * i ?
                            // Using 64-bit for multiplication
                            calc_temp <= {41'd0, dp_power[i]} * {51'd0, best_procs};
                            // Check if calculation complete in next cycle
                            calc_stage <= 3'd6;
                        end
                        3'd6: begin
                            // Store result
                            if (calc_temp < {41'd0, best_power} * {51'd0, i}) begin
                                best_power <= dp_power[i];
                                best_procs <= i;
                            end
                            i <= i + 6'd1;
                            calc_stage <= 3'd0;
                        end
                        3'd2: begin
                            // Calculate answer: ceil(best_power * 1000 / best_procs)
                            // Need integer division with ceiling
                            calc_temp <= {31'd0, best_power} * {34'd0, 1000};
                            calc_stage <= 3'd3;
                        end
                        3'd3: begin
                            // Division
                            if (best_procs > 13'd0) begin
                                calc_result <= calc_temp / {19'd0, best_procs};
                                // Check if there's remainder for ceiling
                                if (calc_temp % {19'd0, best_procs} > 13'd0) begin
                                    calc_stage <= 3'd4;
                                end else begin
                                    calc_stage <= 3'd5;
                                end
                            end else begin
                                calc_result <= 32'd0;
                                calc_stage <= 3'd5;
                            end
                        end
                        3'd4: begin
                            calc_result <= calc_result + 32'd1;
                            calc_stage <= 3'd5;
                        end
                        3'd5: begin
                            result <= calc_result;
                            state <= FINISH;
                        end
                        default: calc_stage <= 3'd0;
                    endcase
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