module goat_rope_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_posts,
    input [15:0] post_x [0:7],
    input [15:0] post_y [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT_PAIRS,
        COMPUTE_DIST,
        FIND_MIN,
        DIVIDE,
        ROUND,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [31:0] min_distance;
    reg [31:0] current_distance;
    reg [15:0] dx, dy;
    reg [31:0] dx2, dy2, sum;
    reg [31:0] sqrt_result;
    reg [3:0] i, j;
    reg [3:0] pair_count;
    reg [31:0] temp_result;

    // Square root computation registers
    reg [31:0] sqrt_val;
    reg [31:0] sqrt_temp;
    reg [4:0] sqrt_iter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            min_distance <= 32'hFFFFFFFF;
            i <= 0;
            j <= 0;
            pair_count <= 0;
            sqrt_iter <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_PAIRS;
            end
            INIT_PAIRS: begin
                if (i == num_posts - 1 && j == num_posts) begin
                    next_state = FIND_MIN;
                end
            end
            COMPUTE_DIST: begin
                if (sqrt_iter == 15) begin
                    next_state = FIND_MIN;
                end
            end
            FIND_MIN: begin
                if (i == num_posts - 1 && j == num_posts) begin
                    next_state = DIVIDE;
                end else begin
                    next_state = INIT_PAIRS;
                end
            end
            DIVIDE: next_state = ROUND;
            ROUND: next_state = DONE;
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
        end else begin
            case (state)
                INIT_PAIRS: begin
                    if (j == num_posts) begin
                        i <= i + 1;
                        j <= i + 1;
                    end else begin
                        j <= j + 1;
                    end
                    dx <= post_x[i] - post_x[j];
                    dy <= post_y[i] - post_y[j];
                    dx2 <= $signed(dx) * $signed(dx);
                    dy2 <= $signed(dy) * $signed(dy);
                    sum <= dx2 + dy2;
                    sqrt_val <= 32'h00000000;
                    sqrt_temp <= sum;
                    sqrt_iter <= 0;
                    next_state = COMPUTE_DIST;
                end
                COMPUTE_DIST: begin
                    // Simplified square root algorithm (shift-add)
                    if (sqrt_iter < 16) begin
                        sqrt_iter <= sqrt_iter + 1;
                        if (sqrt_temp >= (sqrt_val + 1'b1) << (31 - sqrt_iter)) begin
                            sqrt_temp <= sqrt_temp - ((sqrt_val + 1'b1) << (31 - sqrt_iter));
                            sqrt_val <= (sqrt_val >> 1) + (1 << (31 - sqrt_iter));
                        end else begin
                            sqrt_val <= sqrt_val >> 1;
                        end
                    end else begin
                        current_distance <= sqrt_val;
                        next_state = FIND_MIN;
                    end
                end
                FIND_MIN: begin
                    if (current_distance < min_distance) begin
                        min_distance <= current_distance;
                    end
                    if (i == num_posts - 1 && j == num_posts) begin
                        next_state = DIVIDE;
                    end
                end
                DIVIDE: begin
                    temp_result <= min_distance >> 1;
                    next_state = ROUND;
                end
                ROUND: begin
                    // Check bit 15 of fractional part for rounding
                    if (temp_result[15]) begin
                        result <= temp_result + 16'h0001;
                    end else begin
                        result <= temp_result;
                    end
                    done <= 1;
                    next_state = DONE;
                end
                DONE: begin
                    if (!start) begin
                        done <= 0;
                        i <= 0;
                        j <= 0;
                    end
                end
            endcase
        end
    end

endmodule