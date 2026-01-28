module priority_ceiling_sim(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG = 3'd1;
    localparam [2:0] SIMULATE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE = 3'd4;

    reg [2:0] state, next_state;

    // Configuration memory
    reg [7:0] resource_ceiling [0:31];  // Resource ceiling priorities
    reg [15:0] task_config [0:31];      // Task configurations (start time, base priority)
    reg [15:0] instruction_rom [0:191]; // Instruction ROM (64-255)

    // Simulation state
    reg [3:0] current_task_id;
    reg [15:0] current_time;
    reg [3:0] task_pc [0:31];           // Program counters for each task
    reg [3:0] task_state [0:31];        // 0=idle, 1=ready, 2=running, 3=blocked
    reg [4:0] task_priority [0:31];     // Current priority (base or ceiling)
    reg [15:0] task_start_time [0:31];  // Start time for each task
    reg [4:0] task_base_priority [0:31]; // Base priority for each task
    reg [3:0] resource_owner [0:31];    // Current owner of each resource
    reg [4:0] resource_ceiling_val [0:31]; // Ceiling priority for each resource

    // Output queue
    reg [3:0] output_queue_id [0:31];
    reg [15:0] output_queue_time [0:31];
    reg [4:0] output_queue_head, output_queue_tail;
    reg [4:0] output_queue_count;

    // Temporary signals
    reg [3:0] i, j;
    reg [4:0] max_priority;
    reg [3:0] highest_priority_task;
    reg priority_changed;
    reg [3:0] temp_task_id;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            task_done_id <= 4'd0;
            task_done_time <= 16'd0;
            current_task_id <= 4'd0;
            current_time <= 16'd0;
            output_queue_head <= 5'd0;
            output_queue_tail <= 5'd0;
            output_queue_count <= 5'd0;

            // Initialize configuration memory
            for (i = 0; i < 32; i = i + 1) begin
                resource_ceiling[i] <= 8'd0;
                task_config[i] <= 16'd0;
                task_pc[i] <= 4'd0;
                task_state[i] <= 2'd0;  // idle
                task_priority[i] <= 5'd0;
                task_start_time[i] <= 16'd0;
                task_base_priority[i] <= 5'd0;
                resource_owner[i] <= 4'd31;  // no owner
                resource_ceiling_val[i] <= 5'd0;
            end

            // Initialize instruction ROM
            for (i = 0; i < 192; i = i + 1) begin
                instruction_rom[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CONFIG;
            end
            CONFIG: begin
                if (!cfg_en) next_state = SIMULATE;
            end
            SIMULATE: begin
                if (output_queue_count >= 5'd1) next_state = OUTPUT;
            end
            OUTPUT: begin
                if (output_queue_count == 5'd0) next_state = DONE;
            end
            DONE: begin
                if (start) next_state = CONFIG;
            end
            default: next_state = IDLE;
        endcase
    end

    // Configuration mode
    always @(posedge clk) begin
        if (cfg_en && state == CONFIG) begin
            if (cfg_addr < 8'd32) begin
                // Resource configuration
                resource_ceiling[cfg_addr] <= cfg_data[7:0];
                resource_ceiling_val[cfg_addr] <= cfg_data[7:0];
            end else if (cfg_addr < 8'd64) begin
                // Task configuration
                task_config[cfg_addr - 8'd32] <= cfg_data;
                task_start_time[cfg_addr - 8'd32] <= {8'd0, cfg_data[15:8]};
                task_base_priority[cfg_addr - 8'd32] <= cfg_data[7:0];
            end else if (cfg_addr < 8'd256) begin
                // Instruction ROM
                instruction_rom[cfg_addr - 8'd64] <= cfg_data;
            end
        end
    end

    // Simulation logic
    always @(posedge clk) begin
        if (state == SIMULATE) begin
            // Step 1: Identify running tasks and update states
            for (i = 0; i < 32; i = i + 1) begin
                if (task_state[i] == 2'd2) begin  // running
                    // Execute current instruction
                    reg [15:0] instr = instruction_rom[task_pc[i]];
                    reg [1:0] opcode = instr[1:0];
                    reg [5:0] operand = instr[7:0];

                    case (opcode)
                        2'd0: begin  // Compute
                            current_time <= current_time + 16'd1;
                            task_pc[i] <= task_pc[i] + 4'd1;
                        end
                        2'd1: begin  // Lock
                            if (resource_owner[operand] == 4'd31) begin
                                // Resource available
                                resource_owner[operand] <= i;
                                task_priority[i] <= resource_ceiling_val[operand];
                                task_pc[i] <= task_pc[i] + 4'd1;
                            end else begin
                                // Resource locked, block task
                                task_state[i] <= 2'd3;  // blocked
                            end
                        end
                        2'd2: begin  // Unlock
                            resource_owner[operand] <= 4'd31;
                            task_priority[i] <= task_base_priority[i];
                            task_pc[i] <= task_pc[i] + 4'd1;
                        end
                    endcase

                    // Check if task is done
                    if (task_pc[i] >= 4'd192 || instruction_rom[task_pc[i]] == 16'd0) begin
                        task_state[i] <= 2'd0;  // idle
                        // Add to output queue
                        output_queue_id[output_queue_tail] <= i;
                        output_queue_time[output_queue_tail] <= current_time;
                        output_queue_tail <= output_queue_tail + 5'd1;
                        if (output_queue_tail >= 5'd32) output_queue_tail <= 5'd0;
                        output_queue_count <= output_queue_count + 5'd1;
                    end
                end
            end

            // Step 2: Determine priorities and blocking
            // Find highest priority ready task
            max_priority = 5'd0;
            highest_priority_task = 4'd31;
            for (i = 0; i < 32; i = i + 1) begin
                if (task_state[i] == 2'd1 && task_priority[i] > max_priority) begin  // ready
                    max_priority = task_priority[i];
                    highest_priority_task = i;
                end
            end

            // If no running task and we have a ready task, make it run
            reg running_task_exists = 1'b0;
            for (i = 0; i < 32; i = i + 1) begin
                if (task_state[i] == 2'd2) running_task_exists = 1'b1;
            end

            if (!running_task_exists && highest_priority_task != 4'd31) begin
                task_state[highest_priority_task] <= 2'd2;  // running
            end

            // Step 3: Update task states based on time
            for (i = 0; i < 32; i = i + 1) begin
                if (task_state[i] == 2'd0 && current_time >= task_start_time[i]) begin
                    task_state[i] <= 2'd1;  // ready
                    task_priority[i] <= task_base_priority[i];
                end
            end
        end
    end

    // Output logic
    always @(posedge clk) begin
        if (state == OUTPUT && output_queue_count > 5'd0) begin
            result_valid <= 1'b1;
            task_done_id <= output_queue_id[output_queue_head];
            task_done_time <= output_queue_time[output_queue_head];
            output_queue_head <= output_queue_head + 5'd1;
            if (output_queue_head >= 5'd32) output_queue_head <= 5'd0;
            output_queue_count <= output_queue_count - 5'd1;
        end else begin
            result_valid <= 1'b0;
        end
    end

    // Initialize task states based on start times
    always @(posedge clk) begin
        if (state == SIMULATE && current_time == 16'd0) begin
            for (i = 0; i < 32; i = i + 1) begin
                if (task_start_time[i] == 16'd0) begin
                    task_state[i] <= 2'd1;  // ready
                    task_priority[i] <= task_base_priority[i];
                end
            end
        end
    end

endmodule