module julia_betting(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] julia_score,
    input [63:0] p_scores,
    output reg [7:0] k,
    output reg done
);

    typedef enum {
        IDLE,
        EXTRACT,
        SORT_P1,
        SORT_P2,
        SORT_P3,
        SORT_P4,
        SORT_P5,
        SORT_P6,
        COMPARE,
        CALCK_P0,
        CALCK_P1,
        CALCK_P2,
        CALCK_P3,
        CALCK_P4,
        CALCK_P5,
        CALCK_P6,
        DONE
    } state_t;

    reg [2:0] m;
    reg [7:0] opp_scores_raw [0:6];
    reg [7:0] sorted_scores [0:6];
    reg [10:0] sum_distances [0:6];
    state_t state;
    reg [7:0] total_k;
    integer i, j;
    reg [10:0] sum_temp;
    reg [7:0] temp;
    reg [10:0] sum_diff;
    reg [10:0] add_val;
    reg signed [10:0] julia_diff;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            k <= 0;
            total_k <= 0;
            for (i = 0; i < 7; i = i + 1) begin
                opp_scores_raw[i] <= 0;
                sorted_scores[i] <= 0;
                sum_distances[i] <= 0;
            end
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        m <= (n < 1) ? 0 : n - 1;
                        state <= EXTRACT;
                    end
                end

                EXTRACT: begin
                    for (i = 0; i < 7; i = i + 1) begin
                        opp_scores_raw[i] <= 0;
                        sorted_scores[i] <= 0;
                    end
                    for (i = 0; i < 7; i = i + 1) begin
                        if (i < m) begin
                            opp_scores_raw[i] <= p_scores >> (8 * (7 - i - 1));
                        end
                    end
                    for (i = 0; i < 7; i = i + 1) begin
                        sorted_scores[i] <= opp_scores_raw[i];
                    end
                    state <= SORT_P1;
                end

                SORT_P1, SORT_P2, SORT_P3, SORT_P4, SORT_P5, SORT_P6: begin
                    for (j = 0; j < 6; j = j + 1) begin
                        if (sorted_scores[j] < sorted_scores[j + 1]) begin
                            temp <= sorted_scores[j];
                            sorted_scores[j] <= sorted_scores[j + 1];
                            sorted_scores[j + 1] <= temp;
                        end
                    end
                    if (state == SORT_P6)
                        state <= COMPARE;
                    else
                        state <= state_t'(state + 1);
                end

                COMPARE: begin
                    for (i = 0; i < 7; i = i + 1) begin
                        sum_distances[i] <= 0;
                    end
                    for (i = 0; i < 7; i = i + 1) begin
                        sum_temp = 0;
                        if (i < m) begin
                            for (j = i + 1; j < m; j = j + 1) begin
                                sum_temp = sum_temp + (sorted_scores[i] - sorted_scores[j]);
                            end
                            sum_distances[i] <= sum_temp;
                        end
                    end
                    total_k <= 0;
                    state <= CALCK_P0;
                end

                CALCK_P0, CALCK_P1, CALCK_P2, CALCK_P3, CALCK_P4, CALCK_P5, CALCK_P6: begin
                    i = state - CALCK_P0;
                    if (i < m) begin
                        julia_diff = $signed({1'b0, julia_score}) - $signed({1'b0, sorted_scores[i]});
                        sum_diff = (i < 6) ? sum_distances[i + 1] : 0;
                        if (julia_diff <= $signed(sum_diff)) begin
                            add_val = ($signed(sum_diff) - julia_diff + 1) >>> 1;
                        end
                        else begin
                            add_val = julia_diff < 0 ? 0 : julia_diff[7:0];
                        end
                        total_k <= total_k + add_val[7:0];
                    end
                    if (state == CALCK_P6)
                        state <= DONE;
                    else
                        state <= state_t'(state + 1);
                end

                DONE: begin
                    k <= total_k;
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule