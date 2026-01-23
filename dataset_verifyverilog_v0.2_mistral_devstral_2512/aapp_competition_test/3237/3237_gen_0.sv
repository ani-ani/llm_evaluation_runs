module min_cost_calculator (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_factors,
    input [7:0] prime_factors [0:7],
    output reg [63:0] min_cost,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        ACCUMULATE_K,
        GENERATE_SUBSETS,
        CALCULATE_D,
        CALCULATE_N,
        CALCULATE_COST,
        UPDATE_MIN,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [63:0] K;
    reg [63:0] D;
    reg [63:0] N;
    reg [63:0] cost;
    reg [63:0] current_min;

    reg [7:0] subset_counter;
    reg [7:0] factor_index;
    reg [63:0] temp_product;

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            K <= 0;
            D <= 0;
            N <= 0;
            cost <= 0;
            current_min <= 0;
            subset_counter <= 0;
            factor_index <= 0;
            temp_product <= 0;
            min_cost <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = ACCUMULATE_K;
                end
            end
            ACCUMULATE_K: begin
                if (factor_index == num_factors) begin
                    next_state = GENERATE_SUBSETS;
                end
            end
            GENERATE_SUBSETS: begin
                if (subset_counter == (1 << num_factors) - 1) begin
                    next_state = DONE;
                end else begin
                    next_state = CALCULATE_D;
                end
            end
            CALCULATE_D: begin
                next_state = CALCULATE_N;
            end
            CALCULATE_N: begin
                next_state = CALCULATE_COST;
            end
            CALCULATE_COST: begin
                next_state = UPDATE_MIN;
            end
            UPDATE_MIN: begin
                next_state = GENERATE_SUBSETS;
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in initialization
        end else begin
            case (current_state)
                ACCUMULATE_K: begin
                    if (factor_index < num_factors) begin
                        if (factor_index == 0) begin
                            K <= prime_factors[factor_index];
                        end else begin
                            K <= K * prime_factors[factor_index];
                        end
                        factor_index <= factor_index + 1;
                    end
                end
                GENERATE_SUBSETS: begin
                    subset_counter <= subset_counter + 1;
                    factor_index <= 0;
                    temp_product <= 1;
                end
                CALCULATE_D: begin
                    if (factor_index < num_factors) begin
                        if (subset_counter[factor_index]) begin
                            temp_product <= temp_product * prime_factors[factor_index];
                        end
                        factor_index <= factor_index + 1;
                    end else begin
                        D <= temp_product;
                    end
                end
                CALCULATE_N: begin
                    N <= K / D;
                end
                CALCULATE_COST: begin
                    cost <= D + N;
                end
                UPDATE_MIN: begin
                    if (current_min == 0 || cost < current_min) begin
                        current_min <= cost;
                    end
                end
                DONE: begin
                    min_cost <= current_min;
                    done <= 1;
                end
            endcase
        end
    end

endmodule