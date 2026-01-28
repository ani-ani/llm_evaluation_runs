module SymmetrySpots(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [12:0] pt_x [0:7],
    input wire signed [12:0] pt_y [0:7],
    input wire [3:0] len,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CALC_CENTROID = 4'd1;
    localparam [3:0] EVAL_POINT = 4'd2;
    localparam [3:0] EVAL_VERT = 4'd3;
    localparam [3:0] EVAL_HORIZ = 4'd4;
    localparam [3:0] EVAL_DIAG_1 = 4'd5;
    localparam [3:0] EVAL_DIAG_2 = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Centroid calculation
    reg signed [27:0] sum_x, sum_y;
    reg signed [16:0] centroid_x, centroid_y;
    reg [3:0] i, j, k;

    // Point symmetry evaluation
    reg [4:0] point_additions;
    reg [7:0] point_matches;

    // Vertical line evaluation
    reg signed [12:0] sorted_x [0:7];
    reg [4:0] vert_additions;

    // Horizontal line evaluation
    reg signed [12:0] sorted_y [0:7];
    reg [4:0] horiz_additions;

    // Diagonal 1 evaluation (x = y + c)
    reg signed [13:0] diag1_val [0:7];
    reg [4:0] diag1_additions;

    // Diagonal 2 evaluation (x = -y + c)
    reg signed [13:0] diag2_val [0:7];
    reg [4:0] diag2_additions;

    // Minimum result tracking
    reg [4:0] min_result;

    // Bubble sort for vertical
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                sorted_x[i] <= 13'd0;
            end
        end else if (state == EVAL_VERT) begin
            // Bubble sort implementation
            for (i = 0; i < 7; i = i + 1) begin
                for (j = 0; j < 7 - i; j = j + 1) begin
                    if (sorted_x[j] > sorted_x[j + 1]) begin
                        sorted_x[j] <= sorted_x[j + 1];
                        sorted_x[j + 1] <= pt_x[j];
                    end
                end
            end
        end
    end

    // Bubble sort for horizontal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                sorted_y[i] <= 13'd0;
            end
        end else if (state == EVAL_HORIZ) begin
            // Bubble sort implementation
            for (i = 0; i < 7; i = i + 1) begin
                for (j = 0; j < 7 - i; j = j + 1) begin
                    if (sorted_y[j] > sorted_y[j + 1]) begin
                        sorted_y[j] <= sorted_y[j + 1];
                        sorted_y[j + 1] <= pt_y[j];
                    end
                end
            end
        end
    end

    // Bubble sort for diagonal 1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                diag1_val[i] <= 14'd0;
            end
        end else if (state == EVAL_DIAG_1) begin
            // Bubble sort implementation
            for (i = 0; i < 7; i = i + 1) begin
                for (j = 0; j < 7 - i; j = j + 1) begin
                    if (diag1_val[j] > diag1_val[j + 1]) begin
                        diag1_val[j] <= diag1_val[j + 1];
                        diag1_val[j + 1] <= pt_x[j] - pt_y[j];
                    end
                end
            end
        end
    end

    // Bubble sort for diagonal 2
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                diag2_val[i] <= 14'd0;
            end
        end else if (state == EVAL_DIAG_2) begin
            // Bubble sort implementation
            for (i = 0; i < 7; i = i + 1) begin
                for (j = 0; j < 7 - i; j = j + 1) begin
                    if (diag2_val[j] > diag2_val[j + 1]) begin
                        diag2_val[j] <= diag2_val[j + 1];
                        diag2_val[j + 1] <= pt_x[j] + pt_y[j];
                    end
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sum_x <= 28'd0;
            sum_y <= 28'd0;
            centroid_x <= 17'd0;
            centroid_y <= 17'd0;
            point_additions <= 5'd0;
            point_matches <= 8'd0;
            vert_additions <= 5'd0;
            horiz_additions <= 5'd0;
            diag1_additions <= 5'd0;
            diag2_additions <= 5'd0;
            min_result <= 5'd31;
            for (i = 0; i < 8; i = i + 1) begin
                sorted_x[i] <= 13'd0;
                sorted_y[i] <= 13'd0;
                diag1_val[i] <= 14'd0;
                diag2_val[i] <= 14'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALC_CENTROID;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_CENTROID: begin
                    // Accumulate sums
                    sum_x <= 28'd0;
                    sum_y <= 28'd0;
                    for (i = 0; i < len; i = i + 1) begin
                        sum_x <= sum_x + pt_x[i];
                        sum_y <= sum_y + pt_y[i];
                    end

                    // Fixed-point division (Q12.4 format)
                    centroid_x <= (sum_x << 4) / len;
                    centroid_y <= (sum_y << 4) / len;

                    next_state <= EVAL_POINT;
                end

                EVAL_POINT: begin
                    // Evaluate point symmetry
                    point_matches <= 8'd0;
                    for (i = 0; i < len; i = i + 1) begin
                        for (j = 0; j < len; j = j + 1) begin
                            if (i != j && pt_x[i] + pt_x[j] == centroid_x && pt_y[i] + pt_y[j] == centroid_y) begin
                                point_matches <= point_matches + 8'd1;
                            end
                        end
                    end

                    point_additions <= (len - point_matches) / 2;
                    min_result <= point_additions;
                    next_state <= EVAL_VERT;
                end

                EVAL_VERT: begin
                    // Evaluate vertical symmetry
                    // Sort points by x-coordinate
                    for (i = 0; i < len; i = i + 1) begin
                        sorted_x[i] <= pt_x[i];
                    end

                    // Find vertical line candidates
                    vert_additions <= 5'd0;
                    for (i = 0; i < len; i = i + 1) begin
                        for (j = 0; j < len; j = j + 1) begin
                            if (i != j && sorted_x[i] == sorted_x[j]) begin
                                vert_additions <= vert_additions + 5'd1;
                            end
                        end
                    end

                    vert_additions <= (len - vert_additions) / 2;
                    if (vert_additions < min_result) begin
                        min_result <= vert_additions;
                    end
                    next_state <= EVAL_HORIZ;
                end

                EVAL_HORIZ: begin
                    // Evaluate horizontal symmetry
                    // Sort points by y-coordinate
                    for (i = 0; i < len; i = i + 1) begin
                        sorted_y[i] <= pt_y[i];
                    end

                    // Find horizontal line candidates
                    horiz_additions <= 5'd0;
                    for (i = 0; i < len; i = i + 1) begin
                        for (j = 0; j < len; j = j + 1) begin
                            if (i != j && sorted_y[i] == sorted_y[j]) begin
                                horiz_additions <= horiz_additions + 5'd1;
                            end
                        end
                    end

                    horiz_additions <= (len - horiz_additions) / 2;
                    if (horiz_additions < min_result) begin
                        min_result <= horiz_additions;
                    end
                    next_state <= EVAL_DIAG_1;
                end

                EVAL_DIAG_1: begin
                    // Evaluate diagonal 1 symmetry (x = y + c)
                    for (i = 0; i < len; i = i + 1) begin
                        diag1_val[i] <= pt_x[i] - pt_y[i];
                    end

                    // Find diagonal 1 line candidates
                    diag1_additions <= 5'd0;
                    for (i = 0; i < len; i = i + 1) begin
                        for (j = 0; j < len; j = j + 1) begin
                            if (i != j && diag1_val[i] == diag1_val[j]) begin
                                diag1_additions <= diag1_additions + 5'd1;
                            end
                        end
                    end

                    diag1_additions <= (len - diag1_additions) / 2;
                    if (diag1_additions < min_result) begin
                        min_result <= diag1_additions;
                    end
                    next_state <= EVAL_DIAG_2;
                end

                EVAL_DIAG_2: begin
                    // Evaluate diagonal 2 symmetry (x = -y + c)
                    for (i = 0; i < len; i = i + 1) begin
                        diag2_val[i] <= pt_x[i] + pt_y[i];
                    end

                    // Find diagonal 2 line candidates
                    diag2_additions <= 5'd0;
                    for (i = 0; i < len; i = i + 1) begin
                        for (j = 0; j < len; j = j + 1) begin
                            if (i != j && diag2_val[i] == diag2_val[j]) begin
                                diag2_additions <= diag2_additions + 5'd1;
                            end
                        end
                    end

                    diag2_additions <= (len - diag2_additions) / 2;
                    if (diag2_additions < min_result) begin
                        min_result <= diag2_additions;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    result <= min_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // Safety check for cycle count
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
            end
        end
    end

endmodule