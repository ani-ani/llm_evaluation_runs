module bandwidth_allocator (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_species,
    input [31:0] total_bandwidth,
    input [7:0][31:0] a_min,
    input [7:0][31:0] b_max,
    input [7:0][31:0] demand,
    output reg [7:0][31:0] x_alloc,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CALC_SUM,
        CALC_FAIR,
        CLASSIFY,
        ALLOCATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Intermediate registers
    reg [31:0] sum_demand;
    reg [31:0] sum_in_range_demands;
    reg [31:0] remaining_bandwidth;
    reg [31:0] fair_share [0:7];
    reg [1:0] classification [0:7]; // 0: below_min, 1: at_min, 2: in_range, 3: at_max, 4: above_max
    reg [31:0] temp_sum;
    reg [31:0] temp_value;
    reg [31:0] temp_dividend;
    reg [31:0] temp_divisor;
    reg [31:0] temp_quotient;
    reg [31:0] temp_remainder;
    reg [31:0] temp_result;
    reg [31:0] temp_demand;
    reg [31:0] temp_a_min;
    reg [31:0] temp_b_max;
    reg [31:0] temp_x_alloc;
    reg [31:0] temp_fair_share;
    reg [31:0] temp_remaining;
    reg [31:0] temp_sum_in_range;
    reg [31:0] temp_proportional;
    reg [31:0] temp_product;
    reg [31:0] temp_shifted;
    reg [31:0] temp_remaining_shifted;
    reg [31:0] temp_demand_shifted;
    reg [31:0] temp_sum_in_range_shifted;
    reg [31:0] temp_proportional_shifted;
    reg [31:0] temp_proportional_final;
    reg [31:0] temp_x_alloc_final;

    integer i, j, k;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            sum_demand <= 0;
            sum_in_range_demands <= 0;
            remaining_bandwidth <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                fair_share[i] <= 0;
                classification[i] <= 0;
                x_alloc[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = CALC_SUM;
            end
            CALC_SUM: begin
                next_state = CALC_FAIR;
            end
            CALC_FAIR: begin
                next_state = CLASSIFY;
            end
            CLASSIFY: begin
                next_state = ALLOCATE;
            end
            ALLOCATE: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all intermediate registers
            sum_demand <= 0;
            sum_in_range_demands <= 0;
            remaining_bandwidth <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                fair_share[i] <= 0;
                classification[i] <= 0;
                x_alloc[i] <= 0;
            end
        end else begin
            case (current_state)
                CALC_SUM: begin
                    // Compute sum of all demand values
                    temp_sum = 0;
                    for (i = 0; i < num_species; i = i + 1) begin
                        temp_sum = temp_sum + demand[i];
                    end
                    sum_demand <= temp_sum;
                end
                CALC_FAIR: begin
                    // Compute fair share y_i for each species
                    for (i = 0; i < num_species; i = i + 1) begin
                        if (sum_demand != 0) begin
                            // y_i = t * d_i / sum(d_j) in Q16.16
                            // (t * d_i) << 16 / sum_demand
                            temp_product = total_bandwidth * demand[i];
                            temp_shifted = temp_product << 16;
                            temp_dividend = temp_shifted;
                            temp_divisor = sum_demand;
                            temp_quotient = 0;
                            temp_remainder = 0;
                            // Iterative subtraction for division
                            for (j = 0; j < 32; j = j + 1) begin
                                temp_remainder = {temp_remainder[30:0], temp_dividend[31]};
                                temp_dividend = temp_dividend << 1;
                                if (temp_remainder >= temp_divisor) begin
                                    temp_remainder = temp_remainder - temp_divisor;
                                    temp_quotient[j] = 1;
                                end
                            end
                            fair_share[i] <= temp_quotient;
                        end else begin
                            fair_share[i] <= 0;
                        end
                    end
                end
                CLASSIFY: begin
                    // Classify each species
                    for (i = 0; i < num_species; i = i + 1) begin
                        if (fair_share[i] < a_min[i]) begin
                            classification[i] = 0; // below_min
                        end else if (fair_share[i] == a_min[i]) begin
                            classification[i] = 1; // at_min
                        end else if (fair_share[i] > b_max[i]) begin
                            classification[i] = 4; // above_max
                        end else if (fair_share[i] == b_max[i]) begin
                            classification[i] = 3; // at_max
                        end else begin
                            classification[i] = 2; // in_range
                        end
                    end
                end
                ALLOCATE: begin
                    // First set boundary values
                    temp_sum = 0;
                    temp_sum_in_range = 0;
                    for (i = 0; i < num_species; i = i + 1) begin
                        case (classification[i])
                            0: begin // below_min
                                x_alloc[i] = a_min[i];
                                temp_sum = temp_sum + a_min[i];
                            end
                            1: begin // at_min
                                x_alloc[i] = a_min[i];
                                temp_sum = temp_sum + a_min[i];
                            end
                            2: begin // in_range
                                x_alloc[i] = a_min[i];
                                temp_sum = temp_sum + a_min[i];
                                temp_sum_in_range = temp_sum_in_range + demand[i];
                            end
                            3: begin // at_max
                                x_alloc[i] = b_max[i];
                                temp_sum = temp_sum + b_max[i];
                            end
                            4: begin // above_max
                                x_alloc[i] = b_max[i];
                                temp_sum = temp_sum + b_max[i];
                            end
                        endcase
                    end
                    sum_in_range_demands <= temp_sum_in_range;
                    // Calculate remaining bandwidth
                    if (total_bandwidth > temp_sum) begin
                        remaining_bandwidth <= total_bandwidth - temp_sum;
                    end else begin
                        remaining_bandwidth <= 0;
                    end
                    // Distribute remaining bandwidth proportionally among in_range species
                    if (sum_in_range_demands != 0 && remaining_bandwidth != 0) begin
                        for (i = 0; i < num_species; i = i + 1) begin
                            if (classification[i] == 2) begin // in_range
                                // x_i = a_i + (remaining * d_i / sum_in_range_demands)
                                temp_remaining_shifted = remaining_bandwidth << 16;
                                temp_demand_shifted = demand[i] << 16;
                                temp_sum_in_range_shifted = sum_in_range_demands;
                                temp_proportional_shifted = 0;
                                temp_remainder = 0;
                                // Iterative subtraction for division
                                for (j = 0; j < 32; j = j + 1) begin
                                    temp_remainder = {temp_remainder[30:0], temp_remaining_shifted[31]};
                                    temp_remaining_shifted = temp_remaining_shifted << 1;
                                    if (temp_remainder >= temp_sum_in_range_shifted) begin
                                        temp_remainder = temp_remainder - temp_sum_in_range_shifted;
                                        temp_proportional_shifted[j] = 1;
                                    end
                                end
                                temp_proportional_final = temp_proportional_shifted >> 16;
                                temp_x_alloc_final = a_min[i] + temp_proportional_final;
                                x_alloc[i] = temp_x_alloc_final;
                            end
                        end
                    end
                end
                DONE: begin
                    done <= 1;
                end
                default: begin
                    done <= 0;
                end
            endcase
        end
    end

endmodule