module dog_feeding_minimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] N,
    input wire [5:0] M,
    input wire [7:0] time_table [0:49][0:49],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [5:0] dog_idx;
    reg [5:0] bowl_idx;
    reg [5:0] current_dog;
    reg [5:0] current_bowl;
    reg [49:0] used_bowls;
    reg [15:0] current_max;
    reg [15:0] current_sum;
    reg [15:0] min_result;
    reg [7:0] current_time;
    reg [7:0] temp_time;
    reg [5:0] i, j;
    reg [5:0] temp_dog, temp_bowl;
    reg [15:0] temp_max, temp_sum;
    reg [49:0] temp_used;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            dog_idx <= 6'd0;
            bowl_idx <= 6'd0;
            current_dog <= 6'd0;
            current_bowl <= 6'd0;
            used_bowls <= 50'd0;
            current_max <= 16'd0;
            current_sum <= 16'd0;
            min_result <= 16'd9999;
            current_time <= 8'd0;
            temp_time <= 8'd0;
            i <= 6'd0;
            j <= 6'd0;
            temp_dog <= 6'd0;
            temp_bowl <= 6'd0;
            temp_max <= 16'd0;
            temp_sum <= 16'd0;
            temp_used <= 50'd0;
            cycle_count <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                if (dog_idx == N - 1) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (current_dog == N) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load initial values
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else if (state == LOAD) begin
            if (dog_idx < N) begin
                dog_idx <= dog_idx + 6'd1;
            end
        end
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else if (state == COMPUTE) begin
            cycle_count <= cycle_count + 16'd1;
            
            // Base case: all dogs assigned
            if (current_dog == N) begin
                // Calculate T = N * max_time - sum(assigned_times)
                temp_sum = current_sum;
                temp_max = current_max;
                
                // Update minimum result
                if (temp_sum < min_result) begin
                    min_result <= temp_sum;
                end
                
                // Backtrack
                current_dog <= current_dog - 6'd1;
                used_bowls <= used_bowls >> current_bowl;
                used_bowls[0] <= 1'b0;
                
                // Reset current_max and current_sum for backtracking
                current_max <= 16'd0;
                current_sum <= 16'd0;
                
                // Find next bowl for previous dog
                bowl_idx <= current_bowl + 6'd1;
            end
            // Recursive case: assign bowl to current dog
            else if (bowl_idx < M) begin
                if (!used_bowls[bowl_idx]) begin
                    // Assign this bowl to current dog
                    current_time <= time_table[current_dog][bowl_idx];
                    
                    // Update current_max and current_sum
                    if (current_time > current_max) begin
                        temp_max = current_time;
                    end else begin
                        temp_max = current_max;
                    end
                    
                    temp_sum = current_sum + current_time;
                    
                    // Move to next dog
                    current_dog <= current_dog + 6'd1;
                    used_bowls <= used_bowls << bowl_idx;
                    used_bowls[0] <= 1'b1;
                    current_max <= temp_max;
                    current_sum <= temp_sum;
                    bowl_idx <= 6'd0;
                end else begin
                    // Try next bowl
                    bowl_idx <= bowl_idx + 6'd1;
                end
            end
            // No more bowls for this dog, backtrack
            else begin
                current_dog <= current_dog - 6'd1;
                used_bowls <= used_bowls >> current_bowl;
                used_bowls[0] <= 1'b0;
                
                // Reset current_max and current_sum for backtracking
                current_max <= 16'd0;
                current_sum <= 16'd0;
                
                // Find next bowl for previous dog
                bowl_idx <= current_bowl + 6'd1;
            end
            
            // Safety check for cycle count
            if (cycle_count >= MAX_CYCLES) begin
                next_state = FINISH;
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 16'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= min_result;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Initialize current_bowl based on current_dog
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_bowl <= 6'd0;
        end else if (state == COMPUTE) begin
            if (current_dog != N) begin
                current_bowl <= bowl_idx;
            end
        end
    end

endmodule