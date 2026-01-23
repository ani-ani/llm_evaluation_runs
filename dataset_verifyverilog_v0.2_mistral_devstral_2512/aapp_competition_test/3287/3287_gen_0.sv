module thieves_loot (
    input clk,
    input rst_n,
    input start,
    input [WIDTH-1:0] x0, x1, x2, x3,
    output reg [VALUE_WIDTH-1:0] result,
    output reg done
);

    parameter K = 4;
    parameter MAX_SUM = 240;
    parameter WIDTH = 8;
    parameter VALUE_WIDTH = 9;

    typedef enum logic [2:0] {
        IDLE,
        COMPUTE_TOTAL,
        INIT_DP,
        UPDATE_DP,
        FIND_MAX,
        DONE
    } state_t;

    state_t state, next_state;
    logic [VALUE_WIDTH-1:0] total;
    logic [VALUE_WIDTH-1:0] current_sum;
    logic [2:0] coin_type;
    logic [WIDTH-1:0] coin_count;
    logic [7:0] dp_bits [0:7]; // 8 registers of 32 bits = 256 bits
    logic [VALUE_WIDTH-1:0] max_even_sum;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total <= 0;
            current_sum <= 0;
            coin_type <= 0;
            coin_count <= 0;
            for (int i = 0; i < 8; i++) dp_bits[i] <= 0;
            max_even_sum <= 0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            case (state)
                COMPUTE_TOTAL: begin
                    total <= x0*1 + x1*2 + x2*4 + x3*8;
                    next_state <= INIT_DP;
                end
                INIT_DP: begin
                    dp_bits[0] <= 1; // dp[0] = 1
                    for (int i = 1; i < 8; i++) dp_bits[i] <= 0;
                    coin_type <= 0;
                    next_state <= UPDATE_DP;
                end
                UPDATE_DP: begin
                    if (coin_type == 0) begin
                        if (coin_count < x0) begin
                            coin_count <= coin_count + 1;
                            current_sum <= 1;
                        end else begin
                            coin_type <= 1;
                            coin_count <= 0;
                            current_sum <= 2;
                        end
                    end else if (coin_type == 1) begin
                        if (coin_count < x1) begin
                            coin_count <= coin_count + 1;
                            current_sum <= 2;
                        end else begin
                            coin_type <= 2;
                            coin_count <= 0;
                            current_sum <= 4;
                        end
                    end else if (coin_type == 2) begin
                        if (coin_count < x2) begin
                            coin_count <= coin_count + 1;
                            current_sum <= 4;
                        end else begin
                            coin_type <= 3;
                            coin_count <= 0;
                            current_sum <= 8;
                        end
                    end else if (coin_type == 3) begin
                        if (coin_count < x3) begin
                            coin_count <= coin_count + 1;
                            current_sum <= 8;
                        end else begin
                            next_state <= FIND_MAX;
                        end
                    end
                    if (state == UPDATE_DP && coin_type < 4) begin
                        for (int s = MAX_SUM; s >= current_sum; s--) begin
                            logic [7:0] byte_idx = s / 32;
                            logic [4:0] bit_idx = s % 32;
                            if (dp_bits[byte_idx][bit_idx]) begin
                                logic [7:0] next_byte_idx = (s - current_sum) / 32;
                                logic [4:0] next_bit_idx = (s - current_sum) % 32;
                                dp_bits[next_byte_idx][next_bit_idx] <= 1;
                            end
                        end
                    end
                end
                FIND_MAX: begin
                    max_even_sum <= 0;
                    for (int s = total; s >= 0; s--) begin
                        logic [7:0] byte_idx = s / 32;
                        logic [4:0] bit_idx = s % 32;
                        if (dp_bits[byte_idx][bit_idx] && (s % 2 == 0)) begin
                            max_even_sum <= s;
                            break;
                        end
                    end
                    next_state <= DONE;
                end
                DONE: begin
                    result <= total - max_even_sum;
                    done <= 1;
                    next_state <= IDLE;
                end
                default: begin
                    if (start) begin
                        next_state <= COMPUTE_TOTAL;
                        done <= 0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
            endcase
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = COMPUTE_TOTAL;
            default: next_state = state;
        endcase
    end

endmodule