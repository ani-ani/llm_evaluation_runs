module BicycleCourierDivision(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [15:0] point_x,
    input wire [15:0] point_y,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] LOAD_COORDS  = 3'd1;
    localparam [2:0] PRECOMPUTE   = 3'd2;
    localparam [2:0] ITERATE_MASKS = 3'd3;
    localparam [2:0] CALC_DIAMETER = 3'd4;
    localparam [2:0] UPDATE_RESULT = 3'd5;
    localparam [2:0] DONE_STATE   = 3'd6;

    reg [2:0] state;
    reg [3:0] N_reg;
    reg [3:0] i, j;  // Loop indices
    reg [3:0] k, l;  // Inner loop indices
    reg [15:0] min_result;
    reg [15:0] max_diameter;
    reg [15:0] diam_A, diam_B;
    reg [15:0] temp_dist;
    reg [15:0] temp_max;
    reg [15:0] dist_matrix [0:15][0:15];  // Packed 2D array
    reg [15:0] coord_x [0:15];  // Extracted x coordinates
    reg [15:0] coord_y [0:15];  // Extracted y coordinates
    reg [15:0] mask;
    reg [15:0] mask_limit;
    reg [3:0] point_count_A, point_count_B;
    reg [15:0] point_indices_A [0:15];  // List of indices in set A
    reg [15:0] point_indices_B [0:15];  // List of indices in set B
    reg [3:0] cnt_A, cnt_B;
    reg [15:0] temp_result;
    reg [15:0] abs_diff_x, abs_diff_y;
    
    integer p, q;  // For indexing in loops

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            valid <= 1'b0;
            min_result <= 16'd0;
            mask <= 16'd0;
            mask_limit <= 16'd0;
            N_reg <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            l <= 4'd0;
            cnt_A <= 4'd0;
            cnt_B <= 4'd0;
            diam_A <= 16'd0;
            diam_B <= 16'd0;
            max_diameter <= 16'd0;
            temp_result <= 16'd0;
            point_count_A <= 4'd0;
            point_count_B <= 4'd0;
            abs_diff_x <= 16'd0;
            abs_diff_y <= 16'd0;
            temp_dist <= 16'd0;
            temp_max <= 16'd0;
            // Initialize dist_matrix and coord arrays
            for (p = 0; p < 16; p = p + 1) begin
                coord_x[p] <= 16'd0;
                coord_y[p] <= 16'd0;
                for (q = 0; q < 16; q = q + 1) begin
                    dist_matrix[p][q] <= 16'd0;
                end
                point_indices_A[p] <= 16'd0;
                point_indices_B[p] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    min_result <= 16'hFFFF;
                    mask <= 16'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    l <= 4'd0;
                    cnt_A <= 4'd0;
                    cnt_B <= 4'd0;
                    diam_A <= 16'd0;
                    diam_B <= 16'd0;
                    max_diameter <= 16'd0;
                    point_count_A <= 4'd0;
                    point_count_B <= 4'd0;
                    if (start) begin
                        N_reg <= N;
                        state <= LOAD_COORDS;
                    end
                end

                LOAD_COORDS: begin
                    if (i < N_reg) begin
                        coord_x[i] <= {12'd0, point_x[15-(4*i)-:4]};  // Extract 4 bits for each point
                        coord_y[i] <= {12'd0, point_y[15-(4*i)-:4]};
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= PRECOMPUTE;
                    end
                end

                PRECOMPUTE: begin
                    if (i < N_reg) begin
                        if (j < N_reg) begin
                            if (i == j) begin
                                dist_matrix[i][j] <= 16'd0;
                            end else begin
                                if (coord_x[i] > coord_x[j])
                                    abs_diff_x <= coord_x[i] - coord_x[j];
                                else
                                    abs_diff_x <= coord_x[j] - coord_x[i];
                                if (coord_y[i] > coord_y[j])
                                    abs_diff_y <= coord_y[i] - coord_y[j];
                                else
                                    abs_diff_y <= coord_y[j] - coord_y[i];
                            end
                            j <= j + 4'd1;
                        end else begin
                            if (i < N_reg) begin
                                dist_matrix[i][j] <= abs_diff_x + abs_diff_y;
                            end
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        mask <= 16'd1;  // Start from 1
                        mask_limit <= (1 << N_reg) - 2;  // End at (2^N - 2)
                        state <= ITERATE_MASKS;
                    end
                end

                ITERATE_MASKS: begin
                    if (mask <= mask_limit) begin
                        point_count_A <= 4'd0;
                        point_count_B <= 4'd0;
                        // Separate points into sets A and B
                        for (p = 0; p < 16; p = p + 1) begin
                            if (p < N_reg) begin
                                if (mask[p]) begin
                                    point_indices_A[point_count_A] <= p;
                                    point_count_A <= point_count_A + 4'd1;
                                end else begin
                                    point_indices_B[point_count_B] <= p;
                                    point_count_B <= point_count_B + 4'd1;
                                end
                            end
                        end
                        cnt_A <= 4'd0;
                        cnt_B <= 4'd0;
                        diam_A <= 16'd0;
                        diam_B <= 16'd0;
                        state <= CALC_DIAMETER;
                    end else begin
                        result <= min_result;
                        state <= DONE_STATE;
                    end
                end

                CALC_DIAMETER: begin
                    // Calculate diameter for set A
                    if (point_count_A > 4'd1) begin
                        if (cnt_A < point_count_A) begin
                            if (cnt_B < point_count_A) begin
                                temp_dist <= dist_matrix[point_indices_A[cnt_A]][point_indices_A[cnt_B]];
                                cnt_B <= cnt_B + 4'd1;
                            end else begin
                                if (temp_dist > diam_A) begin
                                    diam_A <= temp_dist;
                                end
                                cnt_B <= 4'd0;
                                cnt_A <= cnt_A + 4'd1;
                            end
                        end else begin
                            cnt_A <= 4'd0;
                            cnt_B <= 4'd0;
                            // Calculate diameter for set B
                            if (point_count_B > 4'd1) begin
                                if (cnt_A < point_count_B) begin
                                    if (cnt_B < point_count_B) begin
                                        temp_dist <= dist_matrix[point_indices_B[cnt_A]][point_indices_B[cnt_B]];
                                        cnt_B <= cnt_B + 4'd1;
                                    end else begin
                                        if (temp_dist > diam_B) begin
                                            diam_B <= temp_dist;
                                        end
                                        cnt_B <= 4'd0;
                                        cnt_A <= cnt_A + 4'd1;
                                    end
                                end else begin
                                    // Both diameters calculated
                                    max_diameter <= (diam_A > diam_B) ? diam_A : diam_B;
                                    state <= UPDATE_RESULT;
                                end
                            end else begin
                                diam_B <= 16'd0;
                                max_diameter <= (diam_A > 16'd0) ? diam_A : 16'd0;
                                state <= UPDATE_RESULT;
                            end
                        end
                    end else begin
                        diam_A <= 16'd0;
                        // Calculate diameter for set B
                        if (point_count_B > 4'd1) begin
                            if (cnt_A < point_count_B) begin
                                if (cnt_B < point_count_B) begin
                                    temp_dist <= dist_matrix[point_indices_B[cnt_A]][point_indices_B[cnt_B]];
                                    cnt_B <= cnt_B + 4'd1;
                                end else begin
                                    if (temp_dist > diam_B) begin
                                        diam_B <= temp_dist;
                                    end
                                    cnt_B <= 4'd0;
                                    cnt_A <= cnt_A + 4'd1;
                                end
                            end else begin
                                max_diameter <= diam_B;
                                state <= UPDATE_RESULT;
                            end
                        end else begin
                            diam_B <= 16'd0;
                            max_diameter <= 16'd0;
                            state <= UPDATE_RESULT;
                        end
                    end
                end

                UPDATE_RESULT: begin
                    if (max_diameter < min_result) begin
                        min_result <= max_diameter;
                    end
                    mask <= mask + 16'd1;
                    state <= ITERATE_MASKS;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule