module photo_optimizer (
    input clk,
    input rst_n,
    input start,
    input [9:0] friend_w [0:3],
    input [9:0] friend_h [0:3],
    output reg [31:0] min_area,
    output reg done,
    output reg valid
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD_DATA,
        COMPUTE_HEIGHT,
        CHECK_FRIENDS,
        CALCULATE_AREA,
        UPDATE_MIN,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [9:0] current_height;
    reg [9:0] friend_w_reg [0:3];
    reg [9:0] friend_h_reg [0:3];
    reg [9:0] mandatory_lie_count;
    reg [9:0] optional_lie_budget;
    reg [9:0] current_width_sum;
    reg [31:0] current_area;
    reg [31:0] best_area;
    reg [1:0] friend_index;
    reg [1:0] sort_index_i, sort_index_j;
    reg [9:0] sorted_benefits [0:3];
    reg [9:0] sorted_indices [0:3];
    reg [9:0] temp_benefit;
    reg [1:0] temp_index;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            valid <= 0;
            min_area <= 0;
            current_height <= 0;
            mandatory_lie_count <= 0;
            optional_lie_budget <= 0;
            current_width_sum <= 0;
            current_area <= 0;
            best_area <= 0;
            friend_index <= 0;
            sort_index_i <= 0;
            sort_index_j <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_DATA;
            end
            LOAD_DATA: begin
                next_state = COMPUTE_HEIGHT;
            end
            COMPUTE_HEIGHT: begin
                if (current_height == 1023) begin
                    next_state = DONE;
                end else begin
                    next_state = CHECK_FRIENDS;
                end
            end
            CHECK_FRIENDS: begin
                if (friend_index == 3) begin
                    next_state = CALCULATE_AREA;
                end
            end
            CALCULATE_AREA: begin
                if (sort_index_i == 3 && sort_index_j == 3) begin
                    next_state = UPDATE_MIN;
                end
            end
            UPDATE_MIN: begin
                next_state = COMPUTE_HEIGHT;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Data path logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            current_height <= 0;
            mandatory_lie_count <= 0;
            optional_lie_budget <= 0;
            current_width_sum <= 0;
            current_area <= 0;
            best_area <= 0;
            friend_index <= 0;
            sort_index_i <= 0;
            sort_index_j <= 0;
        end else begin
            case (current_state)
                LOAD_DATA: begin
                    // Load friend data
                    friend_w_reg[0] <= friend_w[0];
                    friend_w_reg[1] <= friend_w[1];
                    friend_w_reg[2] <= friend_w[2];
                    friend_w_reg[3] <= friend_w[3];
                    friend_h_reg[0] <= friend_h[0];
                    friend_h_reg[1] <= friend_h[1];
                    friend_h_reg[2] <= friend_h[2];
                    friend_h_reg[3] <= friend_h[3];
                    best_area <= 32'hFFFFFFFF;
                end
                COMPUTE_HEIGHT: begin
                    current_height <= current_height + 1;
                    mandatory_lie_count <= 0;
                    optional_lie_budget <= 0;
                    current_width_sum <= 0;
                    friend_index <= 0;
                end
                CHECK_FRIENDS: begin
                    if (friend_h_reg[friend_index] > current_height) begin
                        // Must lie down
                        mandatory_lie_count <= mandatory_lie_count + 1;
                        if (friend_w_reg[friend_index] > current_height) begin
                            // Invalid height, skip to next
                            current_height <= current_height + 1;
                            friend_index <= 0;
                        end else begin
                            current_width_sum <= current_width_sum + friend_h_reg[friend_index];
                            friend_index <= friend_index + 1;
                        end
                    end else begin
                        // Can choose to lie down or not
                        current_width_sum <= current_width_sum + friend_w_reg[friend_index];
                        friend_index <= friend_index + 1;
                    end
                end
                CALCULATE_AREA: begin
                    if (sort_index_i < 3) begin
                        if (sort_index_j < 3 - sort_index_i) begin
                            // Sort by benefit (h_i - w_i) where h_i < w_i
                            if (friend_h_reg[sorted_indices[sort_index_j]] < friend_w_reg[sorted_indices[sort_index_j]] &&
                                friend_h_reg[sorted_indices[sort_index_j+1]] < friend_w_reg[sorted_indices[sort_index_j+1]]) begin
                                if (sorted_benefits[sort_index_j] < sorted_benefits[sort_index_j+1]) begin
                                    // Swap
                                    temp_benefit <= sorted_benefits[sort_index_j];
                                    sorted_benefits[sort_index_j] <= sorted_benefits[sort_index_j+1];
                                    sorted_benefits[sort_index_j+1] <= temp_benefit;
                                    temp_index <= sorted_indices[sort_index_j];
                                    sorted_indices[sort_index_j] <= sorted_indices[sort_index_j+1];
                                    sorted_indices[sort_index_j+1] <= temp_index;
                                end
                            end
                            sort_index_j <= sort_index_j + 1;
                        end else begin
                            sort_index_i <= sort_index_i + 1;
                            sort_index_j <= 0;
                        end
                    end else begin
                        // Apply optional lie-downs
                        optional_lie_budget <= 2 - mandatory_lie_count;
                        for (int i = 0; i < 4; i = i + 1) begin
                            if (optional_lie_budget > 0 &&
                                friend_h_reg[sorted_indices[i]] < friend_w_reg[sorted_indices[i]] &&
                                friend_h_reg[sorted_indices[i]] <= current_height) begin
                                current_width_sum <= current_width_sum - friend_w_reg[sorted_indices[i]] + friend_h_reg[sorted_indices[i]];
                                optional_lie_budget <= optional_lie_budget - 1;
                            end
                        end
                        current_area <= current_width_sum * current_height;
                    end
                end
                UPDATE_MIN: begin
                    if (current_area < best_area) begin
                        best_area <= current_area;
                    end
                end
                DONE: begin
                    min_area <= best_area;
                    done <= 1;
                    valid <= 1;
                end
            endcase
        end
    end

    // Initialize sorted indices
    always @(posedge clk) begin
        if (current_state == CALCULATE_AREA && sort_index_i == 0 && sort_index_j == 0) begin
            sorted_indices[0] <= 0;
            sorted_indices[1] <= 1;
            sorted_indices[2] <= 2;
            sorted_indices[3] <= 3;
            sorted_benefits[0] <= friend_h_reg[0] - friend_w_reg[0];
            sorted_benefits[1] <= friend_h_reg[1] - friend_w_reg[1];
            sorted_benefits[2] <= friend_h_reg[2] - friend_w_reg[2];
            sorted_benefits[3] <= friend_h_reg[3] - friend_w_reg[3];
        end
    end

endmodule