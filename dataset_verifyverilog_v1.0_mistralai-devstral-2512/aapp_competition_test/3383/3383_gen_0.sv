module ice_cream_optimizer(
    input clk,
    input rst_n,
    input start,
    input [29:0] n,
    input [6:0] k,
    input [7:0] a,
    input [7:0] b,
    input [6:0][15:0] t,
    input [6:0][6:0][15:0] u,
    output reg [47:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_MATRIX = 3'd1;
    localparam [2:0] FLOYD_WARSHALL = 3'd2;
    localparam [2:0] MATRIX_EXP = 3'd3;
    localparam [2:0] COMPUTE_COST = 3'd4;
    localparam [2:0] DIVISION = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;

    // Counters and control signals
    reg [6:0] fw_counter;
    reg [29:0] exp_counter;
    reg [4:0] div_counter;
    reg [23:0] div_remainder;
    reg [23:0] div_divisor;
    reg [23:0] div_quotient;

    // Matrix storage (100x100 max)
    reg signed [23:0] M [0:99][0:99];
    reg signed [23:0] result_matrix [0:99][0:99];
    reg signed [23:0] temp_matrix [0:99][0:99];
    reg signed [23:0] current_max [0:99];

    // Intermediate results
    reg signed [47:0] total_tastiness;
    reg signed [47:0] total_cost;
    reg signed [47:0] division_result;

    // Initialize matrix M
    integer i, j, l;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 48'd0;
            fw_counter <= 7'd0;
            exp_counter <= 30'd0;
            div_counter <= 5'd0;
            div_remainder <= 24'd0;
            div_divisor <= 24'd0;
            div_quotient <= 24'd0;
            total_tastiness <= 48'd0;
            total_cost <= 48'd0;
            division_result <= 48'd0;

            // Initialize matrices to zero
            for (i = 0; i < 100; i = i + 1) begin
                for (j = 0; j < 100; j = j + 1) begin
                    M[i][j] <= 24'd0;
                    result_matrix[i][j] <= 24'd0;
                    temp_matrix[i][j] <= 24'd0;
                end
                current_max[i] <= 24'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_MATRIX;
                end
            end

            INIT_MATRIX: begin
                // Initialize M matrix: M[i][j] = t[j] + u[i][j]
                for (i = 0; i < k; i = i + 1) begin
                    for (j = 0; j < k; j = j + 1) begin
                        M[i][j] = t[j] + u[i][j];
                    end
                end
                next_state = FLOYD_WARSHALL;
            end

            FLOYD_WARSHALL: begin
                // Floyd-Warshall algorithm for longest paths
                if (fw_counter < k) begin
                    for (i = 0; i < k; i = i + 1) begin
                        for (j = 0; j < k; j = j + 1) begin
                            if (M[i][fw_counter] + M[fw_counter][j] > M[i][j]) begin
                                M[i][j] = M[i][fw_counter] + M[fw_counter][j];
                            end
                        end
                    end
                    fw_counter = fw_counter + 1;
                end else begin
                    fw_counter = 7'd0;
                    // Initialize result_matrix as identity for max-plus
                    for (i = 0; i < k; i = i + 1) begin
                        for (j = 0; j < k; j = j + 1) begin
                            result_matrix[i][j] = (i == j) ? 24'd0 : -24'd8388608; // -infinity
                        end
                    end
                    exp_counter = n;
                    next_state = MATRIX_EXP;
                end
            end

            MATRIX_EXP: begin
                // Matrix exponentiation using exponentiation by squaring
                if (exp_counter > 0) begin
                    if (exp_counter[0]) begin
                        // Multiply result_matrix by M
                        for (i = 0; i < k; i = i + 1) begin
                            for (j = 0; j < k; j = j + 1) begin
                                temp_matrix[i][j] = -24'd8388608;
                                for (l = 0; l < k; l = l + 1) begin
                                    if (result_matrix[i][l] + M[l][j] > temp_matrix[i][j]) begin
                                        temp_matrix[i][j] = result_matrix[i][l] + M[l][j];
                                    end
                                end
                            end
                        end
                        // Copy temp_matrix to result_matrix
                        for (i = 0; i < k; i = i + 1) begin
                            for (j = 0; j < k; j = j + 1) begin
                                result_matrix[i][j] = temp_matrix[i][j];
                            end
                        end
                    end

                    // Square M
                    for (i = 0; i < k; i = i + 1) begin
                        for (j = 0; j < k; j = j + 1) begin
                            temp_matrix[i][j] = -24'd8388608;
                            for (l = 0; l < k; l = l + 1) begin
                                if (M[i][l] + M[l][j] > temp_matrix[i][j]) begin
                                    temp_matrix[i][j] = M[i][l] + M[l][j];
                                end
                            end
                        end
                    end
                    // Copy temp_matrix to M
                    for (i = 0; i < k; i = i + 1) begin
                        for (j = 0; j < k; j = j + 1) begin
                            M[i][j] = temp_matrix[i][j];
                        end
                    end

                    exp_counter = exp_counter >> 1;
                end else begin
                    // Find maximum tastiness across all starting flavours
                    for (i = 0; i < k; i = i + 1) begin
                        current_max[i] = -24'd8388608;
                        for (j = 0; j < k; j = j + 1) begin
                            if (result_matrix[i][j] > current_max[i]) begin
                                current_max[i] = result_matrix[i][j];
                            end
                        end
                    end

                    // Find overall maximum
                    total_tastiness = -48'd140737488355328;
                    for (i = 0; i < k; i = i + 1) begin
                        if (current_max[i] > total_tastiness[23:0]) begin
                            total_tastiness = {{24'd0}, current_max[i]};
                        end
                    end
                    next_state = COMPUTE_COST;
                end
            end

            COMPUTE_COST: begin
                // Compute total cost = n*a + b
                total_cost = (n * a) + b;
                next_state = DIVISION;
            end

            DIVISION: begin
                // Fixed-point division using iterated subtraction
                div_remainder = total_tastiness[23:0];
                div_divisor = total_cost[23:0];
                div_quotient = 24'd0;

                if (div_divisor != 0) begin
                    for (div_counter = 23; div_counter >= 0; div_counter = div_counter - 1) begin
                        div_remainder = div_remainder - div_divisor;
                        if (div_remainder >= 0) begin
                            div_quotient[div_counter] = 1'b1;
                        end else begin
                            div_remainder = div_remainder + div_divisor;
                        end
                    end
                end

                // Result is (tastiness/cost) * 2^24
                division_result = {{24'd0}, div_quotient};
                next_state = FINISH;
            end

            FINISH: begin
                result = division_result;
                done = 1'b1;
                valid = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Clear done signal after one cycle
    always @(posedge clk) begin
        if (state == FINISH) begin
            done <= 1'b0;
        end
    end

endmodule