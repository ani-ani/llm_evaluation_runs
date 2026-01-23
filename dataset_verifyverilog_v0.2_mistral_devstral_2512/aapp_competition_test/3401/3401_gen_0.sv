module aqueduct_solver (
    input clk,
    input rst_n,
    input start,
    input [11:0] hill_x [0:3],
    input [11:0] hill_y [0:3],
    input [11:0] hill_h [0:3],
    input [1:0] spring_idx [0:1],
    input [1:1] town_idx [0:1],
    input [15:0] q_max,
    output reg [31:0] min_length,
    output reg done,
    output reg valid
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PRECOMP,
        CALCULATE,
        DONE
    } state_t;

    state_t state;
    reg [31:0] dist_matrix [0:3][0:3];
    reg [31:0] current_sum;
    reg [31:0] min_length_reg;
    reg [1:0] perm_counter;
    reg [1:0] spring_assignment [0:1];
    reg [1:0] town_assignment [0:1];
    reg [31:0] dx, dy, dx_sq, dy_sq, dist_sq;
    reg [31:0] sqrt_val;
    reg [31:0] sqrt_iter;
    reg [31:0] sqrt_temp;
    reg [31:0] sqrt_prev;
    reg [31:0] sqrt_new;
    reg [31:0] sqrt_diff;
    reg [31:0] sqrt_tol;
    reg [31:0] sqrt_count;
    reg [31:0] sqrt_max_iter;
    reg [31:0] sqrt_input;
    reg [31:0] sqrt_output;
    reg [31:0] sqrt_done;
    reg [31:0] sqrt_start;
    reg [31:0] sqrt_clk;
    reg [31:0] sqrt_rst_n;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_length_reg <= 32'hFFFFFFFF;
            done <= 0;
            valid <= 0;
            perm_counter <= 0;
            current_sum <= 0;
            sqrt_done <= 0;
            sqrt_start <= 0;
            sqrt_clk <= 0;
            sqrt_rst_n <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PRECOMP;
                        done <= 0;
                        valid <= 0;
                        min_length_reg <= 32'hFFFFFFFF;
                        perm_counter <= 0;
                        current_sum <= 0;
                    end
                end
                PRECOMP: begin
                    // Calculate distance matrix
                    for (int i = 0; i < 4; i++) begin
                        for (int j = 0; j < 4; j++) begin
                            dx = hill_x[i] - hill_x[j];
                            dy = hill_y[i] - hill_y[j];
                            dx_sq = dx * dx;
                            dy_sq = dy * dy;
                            dist_sq = dx_sq + dy_sq;
                            dist_matrix[i][j] = dist_sq;
                        end
                    end
                    state <= CALCULATE;
                end
                CALCULATE: begin
                    // Iterate through permutations
                    if (perm_counter == 0) begin
                        spring_assignment[0] = spring_idx[0];
                        spring_assignment[1] = spring_idx[1];
                        town_assignment[0] = town_idx[0];
                        town_assignment[1] = town_idx[1];
                    end else if (perm_counter == 1) begin
                        spring_assignment[0] = spring_idx[1];
                        spring_assignment[1] = spring_idx[0];
                        town_assignment[0] = town_idx[1];
                        town_assignment[1] = town_idx[0];
                    end

                    // Check validity and calculate sum
                    if (hill_h[spring_assignment[0]] >= hill_h[town_assignment[0]] &&
                        hill_h[spring_assignment[1]] >= hill_h[town_assignment[1]] &&
                        dist_matrix[spring_assignment[0]][town_assignment[0]] <= (q_max * q_max) &&
                        dist_matrix[spring_assignment[1]][town_assignment[1]] <= (q_max * q_max)) begin
                        // Calculate sqrt for each distance
                        sqrt_input = dist_matrix[spring_assignment[0]][town_assignment[0]];
                        sqrt_start = 1;
                        sqrt_clk = clk;
                        sqrt_rst_n = rst_n;
                        while (!sqrt_done) begin
                            // Wait for sqrt to complete
                        end
                        current_sum = sqrt_output;

                        sqrt_input = dist_matrix[spring_assignment[1]][town_assignment[1]];
                        sqrt_start = 1;
                        while (!sqrt_done) begin
                            // Wait for sqrt to complete
                        end
                        current_sum = current_sum + sqrt_output;

                        if (current_sum < min_length_reg) begin
                            min_length_reg = current_sum;
                        end
                    end

                    perm_counter = perm_counter + 1;
                    if (perm_counter == 2) begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    done <= 1;
                    valid <= 1;
                    min_length <= min_length_reg;
                end
            endcase
        end
    end

    // Integer square root unit (Babylonian method)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sqrt_val <= 0;
            sqrt_iter <= 0;
            sqrt_temp <= 0;
            sqrt_prev <= 0;
            sqrt_new <= 0;
            sqrt_diff <= 0;
            sqrt_tol <= 0;
            sqrt_count <= 0;
            sqrt_max_iter <= 0;
            sqrt_input <= 0;
            sqrt_output <= 0;
            sqrt_done <= 0;
        end else if (sqrt_start) begin
            sqrt_val = sqrt_input;
            sqrt_iter = 0;
            sqrt_temp = sqrt_input;
            sqrt_prev = 0;
            sqrt_new = 0;
            sqrt_diff = 0;
            sqrt_tol = 1;
            sqrt_count = 0;
            sqrt_max_iter = 10;
            sqrt_done = 0;

            while (sqrt_iter < sqrt_max_iter && sqrt_diff > sqrt_tol) begin
                sqrt_prev = sqrt_val;
                sqrt_new = (sqrt_val + (sqrt_input / sqrt_val)) / 2;
                sqrt_diff = sqrt_prev - sqrt_new;
                sqrt_val = sqrt_new;
                sqrt_iter = sqrt_iter + 1;
            end

            sqrt_output = sqrt_val;
            sqrt_done = 1;
            sqrt_start = 0;
        end
    end

endmodule