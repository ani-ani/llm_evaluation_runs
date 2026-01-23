module digit_sum_pairs_counter (
    input clk,
    input rst_n,
    input start,
    input [31:0] S,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam MAX_N = 9;
    localparam MAX_K = 128;
    localparam MAX_D = 128;

    // States
    typedef enum logic [3:0] {
        IDLE,
        CALCULATE_LOOP_1,
        CALCULATE_LOOP_2,
        CALCULATE_LOOP_3,
        FINALIZE
    } state_t;

    // State machine
    state_t state;
    reg [31:0] n, k, d;
    reg [31:0] k_max, k_min, n_max, n_min;
    reg [31:0] S_int;
    reg [31:0] temp_count;
    reg [31:0] total_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            n <= 0;
            k <= 0;
            d <= 0;
            total_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALCULATE_LOOP_1;
                        n <= 1;
                        S_int <= S >> 16;
                        total_count <= 0;
                    end
                end

                CALCULATE_LOOP_1: begin
                    if (n <= MAX_N) begin
                        // Calculate k_max and k_min
                        k_max <= (S_int + n - 1) / n;
                        k_min <= (S_int - n * (n - 1) / 2) / n;

                        if (k_max >= k_min) begin
                            temp_count <= k_max - k_min + 1;
                            total_count <= (total_count + temp_count) % MOD;
                        end

                        n <= n + 1;
                    end else begin
                        state <= CALCULATE_LOOP_2;
                        k <= 9;
                    end
                end

                CALCULATE_LOOP_2: begin
                    if (k <= MAX_K) begin
                        // Calculate n_max and n_min
                        n_max <= (S_int + k - 1) / k;
                        n_min <= (S_int - k * (k - 1) / 2) / k;

                        if (n_max >= n_min) begin
                            temp_count <= n_max - n_min + 1;
                            total_count <= (total_count + temp_count) % MOD;
                        end

                        k <= k + 1;
                    end else begin
                        state <= CALCULATE_LOOP_3;
                        d <= 1;
                    end
                end

                CALCULATE_LOOP_3: begin
                    if (d <= MAX_D) begin
                        if (S_int % d == 0) begin
                            // Calculate count for this divisor
                            temp_count <= (S_int / d) - (d * (d - 1) / 2);
                            if (temp_count > 0) begin
                                total_count <= (total_count + temp_count) % MOD;
                            end
                        end

                        d <= d + 1;
                    end else begin
                        state <= FINALIZE;
                    end
                end

                FINALIZE: begin
                    result <= total_count % MOD;
                    done <= 1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule