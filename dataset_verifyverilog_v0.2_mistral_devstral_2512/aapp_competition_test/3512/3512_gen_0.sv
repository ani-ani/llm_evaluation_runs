module tsp_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] city_distance_0_1,
    input [2:0] city_distance_0_2,
    input [2:0] city_distance_0_3,
    input [2:0] city_distance_1_2,
    input [2:0] city_distance_1_3,
    input [2:0] city_distance_2_3,
    output reg [15:0] min_cost,
    output reg done
);

    // Internal distance matrix (4x4)
    reg [2:0] dist_matrix [0:3][0:3];
    
    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        CHECK_PERMUTATION,
        UPDATE_MIN,
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Permutation tracking
    reg [5:0] perm_counter; // 6 bits for 24 permutations
    reg [1:0] perm [0:3]; // 4 cities, each 2 bits (0-3)
    
    // Current cost calculation
    reg [15:0] current_cost;
    reg [1:0] current_city, next_city;
    reg [3:0] city_index;
    
    // Constraint check variables
    reg [3:0] k_index;
    reg [1:0] k_city;
    reg [1:0] left_cities [0:3];
    reg [1:0] right_cities [0:3];
    reg [3:0] left_count, right_count;
    reg [3:0] smaller_city;
    reg constraint_valid;
    
    // Initialize distance matrix
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dist_matrix[0][1] <= 0;
            dist_matrix[0][2] <= 0;
            dist_matrix[0][3] <= 0;
            dist_matrix[1][0] <= 0;
            dist_matrix[1][2] <= 0;
            dist_matrix[1][3] <= 0;
            dist_matrix[2][0] <= 0;
            dist_matrix[2][1] <= 0;
            dist_matrix[2][3] <= 0;
            dist_matrix[3][0] <= 0;
            dist_matrix[3][1] <= 0;
            dist_matrix[3][2] <= 0;
        end else begin
            dist_matrix[0][1] <= city_distance_0_1;
            dist_matrix[0][2] <= city_distance_0_2;
            dist_matrix[0][3] <= city_distance_0_3;
            dist_matrix[1][0] <= city_distance_0_1;
            dist_matrix[1][2] <= city_distance_1_2;
            dist_matrix[1][3] <= city_distance_1_3;
            dist_matrix[2][0] <= city_distance_0_2;
            dist_matrix[2][1] <= city_distance_1_2;
            dist_matrix[2][3] <= city_distance_2_3;
            dist_matrix[3][0] <= city_distance_0_3;
            dist_matrix[3][1] <= city_distance_1_3;
            dist_matrix[3][2] <= city_distance_2_3;
        end
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            min_cost <= 16'hFFFF;
            perm_counter <= 0;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
                next_state = CHECK_PERMUTATION;
            end
            CHECK_PERMUTATION: begin
                if (perm_counter == 23) next_state = DONE;
                else next_state = UPDATE_MIN;
            end
            UPDATE_MIN: begin
                next_state = CHECK_PERMUTATION;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Permutation generation and constraint check
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            perm_counter <= 0;
            constraint_valid <= 0;
            current_cost <= 0;
        end else if (current_state == INIT) begin
            perm_counter <= 0;
            min_cost <= 16'hFFFF;
            done <= 0;
        end else if (current_state == CHECK_PERMUTATION) begin
            // Generate permutation (simple increment with rejection)
            // For N=4, we can use a lookup table or simple counter
            // Here we use a counter and map to permutations
            case (perm_counter)
                0: begin perm[0] = 0; perm[1] = 1; perm[2] = 2; perm[3] = 3; end
                1: begin perm[0] = 0; perm[1] = 1; perm[2] = 3; perm[3] = 2; end
                2: begin perm[0] = 0; perm[1] = 2; perm[2] = 1; perm[3] = 3; end
                3: begin perm[0] = 0; perm[1] = 2; perm[2] = 3; perm[3] = 1; end
                4: begin perm[0] = 0; perm[1] = 3; perm[2] = 1; perm[3] = 2; end
                5: begin perm[0] = 0; perm[1] = 3; perm[2] = 2; perm[3] = 1; end
                6: begin perm[0] = 1; perm[1] = 0; perm[2] = 2; perm[3] = 3; end
                7: begin perm[0] = 1; perm[1] = 0; perm[2] = 3; perm[3] = 2; end
                8: begin perm[0] = 1; perm[1] = 2; perm[2] = 0; perm[3] = 3; end
                9: begin perm[0] = 1; perm[1] = 2; perm[2] = 3; perm[3] = 0; end
                10: begin perm[0] = 1; perm[1] = 3; perm[2] = 0; perm[3] = 2; end
                11: begin perm[0] = 1; perm[1] = 3; perm[2] = 2; perm[3] = 0; end
                12: begin perm[0] = 2; perm[1] = 0; perm[2] = 1; perm[3] = 3; end
                13: begin perm[0] = 2; perm[1] = 0; perm[2] = 3; perm[3] = 1; end
                14: begin perm[0] = 2; perm[1] = 1; perm[2] = 0; perm[3] = 3; end
                15: begin perm[0] = 2; perm[1] = 1; perm[2] = 3; perm[3] = 0; end
                16: begin perm[0] = 2; perm[1] = 3; perm[2] = 0; perm[3] = 1; end
                17: begin perm[0] = 2; perm[1] = 3; perm[2] = 1; perm[3] = 0; end
                18: begin perm[0] = 3; perm[1] = 0; perm[2] = 1; perm[3] = 2; end
                19: begin perm[0] = 3; perm[1] = 0; perm[2] = 2; perm[3] = 1; end
                20: begin perm[0] = 3; perm[1] = 1; perm[2] = 0; perm[3] = 2; end
                21: begin perm[0] = 3; perm[1] = 1; perm[2] = 2; perm[3] = 0; end
                22: begin perm[0] = 3; perm[1] = 2; perm[2] = 0; perm[3] = 1; end
                23: begin perm[0] = 3; perm[1] = 2; perm[2] = 1; perm[3] = 0; end
            endcase
            
            // Check constraint for K=2 (city 1 must be on one side)
            k_city = 2'd1; // K=2 (1-indexed)
            left_count = 0; right_count = 0;
            for (smaller_city = 0; smaller_city < k_city; smaller_city = smaller_city + 1) begin
                if (perm[0] == smaller_city || perm[1] == smaller_city) left_count = left_count + 1;
                if (perm[2] == smaller_city || perm[3] == smaller_city) right_count = right_count + 1;
            end
            constraint_valid = (left_count == k_city && right_count == 0) || (left_count == 0 && right_count == k_city);
            
            // Check constraint for K=3 (cities 1,2 must be on same side)
            if (constraint_valid) begin
                k_city = 2'd2; // K=3 (1-indexed)
                left_count = 0; right_count = 0;
                for (smaller_city = 0; smaller_city < k_city; smaller_city = smaller_city + 1) begin
                    if (perm[0] == smaller_city || perm[1] == smaller_city) left_count = left_count + 1;
                    if (perm[2] == smaller_city || perm[3] == smaller_city) right_count = right_count + 1;
                end
                constraint_valid = (left_count == k_city && right_count == 0) || (left_count == 0 && right_count == k_city);
            end
            
            // Calculate cost if valid
            if (constraint_valid) begin
                current_cost = 0;
                for (city_index = 0; city_index < 3; city_index = city_index + 1) begin
                    current_city = perm[city_index];
                    next_city = perm[city_index + 1];
                    current_cost = current_cost + dist_matrix[current_city][next_city];
                end
                // Add return to start (city 0)
                current_cost = current_cost + dist_matrix[perm[3]][perm[0]];
            end else begin
                current_cost = 16'hFFFF;
            end
        end else if (current_state == UPDATE_MIN) begin
            if (current_cost < min_cost) begin
                min_cost <= current_cost;
            end
            perm_counter <= perm_counter + 1;
        end else if (current_state == DONE) begin
            done <= 1;
        end
    end

endmodule