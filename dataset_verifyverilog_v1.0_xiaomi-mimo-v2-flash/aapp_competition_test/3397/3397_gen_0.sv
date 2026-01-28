module feeding_assignment (
    input clk,
    input rst_n,
    input start,
    input [5:0] N,
    input [5:0] M,
    input [7:0] time_table [0:49][0:49],
    input [5:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD_TABLE    = 3'd1;
    localparam [2:0] GENERATE_PERM = 3'd2;
    localparam [2:0] EVALUATE      = 3'd3;
    localparam [2:0] UPDATE_MIN    = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Registers for tracking assignments
    reg [5:0] current_dog;
    reg [5:0] next_dog;
    reg [5:0] current_bowl;
    reg [5:0] next_bowl;
    reg [49:0] used_bowls;  // Bitmask for M <= 50
    reg [5:0] selected_bowl [0:49];  // Selected bowl for each dog
    reg [7:0] assigned_time [0:49];  // Time for each assignment

    // Computation registers
    reg [7:0] max_time;
    reg [15:0] current_T;
    reg [15:0] min_T;
    reg [7:0] sum_times;
    reg [5:0] assignment_index;
    reg [5:0] eval_dog;
    reg [5:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;  // Safety limit

    // FSM: Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && N > 6'd0 && M > 6'd0 && len > 6'd0) begin
                    next_state = LOAD_TABLE;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_TABLE: begin
                // Wait for external memory access
                next_state = GENERATE_PERM;
            end

            GENERATE_PERM: begin
                // Check if all dogs assigned
                if (current_dog >= N) begin
                    next_state = EVALUATE;
                end else begin
                    next_state = GENERATE_PERM;
                end
            end

            EVALUATE: begin
                // Evaluate current assignment
                if (eval_dog >= N) begin
                    next_state = UPDATE_MIN;
                end else begin
                    next_state = EVALUATE;
                end
            end

            UPDATE_MIN: begin
                // Update minimum T
                next_state = GENERATE_PERM;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // FSM: Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_dog <= 6'd0;
            current_bowl <= 6'd0;
            used_bowls <= 50'd0;
            min_T <= 16'hFFFF;
            cycle_count <= 8'd0;
            eval_dog <= 6'd0;
            assignment_index <= 6'd0;
            max_time <= 8'd0;
            current_T <= 16'd0;
            sum_times <= 8'd0;
            next_dog <= 6'd0;
            next_bowl <= 6'd0;
            
            // Initialize arrays
            begin : init_arrays
                integer i;
                for (i = 0; i < 50; i = i + 1) begin
                    selected_bowl[i] <= 6'd0;
                    assigned_time[i] <= 8'd0;
                end
            end

        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    min_T <= 16'hFFFF;
                    current_dog <= 6'd0;
                    used_bowls <= 50'd0;
                    eval_dog <= 6'd0;
                end

                LOAD_TABLE: begin
                    // External table loaded via time_table input
                    // No internal state needed for now
                end

                GENERATE_PERM: begin
                    // Generate next assignment using backtracking
                    if (current_dog < N && cycle_count < MAX_CYCLES) begin
                        // Find next available bowl for current dog
                        if (current_bowl < M) begin
                            if (!used_bowls[current_bowl]) begin
                                // Assign this bowl
                                selected_bowl[current_dog] <= current_bowl;
                                assigned_time[current_dog] <= time_table[current_dog][current_bowl];
                                used_bowls[current_bowl] <= 1'b1;
                                current_dog <= current_dog + 6'd1;
                                current_bowl <= 6'd0;  // Reset bowl counter for next dog
                            end else begin
                                current_bowl <= current_bowl + 6'd1;
                            end
                        end else begin
                            // No available bowl, backtrack
                            if (current_dog > 6'd0) begin
                                current_dog <= current_dog - 6'd1;
                                current_bowl <= selected_bowl[current_dog - 6'd1] + 6'd1;
                                used_bowls[selected_bowl[current_dog - 6'd1]] <= 1'b0;
                            end else begin
                                // No more assignments possible
                                state <= FINISH;
                            end
                        end
                    end
                end

                EVALUATE: begin
                    // Evaluate current assignment
                    if (eval_dog < N) begin
                        // Find max time
                        if (assigned_time[eval_dog] > max_time) begin
                            max_time <= assigned_time[eval_dog];
                        end
                        eval_dog <= eval_dog + 6'd1;
                    end
                end

                UPDATE_MIN: begin
                    // Compute T = sum(max_time - assigned_time)
                    current_T <= 16'd0;
                    // Calculate T in next cycle using comb logic
                    state <= GENERATE_PERM;
                    
                    // Update min_T
                    if (current_T < min_T) begin
                        min_T <= current_T;
                    end
                    
                    // Prepare for next assignment
                    if (current_dog > 6'd0) begin
                        current_dog <= current_dog - 6'd1;
                        current_bowl <= selected_bowl[current_dog - 6'd1] + 6'd1;
                        used_bowls[selected_bowl[current_dog - 6'd1]] <= 1'b0;
                        max_time <= 8'd0;
                        eval_dog <= 6'd0;
                    end
                end

                FINISH: begin
                    if (min_T != 16'hFFFF) begin
                        result <= min_T;
                    end else begin
                        result <= 16'd0;
                    end
                    done <= 1'b1;
                    cycle_count <= 8'd0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational logic for T calculation
    always @(*) begin
        integer i;
        current_T = 16'd0;
        for (i = 0; i < 50; i = i + 1) begin
            if (i < N) begin
                current_T = current_T + (max_time - assigned_time[i]);
            end
        end
    end

    // Completion logic
    always @(*) begin
        if (state == FINISH) begin
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule