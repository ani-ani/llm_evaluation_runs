module card_game_dp (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [4:0] k,
    input [4:0] d_init,
    input [4:0] g_init,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE_DP,
        FETCH_RESULT
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [4:0] d, g, r, dist;
    reg [4:0] current_max;
    reg [4:0] bet;
    reg [4:0] temp_d, temp_g;

    // Initialize state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_DP;
            end
            COMPUTE_DP: begin
                if (r == n || d == 0 || g == 0) next_state = FETCH_RESULT;
            end
            FETCH_RESULT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d <= 0;
            g <= 0;
            r <= 0;
            dist <= 0;
            current_max <= 0;
            bet <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        d <= d_init;
                        g <= g_init;
                        r <= 0;
                        dist <= k;
                        current_max <= 0;
                    end
                end
                COMPUTE_DP: begin
                    // Iterate through possible bets
                    bet <= bet + 1;
                    if (bet > d && bet > g) begin
                        bet <= 0;
                        r <= r + 1;
                        if (dist > 0) begin
                            // Distracted case
                            temp_d = d + 2 * bet;
                            temp_g = g - 2 * bet;
                            if (temp_d > current_max) current_max = temp_d;
                            dist <= dist - 1;
                        end else begin
                            // Not distracted case
                            temp_d = d - 2 * bet;
                            temp_g = g + 2 * bet;
                            if (temp_d > current_max) current_max = temp_d;
                        end
                    end
                end
                FETCH_RESULT: begin
                    result <= current_max;
                    done <= 1;
                end
                default: ;
            endcase
        end
    end

endmodule