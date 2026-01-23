module max_payout_calculator (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_cards,
    input signed [15:0] card_values [0:15],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CALCULATE_PREFIX,
        CALCULATE_SUFFIX,
        FIND_BEST_PAIR,
        COMPUTE_RESULT,
        DONE
    } state_t;

    state_t state;

    // Intermediate registers
    reg signed [31:0] prefix_sum;
    reg [3:0] prefix_count;
    reg signed [31:0] best_prefix_sum;
    reg [3:0] best_prefix_count;

    reg signed [31:0] suffix_sum;
    reg [3:0] suffix_count;
    reg signed [31:0] best_suffix_sum;
    reg [3:0] best_suffix_count;

    reg [3:0] i;
    reg [3:0] j;

    reg signed [31:0] best_pair_sum;
    reg [3:0] best_pair_count;

    // Fixed-point division function
    function signed [31:0] fixed_div(signed [31:0] numerator, input [3:0] denominator);
        if (denominator == 0) begin
            fixed_div = 0;
        end else begin
            fixed_div = (numerator << 16) / denominator;
        end
    endfunction

    // Reset all intermediate registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            prefix_sum <= 0;
            prefix_count <= 0;
            best_prefix_sum <= 0;
            best_prefix_count <= 0;
            suffix_sum <= 0;
            suffix_count <= 0;
            best_suffix_sum <= 0;
            best_suffix_count <= 0;
            i <= 0;
            j <= 0;
            best_pair_sum <= 0;
            best_pair_count <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALCULATE_PREFIX;
                        prefix_sum <= 0;
                        prefix_count <= 0;
                        best_prefix_sum <= 0;
                        best_prefix_count <= 0;
                        i <= 0;
                    end
                end
                CALCULATE_PREFIX: begin
                    if (i < num_cards) begin
                        prefix_sum <= prefix_sum + card_values[i];
                        prefix_count <= prefix_count + 1;
                        if (prefix_count > 0) begin
                            if (fixed_div(prefix_sum, prefix_count) > fixed_div(best_prefix_sum, best_prefix_count)) begin
                                best_prefix_sum <= prefix_sum;
                                best_prefix_count <= prefix_count;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        state <= CALCULATE_SUFFIX;
                        suffix_sum <= 0;
                        suffix_count <= 0;
                        best_suffix_sum <= 0;
                        best_suffix_count <= 0;
                        j <= num_cards - 1;
                    end
                end
                CALCULATE_SUFFIX: begin
                    if (j >= 0) begin
                        suffix_sum <= suffix_sum + card_values[j];
                        suffix_count <= suffix_count + 1;
                        if (suffix_count > 0) begin
                            if (fixed_div(suffix_sum, suffix_count) > fixed_div(best_suffix_sum, best_suffix_count)) begin
                                best_suffix_sum <= suffix_sum;
                                best_suffix_count <= suffix_count;
                            end
                        end
                        j <= j - 1;
                    end else begin
                        state <= FIND_BEST_PAIR;
                        i <= 0;
                        j <= num_cards - 1;
                        best_pair_sum <= 0;
                        best_pair_count <= 0;
                    end
                end
                FIND_BEST_PAIR: begin
                    if (i < j) begin
                        if (fixed_div(prefix_sum, prefix_count) + fixed_div(suffix_sum, suffix_count) > fixed_div(best_pair_sum, best_pair_count)) begin
                            best_pair_sum <= prefix_sum + suffix_sum;
                            best_pair_count <= prefix_count + suffix_count;
                        end
                        i <= i + 1;
                        j <= j - 1;
                    end else begin
                        state <= COMPUTE_RESULT;
                    end
                end
                COMPUTE_RESULT: begin
                    reg signed [31:0] prefix_avg = fixed_div(best_prefix_sum, best_prefix_count);
                    reg signed [31:0] suffix_avg = fixed_div(best_suffix_sum, best_suffix_count);
                    reg signed [31:0] pair_avg = fixed_div(best_pair_sum, best_pair_count);
                    reg signed [31:0] max_avg = 0;

                    if (prefix_avg > max_avg) max_avg = prefix_avg;
                    if (suffix_avg > max_avg) max_avg = suffix_avg;
                    if (pair_avg > max_avg) max_avg = pair_avg;

                    result <= max_avg;
                    state <= DONE;
                end
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule