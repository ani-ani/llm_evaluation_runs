module rect_area_calculator (
    input clk,
    input rst_n,
    input start,
    input [31:0] x1,
    input [31:0] y1,
    input [31:0] x2,
    input [31:0] y2,
    input [1:0] rect_idx,
    input rect_valid,
    output reg [31:0] total_area,
    output reg done,
    output reg [1:0] state_out
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam LOADING = 2'b01;
    localparam COMPUTING = 2'b10;
    localparam DONE = 2'b11;

    // Registers for rectangle storage
    reg [31:0] rects_x1 [0:3];
    reg [31:0] rects_y1 [0:3];
    reg [31:0] rects_x2 [0:3];
    reg [31:0] rects_y2 [0:3];
    reg [3:0] rects_valid;

    // Coordinate sorting arrays
    reg [31:0] x_coords [0:7];
    reg [31:0] y_coords [0:7];
    reg [3:0] x_count;
    reg [3:0] y_count;

    // Computation registers
    reg [5:0] cycle_counter;
    reg [3:0] loop_cnt; // 0 to 15 for area loops

    // State register
    reg [1:0] state;

    // Combinational helper wires for area calculation
    wire [1:0] i_idx;
    wire [1:0] j_idx;
    wire [31:0] x_low, x_high;
    wire [31:0] y_low, y_high;
    wire valid_strip;
    wire rect0_covered, rect1_covered, rect2_covered, rect3_covered;
    wire segment_covered;
    wire [31:0] dx_val;
    wire [31:0] dy_val;
    wire [63:0] prod_val;
    wire [31:0] inc_val;

    // Index logic for area calculation
    assign i_idx = loop_cnt[3:2];
    assign j_idx = loop_cnt[1:0];

    // Coordinate MUX for current strip/segment
    assign x_low = (i_idx == 2'd0) ? x_coords[0] : (i_idx == 2'd1) ? x_coords[1] : (i_idx == 2'd2) ? x_coords[2] : x_coords[3];
    assign x_high = (i_idx == 2'd0) ? x_coords[1] : (i_idx == 2'd1) ? x_coords[2] : (i_idx == 2'd2) ? x_coords[3] : x_coords[4];
    assign y_low = (j_idx == 2'd0) ? y_coords[0] : (j_idx == 2'd1) ? y_coords[1] : (j_idx == 2'd2) ? y_coords[2] : y_coords[3];
    assign y_high = (j_idx == 2'd0) ? y_coords[1] : (j_idx == 2'd1) ? y_coords[2] : (j_idx == 2'd2) ? y_coords[3] : y_coords[4];

    // Validity and Coverage Check
    assign valid_strip = (state == COMPUTING) && (cycle_counter >= 38 && cycle_counter <= 53) && 
                         (i_idx < (x_count - 1)) && (j_idx < (y_count - 1));

    assign rect0_covered = rects_valid[0] && (rects_x1[0] < x_high) && (rects_x2[0] > x_low) && (rects_y1[0] < y_high) && (rects_y2[0] > y_low);
    assign rect1_covered = rects_valid[1] && (rects_x1[1] < x_high) && (rects_x2[1] > x_low) && (rects_y1[1] < y_high) && (rects_y2[1] > y_low);
    assign rect2_covered = rects_valid[2] && (rects_x1[2] < x_high) && (rects_x2[2] > x_low) && (rects_y1[2] < y_high) && (rects_y2[2] > y_low);
    assign rect3_covered = rects_valid[3] && (rects_x1[3] < x_high) && (rects_x2[3] > x_low) && (rects_y1[3] < y_high) && (rects_y2[3] > y_low);
    assign segment_covered = rect0_covered || rect1_covered || rect2_covered || rect3_covered;

    // Area Calculation
    assign dx_val = x_high - x_low;
    assign dy_val = y_high - y_low;
    assign prod_val = dx_val * dy_val;
    assign inc_val = prod_val[47:16]; // Shift right 16 for Q16.16 result

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            total_area <= 32'd0;
            rects_valid <= 4'b0;
            state_out <= IDLE;
            cycle_counter <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    state_out <= IDLE;
                    if (start) begin
                        state <= LOADING;
                        state_out <= LOADING;
                        rects_valid <= 4'b0; // Clear previous data
                    end
                end

                LOADING: begin
                    state_out <= LOADING;
                    if (rect_valid) begin
                        if (x1 < x2) begin
                            rects_x1[rect_idx] <= x1;
                            rects_x2[rect_idx] <= x2;
                        end else begin
                            rects_x1[rect_idx] <= x2;
                            rects_x2[rect_idx] <= x1;
                        end
                        if (y1 < y2) begin
                            rects_y1[rect_idx] <= y1;
                            rects_y2[rect_idx] <= y2;
                        end else begin
                            rects_y1[rect_idx] <= y2;
                            rects_y2[rect_idx] <= y1;
                        end
                        rects_valid[rect_idx] <= 1'b1;
                    end
                    // Transition when start is released
                    if (!start && (rects_valid != 0)) begin
                        state <= COMPUTING;
                        state_out <= COMPUTING;
                        cycle_counter <= 6'd0;
                    end
                end

                COMPUTING: begin
                    state_out <= COMPUTING;
                    cycle_counter <= cycle_counter + 1;

                    // --- Phase 1: Coordinate Extraction (0-8) ---
                    if (cycle_counter == 0) begin
                        x_count <= 0; y_count <= 0;
                    end else if (cycle_counter >= 1 && cycle_counter <= 4) begin
                        if (rects_valid[cycle_counter-1]) begin
                            x_coords[x_count] <= rects_x1[cycle_counter-1];
                            y_coords[y_count] <= rects_y1[cycle_counter-1];
                            x_count <= x_count + 1;
                            y_count <= y_count + 1;
                        end
                    end else if (cycle_counter >= 5 && cycle_counter <= 8) begin
                        if (rects_valid[cycle_counter-5]) begin
                            x_coords[x_count] <= rects_x2[cycle_counter-5];
                            y_coords[y_count] <= rects_y2[cycle_counter-5];
                            x_count <= x_count + 1;
                            y_count <= y_count + 1;
                        end
                    end

                    // --- Phase 2: Sorting X (9-22) ---
                    if (cycle_counter >= 9 && cycle_counter <= 22) begin
                        // Unrolled Bubble Sort Passes
                        case (cycle_counter)
                            // Pass 1
                            9: begin if (x_coords[6] > x_coords[7]) begin x_coords[6] <= x_coords[7]; x_coords[7] <= x_coords[6]; end end
                            10: begin if (x_coords[5] > x_coords[6]) begin x_coords[5] <= x_coords[6]; x_coords[6] <= x_coords[5]; end end
                            11: begin if (x_coords[4] > x_coords[5]) begin x_coords[4] <= x_coords[5]; x_coords[5] <= x_coords[4]; end end
                            12: begin if (x_coords[3] > x_coords[4]) begin x_coords[3] <= x_coords[4]; x_coords[4] <= x_coords[3]; end end
                            13: begin if (x_coords[2] > x_coords[3]) begin x_coords[2] <= x_coords[3]; x_coords[3] <= x_coords[2]; end end
                            14: begin if (x_coords[1] > x_coords[2]) begin x_coords[1] <= x_coords[2]; x_coords[2] <= x_coords[1]; end end
                            15: begin if (x_coords[0] > x_coords[1]) begin x_coords[0] <= x_coords[1]; x_coords[1] <= x_coords[0]; end end
                            // Pass 2
                            16: begin if (x_coords[6] > x_coords[7]) begin x_coords[6] <= x_coords[7]; x_coords[7] <= x_coords[6]; end end
                            17: begin if (x_coords[5] > x_coords[6]) begin x_coords[5] <= x_coords[6]; x_coords[6] <= x_coords[5]; end end
                            18: begin if (x_coords[4] > x_coords[5]) begin x_coords[4] <= x_coords[5]; x_coords[5] <= x_coords[4]; end end
                            19: begin if (x_coords[3] > x_coords[4]) begin x_coords[3] <= x_coords[4]; x_coords[4] <= x_coords[3]; end end
                            20: begin if (x_coords[2] > x_coords[3]) begin x_coords[2] <= x_coords[3]; x_coords[3] <= x_coords[2]; end end
                            21: begin if (x_coords[1] > x_coords[2]) begin x_coords[1] <= x_coords[2]; x_coords[2] <= x_coords[1]; end end
                            22: begin if (x_coords[0] > x_coords[1]) begin x_coords[0] <= x_coords[1]; x_coords[1] <= x_coords[0]; end end
                        endcase
                    end

                    // --- Phase 3: Sorting Y (23-36) ---
                    if (cycle_counter >= 23 && cycle_counter <= 36) begin
                        // Unrolled Bubble Sort Passes for Y
                        case (cycle_counter)
                            // Pass 1
                            23: begin if (y_coords[6] > y_coords[7]) begin y_coords[6] <= y_coords[7]; y_coords[7] <= y_coords[6]; end end
                            24: begin if (y_coords[5] > y_coords[6]) begin y_coords[5] <= y_coords[6]; y_coords[6] <= y_coords[5]; end end
                            25: begin if (y_coords[4] > y_coords[5]) begin y_coords[4] <= y_coords[5]; y_coords[5] <= y_coords[4]; end end
                            26: begin if (y_coords[3] > y_coords[4]) begin y_coords[3] <= y_coords[4]; y_coords[4] <= y_coords[3]; end end
                            27: begin if (y_coords[2] > y_coords[3]) begin y_coords[2] <= y_coords[3]; y_coords[3] <= y_coords[2]; end end
                            28: begin if (y_coords[1] > y_coords[2]) begin y_coords[1] <= y_coords[2]; y_coords[2] <= y_coords[1]; end end
                            29: begin if (y_coords[0] > y_coords[1]) begin y_coords[0] <= y_coords[1]; y_coords[1] <= y_coords[0]; end end
                            // Pass 2
                            30: begin if (y_coords[6] > y_coords[7]) begin y_coords[6] <= y_coords[7]; y_coords[7] <= y_coords[6]; end end
                            31: begin if (y_coords[5] > y_coords[6]) begin y_coords[5] <= y_coords[6]; y_coords[6] <= y_coords[5]; end end
                            32: begin if (y_coords[4] > y_coords[5]) begin y_coords[4] <= y_coords[5]; y_coords[5] <= y_coords[4]; end end
                            33: begin if (y_coords[3] > y_coords[4]) begin y_coords[3] <= y_coords[4]; y_coords[4] <= y_coords[3]; end end
                            34: begin if (y_coords[2] > y_coords[3]) begin y_coords[2] <= y_coords[3]; y_coords[3] <= y_coords[2]; end end
                            35: begin if (y_coords[1] > y_coords[2]) begin y_coords[1] <= y_coords[2]; y_coords[2] <= y_coords[1]; end end
                            36: begin if (y_coords[0] > y_coords[1]) begin y_coords[0] <= y_coords[1]; y_coords[1] <= y_coords[0]; end end
                        endcase
                    end

                    // --- Phase 4: Area Accumulation (37-53) ---
                    if (cycle_counter == 37) begin
                        loop_cnt <= 0;
                        total_area <= 32'd0;
                    end else if (cycle_counter >= 38 && cycle_counter <= 53) begin
                        // Check validity and coverage
                        if (valid_strip && segment_covered) begin
                            // Accumulate area. inc_val is combinational result.
                            total_area <= total_area + inc_val;
                        end
                        // Increment loop counter
                        if (loop_cnt < 15) loop_cnt <= loop_cnt + 1;
                    end

                    // --- Phase 5: Completion ---
                    if (cycle_counter == 54) begin
                        state <= DONE;
                        state_out <= DONE;
                        done <= 1'b1;
                    end

                end

                DONE: begin
                    state_out <= DONE;
                    done <= 1'b1;
                    if (start) begin
                        state <= LOADING;
                        state_out <= LOADING;
                        done <= 1'b0;
                        rects_valid <= 4'b0;
                        total_area <= 32'd0;
                    end
                end
            endcase
        end
    end
endmodule