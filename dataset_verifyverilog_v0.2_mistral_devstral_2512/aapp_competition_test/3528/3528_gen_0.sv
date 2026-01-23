module elastic_band_area (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_points,
    input [5:0] num_removals,
    input [31:0] points_x [0:15],
    input [31:0] points_y [0:15],
    input [3:0] removals [0:13],
    output reg [31:0] area_out,
    output reg [3:0] area_idx,
    output reg area_valid,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam CONVEX_HULL = 3'b001;
    localparam CALCULATE_AREA = 3'b010;
    localparam REMOVE_POINT = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [5:0] removal_count;
    reg [5:0] point_count;
    reg [3:0] current_removal;
    reg [31:0] active_x [0:15];
    reg [31:0] active_y [0:15];
    reg [31:0] hull_x [0:15];
    reg [31:0] hull_y [0:15];
    reg [5:0] hull_size;
    reg [5:0] i, j, k;
    reg [31:0] temp_x, temp_y;
    reg [31:0] sum1, sum2;
    reg [31:0] cross_product;
    reg [31:0] min_x, min_y;
    reg [5:0] min_idx;
    reg [31:0] area_accum;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            removal_count <= 0;
            point_count <= 0;
            current_removal <= 0;
            area_out <= 0;
            area_idx <= 0;
            area_valid <= 0;
            done <= 0;
            hull_size <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            sum1 <= 0;
            sum2 <= 0;
            area_accum <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CONVEX_HULL;
                        removal_count <= 0;
                        point_count <= num_points;
                        // Initialize active points
                        for (i = 0; i < 16; i = i + 1) begin
                            active_x[i] <= points_x[i];
                            active_y[i] <= points_y[i];
                        end
                    end
                end

                CONVEX_HULL: begin
                    // Simplified Graham scan
                    // Step 1: Find point with lowest y (and leftmost if tie)
                    min_y <= active_y[0];
                    min_x <= active_x[0];
                    min_idx <= 0;
                    for (i = 1; i < point_count; i = i + 1) begin
                        if (active_y[i] < min_y || (active_y[i] == min_y && active_x[i] < min_x)) begin
                            min_y <= active_y[i];
                            min_x <= active_x[i];
                            min_idx <= i;
                        end
                    end

                    // Step 2: Sort by polar angle using bubble sort
                    for (i = 0; i < point_count - 1; i = i + 1) begin
                        for (j = 0; j < point_count - i - 1; j = j + 1) begin
                            // Compute cross product
                            cross_product <= (active_x[j] - min_x) * (active_y[j+1] - min_y) - 
                                           (active_y[j] - min_y) * (active_x[j+1] - min_x);
                            if (cross_product < 0) begin
                                // Swap points
                                temp_x <= active_x[j];
                                temp_y <= active_y[j];
                                active_x[j] <= active_x[j+1];
                                active_y[j] <= active_y[j+1];
                                active_x[j+1] <= temp_x;
                                active_y[j+1] <= temp_y;
                            end
                        end
                    end

                    // Step 3: Build convex hull
                    hull_size <= 0;
                    hull_x[0] <= min_x;
                    hull_y[0] <= min_y;
                    hull_size <= 1;
                    hull_x[1] <= active_x[0];
                    hull_y[1] <= active_y[0];
                    hull_size <= 2;

                    for (i = 1; i < point_count; i = i + 1) begin
                        while (hull_size > 1 && 
                              (hull_x[hull_size-1] - hull_x[hull_size-2]) * (active_y[i] - hull_y[hull_size-2]) <= 
                              (hull_y[hull_size-1] - hull_y[hull_size-2]) * (active_x[i] - hull_x[hull_size-2])) begin
                            hull_size <= hull_size - 1;
                        end
                        hull_x[hull_size] <= active_x[i];
                        hull_y[hull_size] <= active_y[i];
                        hull_size <= hull_size + 1;
                    end

                    state <= CALCULATE_AREA;
                end

                CALCULATE_AREA: begin
                    // Shoelace formula
                    sum1 <= 0;
                    sum2 <= 0;
                    for (i = 0; i < hull_size - 1; i = i + 1) begin
                        sum1 <= sum1 + (hull_x[i] * hull_y[i+1]);
                        sum2 <= sum2 + (hull_y[i] * hull_x[i+1]);
                    end
                    // Close the polygon
                    sum1 <= sum1 + (hull_x[hull_size-1] * hull_y[0]);
                    sum2 <= sum2 + (hull_y[hull_size-1] * hull_x[0]);

                    // Absolute value and multiply by 65536 (Q16.16)
                    area_accum <= (sum1 > sum2) ? (sum1 - sum2) : (sum2 - sum1);
                    area_accum <= area_accum * 65536;

                    area_out <= area_accum;
                    area_idx <= removal_count;
                    area_valid <= 1;
                    state <= REMOVE_POINT;
                end

                REMOVE_POINT: begin
                    area_valid <= 0;
                    if (removal_count < num_removals) begin
                        current_removal <= removals[removal_count];
                        // Find and remove extremal point
                        case (current_removal)
                            0: begin // Leftmost
                                min_x <= active_x[0];
                                min_idx <= 0;
                                for (i = 1; i < point_count; i = i + 1) begin
                                    if (active_x[i] < min_x) begin
                                        min_x <= active_x[i];
                                        min_idx <= i;
                                    end
                                end
                            end
                            1: begin // Rightmost
                                min_x <= active_x[0];
                                min_idx <= 0;
                                for (i = 1; i < point_count; i = i + 1) begin
                                    if (active_x[i] > min_x) begin
                                        min_x <= active_x[i];
                                        min_idx <= i;
                                    end
                                end
                            end
                            2: begin // Topmost
                                min_y <= active_y[0];
                                min_idx <= 0;
                                for (i = 1; i < point_count; i = i + 1) begin
                                    if (active_y[i] > min_y) begin
                                        min_y <= active_y[i];
                                        min_idx <= i;
                                    end
                                end
                            end
                            3: begin // Bottommost
                                min_y <= active_y[0];
                                min_idx <= 0;
                                for (i = 1; i < point_count; i = i + 1) begin
                                    if (active_y[i] < min_y) begin
                                        min_y <= active_y[i];
                                        min_idx <= i;
                                    end
                                end
                            end
                        endcase

                        // Remove the point by shifting
                        for (i = min_idx; i < point_count - 1; i = i + 1) begin
                            active_x[i] <= active_x[i+1];
                            active_y[i] <= active_y[i+1];
                        end
                        point_count <= point_count - 1;
                        removal_count <= removal_count + 1;
                        state <= CONVEX_HULL;
                    end else begin
                        state <= DONE;
                        done <= 1;
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule