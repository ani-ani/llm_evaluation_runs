module circle_regions(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire signed [7:0] circ_x [0:2],
    input wire signed [7:0] circ_y [0:2],
    input wire [7:0] circ_r [0:2],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_R_SQ = 3'd1;
    localparam [2:0] CALC_DIST = 3'd2;
    localparam [2:0] CLASSIFY = 3'd3;
    localparam [2:0] SORT = 3'd4;
    localparam [2:0] CHECK_EDGE = 3'd5;
    localparam [2:0] LOOKUP = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Internal registers
    reg [15:0] r_sq [0:2];
    reg [15:0] dist_sq [0:2];
    reg [2:0] rel_code [0:2];
    reg [2:0] sorted_codes [0:2];
    reg [2:0] temp_code;
    reg [3:0] pair_idx;
    reg [1:0] sort_idx;
    reg [1:0] cmp_idx;
    reg [15:0] dx, dy;
    reg [15:0] r_sum_sq, r_diff_sq;
    reg [15:0] temp_val;
    reg [3:0] lut_index;
    reg [3:0] base_result;
    reg edge_case;

    // Lookup table for region counts
    localparam [3:0] LUT [0:124] = '
        '{
            4'd2,  // n=1 (dummy)
            4'd3, 4'd3, 4'd3, 4'd3, 4'd4,  // n=2 cases
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4,
            4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4, 4'd4
        };

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            pair_idx <= 4'd0;
            sort_idx <= 2'd0;
            cmp_idx <= 2'd0;
            edge_case <= 1'b0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 3; i = i + 1) begin
                r_sq[i] <= 16'd0;
                dist_sq[i] <= 16'd0;
                rel_code[i] <= 3'd0;
                sorted_codes[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALC_R_SQ;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_R_SQ: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count < 8'd3) begin
                        r_sq[pair_idx] <= circ_r[pair_idx] * circ_r[pair_idx];
                        pair_idx <= pair_idx + 4'd1;
                        next_state <= CALC_R_SQ;
                    end else begin
                        pair_idx <= 4'd0;
                        next_state <= CALC_DIST;
                    end
                end

                CALC_DIST: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (pair_idx < 4'd3) begin
                        dx <= circ_x[pair_idx] - circ_x[pair_idx + 4'd1];
                        dy <= circ_y[pair_idx] - circ_y[pair_idx + 4'd1];
                        dist_sq[pair_idx] <= dx * dx + dy * dy;
                        pair_idx <= pair_idx + 4'd1;
                        next_state <= CALC_DIST;
                    end else begin
                        pair_idx <= 4'd0;
                        next_state <= CLASSIFY;
                    end
                end

                CLASSIFY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (pair_idx < 4'd3) begin
                        r_sum_sq <= (circ_r[pair_idx] + circ_r[pair_idx + 4'd1]) * 
                                    (circ_r[pair_idx] + circ_r[pair_idx + 4'd1]);
                        r_diff_sq <= (circ_r[pair_idx] - circ_r[pair_idx + 4'd1]) * 
                                    (circ_r[pair_idx] - circ_r[pair_idx + 4'd1]);

                        if (dist_sq[pair_idx] > r_sum_sq) begin
                            rel_code[pair_idx] <= 3'd1;  // Disjoint
                        end else if (dist_sq[pair_idx] == r_sum_sq) begin
                            rel_code[pair_idx] <= 3'd2;  // Tangent Outside
                        end else if (dist_sq[pair_idx] < r_diff_sq) begin
                            rel_code[pair_idx] <= 3'd3;  // Disjoint One Inside Other
                        end else if (dist_sq[pair_idx] == r_diff_sq) begin
                            rel_code[pair_idx] <= 3'd4;  // Tangent Inside
                        end else begin
                            rel_code[pair_idx] <= 3'd5;  // Intersecting
                        end

                        pair_idx <= pair_idx + 4'd1;
                        next_state <= CLASSIFY;
                    end else begin
                        pair_idx <= 4'd0;
                        sort_idx <= 2'd0;
                        cmp_idx <= 2'd0;
                        next_state <= SORT;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (sort_idx < 2'd3) begin
                        if (cmp_idx < 2'd2) begin
                            if (rel_code[cmp_idx] > rel_code[cmp_idx + 2'd1]) begin
                                temp_code <= rel_code[cmp_idx];
                                rel_code[cmp_idx] <= rel_code[cmp_idx + 2'd1];
                                rel_code[cmp_idx + 2'd1] <= temp_code;
                            end
                            cmp_idx <= cmp_idx + 2'd1;
                            next_state <= SORT;
                        end else begin
                            cmp_idx <= 2'd0;
                            sort_idx <= sort_idx + 2'd1;
                            next_state <= SORT;
                        end
                    end else begin
                        sorted_codes[0] <= rel_code[0];
                        sorted_codes[1] <= rel_code[1];
                        sorted_codes[2] <= rel_code[2];
                        next_state <= CHECK_EDGE;
                    end
                end

                CHECK_EDGE: begin
                    cycle_count <= cycle_count + 8'd1;
                    edge_case <= 1'b0;

                    // Check for 3-circle intersection (simplified)
                    if (n == 3'd3 && 
                        sorted_codes[0] == 3'd5 && 
                        sorted_codes[1] == 3'd5 && 
                        sorted_codes[2] == 3'd5) begin
                        // All pairs intersect - check if all 3 circles pass through same points
                        // Simplified: Assume edge case if all radii are equal and distances match
                        if (circ_r[0] == circ_r[1] && circ_r[1] == circ_r[2] &&
                            dist_sq[0] == dist_sq[1] && dist_sq[1] == dist_sq[2]) begin
                            edge_case <= 1'b1;
                        end
                    end
                    next_state <= LOOKUP;
                end

                LOOKUP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (n == 3'd1) begin
                        base_result <= 4'd2;
                    end else if (n == 3'd2) begin
                        if (rel_code[0] == 3'd5) begin
                            base_result <= 4'd4;
                        end else begin
                            base_result <= 4'd3;
                        end
                    end else begin
                        // n=3: Map sorted codes to LUT index
                        lut_index <= (sorted_codes[0] << 4) | (sorted_codes[1] << 2) | sorted_codes[2];
                        base_result <= LUT[lut_index];
                        if (edge_case) begin
                            base_result <= base_result - 4'd1;
                        end
                    end
                    next_state <= FINISH;
                end

                FINISH: begin
                    result <= base_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule