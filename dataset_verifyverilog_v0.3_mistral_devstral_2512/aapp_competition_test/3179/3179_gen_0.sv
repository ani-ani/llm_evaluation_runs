module CanyonMapper (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [1:0] k,
    input wire [15:0] x [0:7],
    input wire [15:0] y [0:7],
    output reg [15:0] side,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_BBOX = 3'd1;
    localparam [2:0] BINARY_SEARCH = 3'd2;
    localparam [2:0] GENERATE_CANDIDATES = 3'd3;
    localparam [2:0] CHECK_COMBINATIONS = 3'd4;
    localparam [2:0] OUTPUT_RESULT = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] min_x, max_x, min_y, max_y;
    reg [15:0] low, high, mid;
    reg [15:0] candidate_x [0:CANDIDATE_MAX-1];
    reg [15:0] candidate_y [0:CANDIDATE_MAX-1];
    reg [7:0] candidate_mask [0:CANDIDATE_MAX-1];
    reg [7:0] candidate_count;
    reg [7:0] combination [0:K_MAX-1];
    reg [7:0] combination_idx;
    reg [7:0] current_combination;
    reg [7:0] i, j, m;
    reg [7:0] vertex_idx;
    reg [7:0] candidate_idx;
    reg [7:0] temp_mask;
    reg feasible;
    reg [7:0] n_reg, k_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            side <= 16'd0;
            done <= 1'b0;
            min_x <= 16'd0;
            max_x <= 16'd0;
            min_y <= 16'd0;
            max_y <= 16'd0;
            low <= 16'd0;
            high <= 16'd0;
            mid <= 16'd0;
            candidate_count <= 8'd0;
            combination_idx <= 8'd0;
            current_combination <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            m <= 8'd0;
            vertex_idx <= 8'd0;
            candidate_idx <= 8'd0;
            temp_mask <= 8'd0;
            feasible <= 1'b0;
            n_reg <= 8'd0;
            k_reg <= 8'd0;
            for (vertex_idx = 0; vertex_idx < CANDIDATE_MAX; vertex_idx = vertex_idx + 1) begin
                candidate_x[vertex_idx] <= 16'd0;
                candidate_y[vertex_idx] <= 16'd0;
                candidate_mask[vertex_idx] <= 8'd0;
            end
            for (vertex_idx = 0; vertex_idx < K_MAX; vertex_idx = vertex_idx + 1) begin
                combination[vertex_idx] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_BBOX;
                    n_reg = n;
                    k_reg = k;
                    min_x = 16'd32767;
                    max_x = 16'd0;
                    min_y = 16'd32767;
                    max_y = 16'd0;
                    vertex_idx = 0;
                end
            end

            COMPUTE_BBOX: begin
                if (vertex_idx < n_reg) begin
                    if (x[vertex_idx] < min_x) min_x = x[vertex_idx];
                    if (x[vertex_idx] > max_x) max_x = x[vertex_idx];
                    if (y[vertex_idx] < min_y) min_y = y[vertex_idx];
                    if (y[vertex_idx] > max_y) max_y = y[vertex_idx];
                    vertex_idx = vertex_idx + 1;
                end else begin
                    low = 16'd0;
                    high = (max_x - min_x) > (max_y - min_y) ? (max_x - min_x) : (max_y - min_y);
                    next_state = BINARY_SEARCH;
                end
            end

            BINARY_SEARCH: begin
                if (low <= high) begin
                    mid = (low + high) / 2;
                    candidate_count = 0;
                    i = 0;
                    j = 0;
                    next_state = GENERATE_CANDIDATES;
                end else begin
                    side = low;
                    next_state = OUTPUT_RESULT;
                end
            end

            GENERATE_CANDIDATES: begin
                if (i < n_reg) begin
                    if (j < n_reg) begin
                        // Generate 4 candidate squares
                        candidate_x[candidate_count] = x[i];
                        candidate_y[candidate_count] = y[j];
                        candidate_count = candidate_count + 1;

                        candidate_x[candidate_count] = x[i] - mid;
                        candidate_y[candidate_count] = y[j];
                        candidate_count = candidate_count + 1;

                        candidate_x[candidate_count] = x[i];
                        candidate_y[candidate_count] = y[j] - mid;
                        candidate_count = candidate_count + 1;

                        candidate_x[candidate_count] = x[i] - mid;
                        candidate_y[candidate_count] = y[j] - mid;
                        candidate_count = candidate_count + 1;

                        j = j + 1;
                    end else begin
                        i = i + 1;
                        j = 0;
                    end
                end else begin
                    // Compute masks for all candidates
                    candidate_idx = 0;
                    vertex_idx = 0;
                    temp_mask = 0;
                    next_state = GENERATE_CANDIDATES + 1;
                end
            end

            GENERATE_CANDIDATES + 1: begin
                if (candidate_idx < candidate_count) begin
                    if (vertex_idx < n_reg) begin
                        if (x[vertex_idx] >= candidate_x[candidate_idx] &&
                            x[vertex_idx] <= candidate_x[candidate_idx] + mid &&
                            y[vertex_idx] >= candidate_y[candidate_idx] &&
                            y[vertex_idx] <= candidate_y[candidate_idx] + mid) begin
                            temp_mask = temp_mask | (1 << vertex_idx);
                        end
                        vertex_idx = vertex_idx + 1;
                    end else begin
                        candidate_mask[candidate_idx] = temp_mask;
                        candidate_idx = candidate_idx + 1;
                        vertex_idx = 0;
                        temp_mask = 0;
                    end
                end else begin
                    // Start checking combinations
                    combination_idx = 0;
                    current_combination = 0;
                    m = 0;
                    feasible = 1'b0;
                    next_state = CHECK_COMBINATIONS;
                end
            end

            CHECK_COMBINATIONS: begin
                if (combination_idx < k_reg) begin
                    if (current_combination < candidate_count) begin
                        combination[combination_idx] = current_combination;
                        current_combination = current_combination + 1;
                        combination_idx = combination_idx + 1;
                    end else begin
                        // Check if this combination covers all vertices
                        temp_mask = 0;
                        for (m = 0; m < k_reg; m = m + 1) begin
                            temp_mask = temp_mask | candidate_mask[combination[m]];
                        end
                        if (temp_mask == (1 << n_reg) - 1) begin
                            feasible = 1'b1;
                        end
                        // Move to next combination
                        combination_idx = k_reg - 1;
                        while (combination_idx >= 0 && combination[combination_idx] == candidate_count - 1) begin
                            combination_idx = combination_idx - 1;
                        end
                        if (combination_idx >= 0) begin
                            combination[combination_idx] = combination[combination_idx] + 1;
                            for (m = combination_idx + 1; m < k_reg; m = m + 1) begin
                                combination[m] = combination[m - 1] + 1;
                            end
                        end else begin
                            combination_idx = k_reg;
                        end
                    end
                end else begin
                    if (feasible) begin
                        low = mid + 1;
                    end else begin
                        high = mid - 1;
                    end
                    next_state = BINARY_SEARCH;
                end
            end

            OUTPUT_RESULT: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule