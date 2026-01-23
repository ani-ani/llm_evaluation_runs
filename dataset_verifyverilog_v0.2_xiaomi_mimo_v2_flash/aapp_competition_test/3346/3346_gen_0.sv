module traffic_scheduler (
    input clk,
    input rst_n,
    input start,
    input [7:0] car_idx,
    input car_dir,
    input [15:0] car_arrival,
    input [15:0] car_irritation,
    output reg [3:0] result_min_irritated,
    output reg done
);

    // Parameters
    parameter t_pass = 16'd8;
    parameter t_gap = 16'd3;
    parameter MAX_CARS = 8;

    // Memory for car data (8 cars)
    reg [15:0] car_arrival_mem [0:7];
    reg [15:0] car_irritation_mem [0:7];
    reg car_dir_mem [0:7];
    reg [2:0] load_ptr;

    // FSM States
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam CALCULATING = 3'b011;
    localparam DONE_STATE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Scheduling variables
    reg [15:0] current_time;
    reg current_dir;
    reg [3:0] irritated_count;
    reg [3:0] best_irritated;
    reg [2:0] car_ptr; // Processing pointer 0-7
    reg [7:0] direction_switches; // 8-bit mask for direction decisions
    reg [6:0] iteration_counter; // 0-127 (128 iterations total, tracked via counter)
    reg [6:0] max_iterations; // 128

    // Load state machine
    reg [2:0] load_state;
    reg [2:0] next_load_state;
    localparam LOAD_IDLE = 3'b0;
    localparam LOAD_WAIT = 3'b1;
    localparam LOAD_ACTIVE = 3'b10;
    localparam LOAD_DONE = 3'b11;

    integer i;

    // Control signals
    reg rst_vars;
    reg inc_iter;
    reg inc_car;
    reg calc_better;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD;
            LOAD: if (load_state == LOAD_DONE) next_state = PROCESSING;
            PROCESSING: begin
                // 128 iterations (0 to 127) and 8 cars (0 to 7)
                // We iterate 128 times total. Inside each iteration, we process all 8 cars.
                if (iteration_counter >= 128) next_state = CALCULATING;
                else next_state = PROCESSING; 
            end
            CALCULATING: next_state = DONE_STATE;
            DONE_STATE: if (start) next_state = LOAD; // Restart if start again
            default: next_state = IDLE;
        endcase
    end

    // Load FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_state <= LOAD_IDLE;
            load_ptr <= 0;
        end else begin
            load_state <= next_load_state;
            if (state == IDLE) load_ptr <= 0;
            else if (next_load_state == LOAD_ACTIVE && load_state == LOAD_WAIT) begin
                if (load_ptr < 7) load_ptr <= load_ptr + 1;
            end
        end
    end

    always @(*) begin
        next_load_state = load_state;
        case (load_state)
            LOAD_IDLE: if (state == LOAD) next_load_state = LOAD_WAIT;
            LOAD_WAIT: if (start) next_load_state = LOAD_ACTIVE; // Wait for valid input cycle
            LOAD_ACTIVE: begin
                if (load_ptr == 7 && car_idx == 7) next_load_state = LOAD_DONE;
                else next_load_state = LOAD_WAIT;
            end
            LOAD_DONE: if (state != LOAD) next_load_state = LOAD_IDLE;
            default: next_load_state = LOAD_IDLE;
        endcase
    end

    // Data Loading
    always @(posedge clk) begin
        if (state == LOAD && load_state == LOAD_ACTIVE && load_ptr == car_idx) begin
            car_arrival_mem[car_idx] <= car_arrival;
            car_irritation_mem[car_idx] <= car_irritation;
            car_dir_mem[car_idx] <= car_dir;
        end
    end

    // Processing Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iteration_counter <= 0;
            car_ptr <= 0;
            best_irritated <= 4'd8; // Max possible
            current_time <= 0;
            current_dir <= 0;
            irritated_count <= 0;
            done <= 0;
            result_min_irritated <= 0;
        end else begin
            case (state)
                IDLE, LOAD: begin
                    done <= 0;
                end
                PROCESSING: begin
                    // Processing Loop Logic
                    // We expand the loop into sequential logic.
                    // We need a counter for the 128 iterations.
                    if (car_ptr == 0 && iteration_counter < 128) begin
                        // Reset counters for new iteration (iteration_counter changed in previous cycle end or logic below)
                        // Logic flow: At start of iteration (car_ptr==0), we reset local stats.
                        // But iteration_counter is incremented at end of car_ptr 7.
                    end
                    if (iteration_counter < 128) begin
                        // Check irritation for current car
                        // Determine time
                        // Update vars
                        // Move to next car
                        if (car_ptr == 0) begin
                            // Start of new iteration (mask)
                            current_time <= 16'd0;
                            irritated_count <= 4'd0;
                            // For car 0, we align with car 0 direction. No switch cost.
                            current_dir <= car_dir_mem[0];
                            // Step 1: Wait for arrival
                            if (current_time < car_arrival_mem[0]) begin
                                current_time <= car_arrival_mem[0];
                            end
                            // Step 3: Check irritation (Arrival - Limit)
                            if (current_time > car_arrival_mem[0]) begin
                                if ( (current_time - car_arrival_mem[0]) > car_irritation_mem[0] ) begin
                                    irritated_count <= 1;
                                end
                            end
                            // Step 4: Gap
                            current_time <= current_time + t_gap;
                            // Step 5: Switch decision (Mask bit 0)
                            if (iteration_counter[0]) begin
                                current_dir <= !current_dir;
                            end
                        end else if (car_ptr > 0) begin
                            // Carry forward
                            current_time <= current_time;
                            current_dir <= current_dir;
                            irritated_count <= irritated_count;
                            // Step 1: Switch if needed
                            if (current_dir != car_dir_mem[car_ptr]) begin
                                current_time <= current_time + t_pass;
                                current_dir <= car_dir_mem[car_ptr];
                            end
                            // Step 2: Wait for arrival
                            if (current_time < car_arrival_mem[car_ptr]) begin
                                current_time <= car_arrival_mem[car_ptr];
                            end
                            // Step 3: Check irritation
                            if (current_time > car_arrival_mem[car_ptr]) begin
                                if ( (current_time - car_arrival_mem[car_ptr]) > car_irritation_mem[car_ptr] ) begin
                                    irritated_count <= irritated_count + 1;
                                end
                            end
                            // Step 4: Gap
                            current_time <= current_time + t_gap;
                            // Step 5: Switch decision (Mask bit car_ptr)
                            if (iteration_counter[car_ptr]) begin
                                current_dir <= !current_dir;
                            end
                        end
                        // Move to next car
                        if (car_ptr < 7) begin
                            car_ptr <= car_ptr + 1;
                        end else begin
                            // Finished 8 cars for this iteration
                            car_ptr <= 0;
                            // Update Best Irritated Check
                            if (iteration_counter < 128) begin
                                if (irritated_count < best_irritated) begin
                                    best_irritated <= irritated_count;
                                end
                                iteration_counter <= iteration_counter + 1;
                            end
                        end
                    end
                end
                CALCULATING: begin
                    done <= 1;
                    result_min_irritated <= best_irritated;
                end
                DONE_STATE: begin
                    if (start) begin // Keep result until next start
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule