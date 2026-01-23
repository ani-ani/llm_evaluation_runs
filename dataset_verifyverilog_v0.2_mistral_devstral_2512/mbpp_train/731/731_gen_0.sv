module cone_lsa (
    input clk,
    input rst_n,
    input start,
    input [15:0] r,
    input [15:0] h,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam PI_Q16_16 = 32'h0325A1; // 3.14159 * 65536 = 205887
    localparam SCALE_1000_TO_Q16_16 = 32'h00010400; // 65536 / 1000 = 65.536
    localparam MAX_ITERATIONS = 16;

    // States
    typedef enum logic [2:0] {
        IDLE,
        PREPARE,
        SQRT_LOOP,
        MULTIPLY,
        DONE
    } state_t;

    // State machine
    state_t current_state, next_state;

    // Intermediate registers
    reg [31:0] r_q16_16, h_q16_16;
    reg [31:0] r_squared, h_squared, sum_squared;
    reg [31:0] sqrt_val, sqrt_val_prev;
    reg [31:0] temp_mult;
    reg [31:0] iteration_count;

    // Convert input to Q16.16
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            iteration_count <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state <= PREPARE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PREPARE: begin
                    // Convert r and h to Q16.16
                    r_q16_16 <= $signed(r) * SCALE_1000_TO_Q16_16;
                    h_q16_16 <= $signed(h) * SCALE_1000_TO_Q16_16;

                    // Compute r² and h²
                    r_squared <= (r_q16_16 * r_q16_16) >>> 16;
                    h_squared <= (h_q16_16 * h_q16_16) >>> 16;
                    sum_squared <= r_squared + h_squared;

                    // Initialize sqrt_val
                    sqrt_val <= sum_squared >>> 1; // Initial guess
                    iteration_count <= 0;

                    next_state <= SQRT_LOOP;
                end

                SQRT_LOOP: begin
                    if (iteration_count < MAX_ITERATIONS) begin
                        // Newton-Raphson iteration: x_{n+1} = (x_n + S/x_n) / 2
                        sqrt_val_prev <= sqrt_val;
                        temp_mult <= (sum_squared <<< 16) / sqrt_val_prev;
                        sqrt_val <= (sqrt_val_prev + temp_mult) >>> 1;
                        iteration_count <= iteration_count + 1;
                        next_state <= SQRT_LOOP;
                    end else begin
                        next_state <= MULTIPLY;
                    end
                end

                MULTIPLY: begin
                    // Compute π * r * sqrt_val
                    temp_mult <= (PI_Q16_16 * r_q16_16) >>> 16;
                    result <= (temp_mult * sqrt_val) >>> 16;
                    next_state <= DONE;
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        done <= 0;
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule