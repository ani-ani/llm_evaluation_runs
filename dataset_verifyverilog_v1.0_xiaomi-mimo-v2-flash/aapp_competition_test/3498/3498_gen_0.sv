module priority_ceiling_sim (
    input clk,
    input rst_n,
    input start,
    input cfg_en,
    input [7:0] cfg_addr,
    input [15:0] cfg_data,
    output reg result_valid,
    output reg [3:0] task_done_id,
    output reg [15:0] task_done_time
);

    // Resource Ceiling Array (Address 0-31)
    reg [4:0] resource_ceiling [0:31]; // Priority 0-31
    
    // Task Configuration (Address 32-63)
    // [15:8] Start Time (0-255)
    // [7:0] Base Priority (1-20)
    reg [7:0] task_start_time [0:31]; // 0-255
    reg [4:0] task_base_priority [0:31]; // 1-20
    
    // Instruction ROM (Address 64-255)
    // Format: [7:6] Opcode, [5:0] Operand
    reg [7:0] instruction_rom [0:191]; // 192 instructions (255-64+1)
    
    // Task State Registers
    reg [5:0] task_pc [0:31]; // Program counter (instruction index 0-63)
    reg [15:0] task_execution_time [0:31]; // Current execution time
    reg task_active [0:31]; // Is task currently running?
    reg task_blocked [0:31]; // Is task blocked on a resource?
    reg task_completed [0:31]; // Has task finished all instructions?
    reg [4:0] task_current_priority [0:31]; // Dynamic priority
    reg [4:0] task_blocking_resource [0:31]; // Resource ID task is blocked on
    
    // Resource Lock State
    reg resource_locked [0:31]; // Is resource locked?
    reg [3:0] resource_owner [0:31]; // Which task owns the resource
    
    // Simulation State
    reg [3:0] state;
    reg [3:0] next_state;
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CONFIG        = 4'd1;
    localparam [3:0] SIM_START     = 4'd2;
    localparam [3:0] CHECK_READY   = 4'd3;
    localparam [3:0] UPDATE_PRIOR  = 4'd4;
    localparam [3:0] EXECUTE       = 4'd5;
    localparam [3:0] OUTPUT_RESULTS = 4'd6;
    localparam [3:0] OUTPUT_WAIT   = 4'd7;
    localparam [3:0] DONE          = 4'd8;
    
    // Iteration counters for priority updates
    reg [2:0] iter_count;
    reg stable_flag;
    
    // Output generation counters
    reg [3:0] output_task_idx;
    reg output_done;
    
    // Temporary variables for next state logic
    reg [3:0] i, j;
    reg [4:0] max_prio;
    reg [4:0] temp_prio;
    reg any_task_ready;
    reg [4:0] ceiling;
    
    // Reset logic for all arrays and state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            state <= IDLE;
            result_valid <= 1'b0;
            task_done_id <= 4'd0;
            task_done_time <= 16'd0;
            
            // Reset config arrays
            for (i = 0; i < 32; i = i + 1) begin
                resource_ceiling[i] <= 5'd0;
                task_start_time[i] <= 8'd0;
                task_base_priority[i] <= 5'd0;
                task_pc[i] <= 6'd0;
                task_execution_time[i] <= 16'd0;
                task_active[i] <= 1'b0;
                task_blocked[i] <= 1'b0;
                task_completed[i] <= 1'b0;
                task_current_priority[i] <= 5'd0;
                task_blocking_resource[i] <= 5'd0;
                resource_locked[i] <= 1'b0;
                resource_owner[i] <= 4'd0;
            end
            
            // Reset instruction ROM
            for (i = 0; i < 192; i = i + 1) begin
                instruction_rom[i] <= 8'd0;
            end
            
            iter_count <= 3'd0;
            stable_flag <= 1'b0;
            output_task_idx <= 4'd0;
            output_done <= 1'b0;
            
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (start && !cfg_en) begin
                        state <= SIM_START;
                    end else if (cfg_en) begin
                        state <= CONFIG;
                    end
                end
                
                CONFIG: begin
                    if (!cfg_en) begin
                        state <= IDLE;
                    end else if (cfg_en && cfg_addr >= 8'd0 && cfg_addr < 8'd32) begin
                        // Resource config
                        resource_ceiling[cfg_addr[4:0]] <= cfg_data[4:0];
                    end else if (cfg_en && cfg_addr >= 8'd32 && cfg_addr < 8'd64) begin
                        // Task config
                        task_start_time[cfg_addr[4:0]] <= cfg_data[15:8];
                        task_base_priority[cfg_addr[4:0]] <= cfg_data[7:0];
                    end else if (cfg_en && cfg_addr >= 8'd64) begin
                        // Instruction ROM
                        instruction_rom[cfg_addr[7:0] - 8'd64] <= cfg_data[7:0];
                    end
                end
                
                SIM_START: begin
                    // Initialize task states for simulation
                    for (i = 0; i < 32; i = i + 1) begin
                        task_pc[i] <= 6'd0;
                        task_execution_time[i] <= 16'd0;
                        task_active[i] <= 1'b0;
                        task_blocked[i] <= 1'b0;
                        task_completed[i] <= 1'b0;
                        task_current_priority[i] <= task_base_priority[i];
                        task_blocking_resource[i] <= 5'd0;
                        resource_locked[i] <= 1'b0;
                        resource_owner[i] <= 4'd0;
                    end
                    iter_count <= 3'd0;
                    stable_flag <= 1'b0;
                    state <= CHECK_READY;
                end
                
                CHECK_READY: begin
                    // Check which tasks should start based on Start Time
                    for (i = 0; i < 32; i = i + 1) begin
                        if (!task_completed[i] && !task_active[i] && !task_blocked[i]) begin
                            if (task_execution_time[i] >= {8'd0, task_start_time[i]}) begin
                                task_active[i] <= 1'b1;
                            end
                        end
                    end
                    state <= UPDATE_PRIOR;
                    iter_count <= 3'd0;
                end
                
                UPDATE_PRIOR: begin
                    // Priority Ceiling Protocol Update (fixed-point iteration)
                    stable_flag <= 1'b1;
                    
                    // Check all tasks
                    for (i = 0; i < 32; i = i + 1) begin
                        if (task_active[i] && !task_completed[i]) begin
                            // Base priority
                            temp_prio = task_base_priority[i];
                            
                            // If blocked, inherit priority from blocking resource ceiling
                            if (task_blocked[i]) begin
                                ceiling = resource_ceiling[task_blocking_resource[i]];
                                if (ceiling > temp_prio) temp_prio = ceiling;
                            end
                            
                            // If holding resources, inherit from resource ceilings
                            for (j = 0; j < 32; j = j + 1) begin
                                if (resource_locked[j] && resource_owner[j] == i) begin
                                    ceiling = resource_ceiling[j];
                                    if (ceiling > temp_prio) temp_prio = ceiling;
                                end
                            end
                            
                            // Update if changed
                            if (task_current_priority[i] != temp_prio) begin
                                task_current_priority[i] <= temp_prio;
                                stable_flag <= 1'b0;
                            end
                        end
                    end
                    
                    // Check for blocking/unblocking
                    for (i = 0; i < 32; i = i + 1) begin
                        if (task_active[i] && !task_completed[i] && !task_blocked[i]) begin
                            // Get current instruction
                            if (task_pc[i] < 6'd64) begin
                                reg [7:0] instr = instruction_rom[task_pc[i]];
                                reg [1:0] opcode = instr[7:6];
                                reg [5:0] operand = instr[5:0];
                                
                                if (opcode == 2'b01) begin // Lock
                                    // Check if resource is locked by higher priority task
                                    if (resource_locked[operand] && resource_owner[operand] != i) begin
                                        // Blocked if resource owner has higher priority
                                        if (task_current_priority[resource_owner[operand]] > task_current_priority[i]) begin
                                            task_blocked[i] <= 1'b1;
                                            task_blocking_resource[i] <= operand;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    // Iterate until stable (3 iterations max for simplicity)
                    if (iter_count >= 3'd2) begin
                        state <= EXECUTE;
                    end else begin
                        iter_count <= iter_count + 3'd1;
                        if (!stable_flag) begin
                            state <= UPDATE_PRIOR;
                        end else begin
                            state <= EXECUTE;
                        end
                    end
                end
                
                EXECUTE: begin
                    // Find highest priority ready task
                    max_prio = 5'd0;
                    any_task_ready = 1'b0;
                    reg [3:0] selected_task = 4'd0;
                    
                    for (i = 0; i < 32; i = i + 1) begin
                        if (task_active[i] && !task_completed[i] && !task_blocked[i]) begin
                            if (task_current_priority[i] >= max_prio) begin
                                max_prio = task_current_priority[i];
                                selected_task = i;
                                any_task_ready = 1'b1;
                            end
                        end
                    end
                    
                    if (any_task_ready) begin
                        reg [7:0] instr = instruction_rom[task_pc[selected_task]];
                        reg [1:0] opcode = instr[7:6];
                        reg [5:0] operand = instr[5:0];
                        
                        case (opcode)
                            2'b00: begin // Compute
                                task_execution_time[selected_task] <= task_execution_time[selected_task] + 16'd1;
                                task_pc[selected_task] <= task_pc[selected_task] + 6'd1;
                            end
                            2'b01: begin // Lock
                                resource_locked[operand] <= 1'b1;
                                resource_owner[operand] <= selected_task;
                                task_pc[selected_task] <= task_pc[selected_task] + 6'd1;
                            end
                            2'b10: begin // Unlock
                                resource_locked[operand] <= 1'b0;
                                resource_owner[operand] <= 4'd0;
                                task_pc[selected_task] <= task_pc[selected_task] + 6'd1;
                            end
                            default: begin
                                task_pc[selected_task] <= task_pc[selected_task] + 6'd1;
                            end
                        endcase
                        
                        // Check if task completed
                        if (task_pc[selected_task] >= 6'd63) begin
                            task_completed[selected_task] <= 1'b1;
                            task_active[selected_task] <= 1'b0;
                            task_done_id <= selected_task;
                            task_done_time <= task_execution_time[selected_task];
                            result_valid <= 1'b1;
                        end
                    end
                    
                    // Check if all tasks done
                    reg all_done = 1'b1;
                    for (i = 0; i < 32; i = i + 1) begin
                        if (!task_completed[i] && task_start_time[i] != 8'd0) begin
                            all_done = 1'b0;
                        end
                    end
                    
                    if (all_done) begin
                        output_task_idx <= 4'd0;
                        output_done <= 1'b0;
                        state <= OUTPUT_RESULTS;
                    end else begin
                        state <= CHECK_READY;
                    end
                end
                
                OUTPUT_RESULTS: begin
                    // Output completed tasks one per cycle
                    if (output_task_idx < 4'd16) begin
                        task_done_id <= output_task_idx;
                        task_done_time <= task_execution_time[output_task_idx];
                        result_valid <= 1'b1;
                        output_task_idx <= output_task_idx + 4'd1;
                        state <= OUTPUT_WAIT;
                    end else begin
                        state <= DONE;
                    end
                end
                
                OUTPUT_WAIT: begin
                    result_valid <= 1'b0;
                    state <= OUTPUT_RESULTS;
                end
                
                DONE: begin
                    result_valid <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule