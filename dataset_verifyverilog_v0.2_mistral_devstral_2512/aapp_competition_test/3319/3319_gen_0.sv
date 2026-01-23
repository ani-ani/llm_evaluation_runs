module planetoid_collision (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_planetoids,
    input [7:0] mass_in [0:3],
    input [7:0] pos_x_in [0:3],
    input [7:0] pos_y_in [0:3],
    input signed [7:0] vel_x_in [0:3],
    input signed [7:0] vel_y_in [0:3],
    output reg [2:0] result_count,
    output reg [7:0] result_mass [0:3],
    output reg [7:0] result_pos_x [0:3],
    output reg [7:0] result_pos_y [0:3],
    output reg signed [7:0] result_vel_x [0:3],
    output reg signed [7:0] result_vel_y [0:3],
    output reg done,
    output reg [7:0] final_time
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK,
        COLLIDE,
        SORT,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [7:0] mass [0:3];
    reg [7:0] pos_x [0:3];
    reg [7:0] pos_y [0:3];
    reg signed [7:0] vel_x [0:3];
    reg signed [7:0] vel_y [0:3];
    reg [7:0] time;
    reg [2:0] active_count;
    reg [1:0] collision_pair;
    reg collision_detected;

    // Temporary registers for collision resolution
    reg [7:0] new_mass;
    reg [7:0] new_pos_x, new_pos_y;
    reg signed [7:0] new_vel_x, new_vel_y;
    reg [1:0] colliding_indices [0:1];

    // Sorting registers
    reg [7:0] sort_mass [0:3];
    reg [7:0] sort_pos_x [0:3];
    reg [7:0] sort_pos_y [0:3];
    reg signed [7:0] sort_vel_x [0:3];
    reg signed [7:0] sort_vel_y [0:3];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            time <= 0;
            active_count <= 0;
            collision_detected <= 0;
            for (int i = 0; i < 4; i++) begin
                mass[i] <= 0;
                pos_x[i] <= 0;
                pos_y[i] <= 0;
                vel_x[i] <= 0;
                vel_y[i] <= 0;
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
                if (start) begin
                    next_state = CHECK;
                end
            end
            CHECK: begin
                if (collision_detected) begin
                    next_state = COLLIDE;
                end else if (time >= 15) begin
                    next_state = SORT;
                end
            end
            COLLIDE: begin
                next_state = CHECK;
            end
            SORT: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (state == IDLE && start) begin
            active_count <= num_planetoids;
            for (int i = 0; i < 4; i++) begin
                if (i < num_planetoids) begin
                    mass[i] <= mass_in[i];
                    pos_x[i] <= pos_x_in[i];
                    pos_y[i] <= pos_y_in[i];
                    vel_x[i] <= vel_x_in[i];
                    vel_y[i] <= vel_y_in[i];
                end else begin
                    mass[i] <= 0;
                    pos_x[i] <= 0;
                    pos_y[i] <= 0;
                    vel_x[i] <= 0;
                    vel_y[i] <= 0;
                end
            end
            time <= 0;
            done <= 0;
        end
    end

    // Collision detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            collision_detected <= 0;
        end else if (state == CHECK) begin
            collision_detected <= 0;
            for (int i = 0; i < 4; i++) begin
                for (int j = i+1; j < 4; j++) begin
                    if (mass[i] && mass[j]) begin
                        reg [7:0] next_x_i = (pos_x[i] + vel_x[i]) & 8'h07;
                        reg [7:0] next_y_i = (pos_y[i] + vel_y[i]) & 8'h07;
                        reg [7:0] next_x_j = (pos_x[j] + vel_x[j]) & 8'h07;
                        reg [7:0] next_y_j = (pos_y[j] + vel_y[j]) & 8'h07;
                        if (next_x_i == next_x_j && next_y_i == next_y_j) begin
                            collision_detected <= 1;
                            colliding_indices[0] <= i;
                            colliding_indices[1] <= j;
                        end
                    end
                end
            end
        end
    end

    // Collision resolution
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled elsewhere
        end else if (state == COLLIDE) begin
            // Calculate new properties
            new_mass <= mass[colliding_indices[0]] + mass[colliding_indices[1]];
            new_pos_x <= (pos_x[colliding_indices[0]] + vel_x[colliding_indices[0]]) & 8'h07;
            new_pos_y <= (pos_y[colliding_indices[0]] + vel_y[colliding_indices[0]]) & 8'h07;
            new_vel_x <= ($signed(mass[colliding_indices[0]]) * vel_x[colliding_indices[0]] + 
                          $signed(mass[colliding_indices[1]]) * vel_x[colliding_indices[1]]) / 
                          (mass[colliding_indices[0]] + mass[colliding_indices[1]]);
            new_vel_y <= ($signed(mass[colliding_indices[0]]) * vel_y[colliding_indices[0]] + 
                          $signed(mass[colliding_indices[1]]) * vel_y[colliding_indices[1]]) / 
                          (mass[colliding_indices[0]] + mass[colliding_indices[1]]);

            // Update the first colliding planetoid
            mass[colliding_indices[0]] <= new_mass;
            pos_x[colliding_indices[0]] <= new_pos_x;
            pos_y[colliding_indices[0]] <= new_pos_y;
            vel_x[colliding_indices[0]] <= new_vel_x;
            vel_y[colliding_indices[0]] <= new_vel_y;

            // Remove the second colliding planetoid
            mass[colliding_indices[1]] <= 0;
            pos_x[colliding_indices[1]] <= 0;
            pos_y[colliding_indices[1]] <= 0;
            vel_x[colliding_indices[1]] <= 0;
            vel_y[colliding_indices[1]] <= 0;

            // Update active count
            active_count <= active_count - 1;
            time <= time + 1;
        end
    end

    // Update positions when no collision
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled elsewhere
        end else if (state == CHECK && !collision_detected) begin
            for (int i = 0; i < 4; i++) begin
                if (mass[i]) begin
                    pos_x[i] <= (pos_x[i] + vel_x[i]) & 8'h07;
                    pos_y[i] <= (pos_y[i] + vel_y[i]) & 8'h07;
                end
            end
            time <= time + 1;
        end
    end

    // Sorting
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled elsewhere
        end else if (state == SORT) begin
            // Copy current state to sort registers
            for (int i = 0; i < 4; i++) begin
                sort_mass[i] <= mass[i];
                sort_pos_x[i] <= pos_x[i];
                sort_pos_y[i] <= pos_y[i];
                sort_vel_x[i] <= vel_x[i];
                sort_vel_y[i] <= vel_y[i];
            end

            // Bubble sort by mass (descending), then position (ascending)
            for (int i = 0; i < 3; i++) begin
                for (int j = 0; j < 3 - i; j++) begin
                    if (sort_mass[j] < sort_mass[j+1] ||
                        (sort_mass[j] == sort_mass[j+1] && 
                         (sort_pos_x[j] > sort_pos_x[j+1] ||
                          (sort_pos_x[j] == sort_pos_x[j+1] && sort_pos_y[j] > sort_pos_y[j+1])))) begin
                        // Swap
                        reg [7:0] temp_mass = sort_mass[j];
                        reg [7:0] temp_pos_x = sort_pos_x[j];
                        reg [7:0] temp_pos_y = sort_pos_y[j];
                        reg signed [7:0] temp_vel_x = sort_vel_x[j];
                        reg signed [7:0] temp_vel_y = sort_vel_y[j];

                        sort_mass[j] <= sort_mass[j+1];
                        sort_pos_x[j] <= sort_pos_x[j+1];
                        sort_pos_y[j] <= sort_pos_y[j+1];
                        sort_vel_x[j] <= sort_vel_x[j+1];
                        sort_vel_y[j] <= sort_vel_y[j+1];

                        sort_mass[j+1] <= temp_mass;
                        sort_pos_x[j+1] <= temp_pos_x;
                        sort_pos_y[j+1] <= temp_pos_y;
                        sort_vel_x[j+1] <= temp_vel_x;
                        sort_vel_y[j+1] <= temp_vel_y;
                    end
                end
            end

            // Copy sorted results to outputs
            result_count <= active_count;
            for (int i = 0; i < 4; i++) begin
                result_mass[i] <= sort_mass[i];
                result_pos_x[i] <= sort_pos_x[i];
                result_pos_y[i] <= sort_pos_y[i];
                result_vel_x[i] <= sort_vel_x[i];
                result_vel_y[i] <= sort_vel_y[i];
            end
            final_time <= time;
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (state == DONE) begin
            done <= 1;
        end else if (state == IDLE) begin
            done <= 0;
        end
    end

endmodule