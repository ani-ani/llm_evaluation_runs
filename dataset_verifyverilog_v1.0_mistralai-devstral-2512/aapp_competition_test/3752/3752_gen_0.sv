module cooking_time_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] k,
    input wire [63:0] d,
    input wire [63:0] t,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_P = 3'd1;
    localparam [2:0] COMPUTE_U = 3'd2;
    localparam [2:0] BINARY_SEARCH = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Constants
    localparam [63:0] SCALE = 64'd1 << 32;
    localparam [63:0] MAX_CYCLES = 64'd1000;

    // Internal registers
    reg [2:0] state, next_state;
    reg [63:0] P, U, T_low, T_high, T_mid, cooked, full_periods, remainder_time;
    reg [63:0] cycle_count;
    reg [63:0] temp_k, temp_d, temp_t;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            cycle_count <= 64'd0;
            P <= 64'd0;
            U <= 64'd0;
            T_low <= 64'd0;
            T_high <= 64'd0;
            T_mid <= 64'd0;
            cooked <= 64'd0;
            full_periods <= 64'd0;
            remainder_time <= 64'd0;
            temp_k <= 64'd0;
            temp_d <= 64'd0;
            temp_t <= 64'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 64'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= COMPUTE_P;
                        temp_k <= k;
                        temp_d <= d;
                        temp_t <= t;
                        cycle_count <= 64'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_P: begin
                    // Compute P = ceil(k/d) * d
                    if (temp_k % temp_d == 64'd0) begin
                        P <= temp_k;
                    end else begin
                        P <= ((temp_k + temp_d - 64'd1) / temp_d) * temp_d;
                    end
                    next_state <= COMPUTE_U;
                end

                COMPUTE_U: begin
                    // Compute U = k + (P - k) / 2
                    U <= temp_k + ((P - temp_k) >> 1);
                    // Initialize binary search bounds
                    T_low <= 64'd0;
                    T_high <= temp_t << 64'd1;  // Safe upper bound
                    next_state <= BINARY_SEARCH;
                end

                BINARY_SEARCH: begin
                    // Binary search for minimal T where cooked >= t
                    T_mid <= (T_low + T_high) >> 1;

                    // Compute cooked units for T_mid
                    full_periods <= T_mid / P;
                    remainder_time <= T_mid % P;

                    if (remainder_time <= temp_k) begin
                        cooked <= full_periods * U + remainder_time;
                    end else begin
                        cooked <= full_periods * U + temp_k + ((remainder_time - temp_k) >> 1);
                    end

                    // Check if cooked >= t
                    if (cooked >= temp_t) begin
                        T_high <= T_mid;
                    end else begin
                        T_low <= T_mid + 64'd1;
                    end

                    // Check termination condition
                    if ((T_high - T_low) <= 64'd1 || cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                        result <= T_high * SCALE;
                    end else begin
                        next_state <= BINARY_SEARCH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule