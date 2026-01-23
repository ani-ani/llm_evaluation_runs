module fruit_slicer (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_circles,
    input [63:0] circle_x [0:7],
    input [63:0] circle_y [0:7],
    output reg [3:0] max_slices,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam COMPUTE_DIR = 3'b001;
    localparam PROJECT = 3'b010;
    localparam SORT = 3'b011;
    localparam COUNT = 3'b100;
    localparam NEXT_DIR = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    reg [3:0] dir_idx; // 0 to 15
    reg [2:0] pt_idx;   // 0 to 7
    reg [3:0] max_count_dir; // Max count for current direction
    reg [2:0] k; // Inner loop index
    reg proj_phase; // 0: mult, 1: store
    reg [3:0] current_count;

    // Lookup table for cos(theta) and sin(theta) in Q16.16
    wire [31:0] cos_val [0:15];
    wire [31:0] sin_val [0:15];

    // 0: 0 deg
    assign cos_val[0] = 32'h00010000;
    assign sin_val[0] = 32'h00000000;
    // 1: 11.25 deg
    assign cos_val[1] = 32'h0000F625;
    assign sin_val[1] = 32'h0000302B;
    // 2: 22.5 deg
    assign cos_val[2] = 32'h0000EC83;
    assign sin_val[2] = 32'h00005A82;
    // 3: 33.75 deg
    assign cos_val[3] = 32'h0000D880;
    assign sin_val[3] = 32'h00007C98;
    // 4: 45 deg
    assign cos_val[4] = 32'h0000B504;
    assign sin_val[4] = 32'h0000B504;
    // 5: 56.25 deg
    assign cos_val[5] = 32'h00007C98;
    assign sin_val[5] = 32'h0000D880;
    // 6: 67.5 deg
    assign cos_val[6] = 32'h00005A82;
    assign sin_val[6] = 32'h0000EC83;
    // 7: 78.75 deg
    assign cos_val[7] = 32'h0000302B;
    assign sin_val[7] = 32'h0000F625;
    // 8: 90 deg
    assign cos_val[8] = 32'h00000000;
    assign sin_val[8] = 32'h00010000;
    // 9: 101.25 deg
    assign cos_val[9] = 32'hFFFFCFD5;
    assign sin_val[9] = 32'h0000F625;
    // 10: 112.5 deg
    assign cos_val[10] = 32'hFFFFA57E;
    assign sin_val[10] = 32'h0000EC83;
    // 11: 123.75 deg
    assign cos_val[11] = 32'hFFFF8368;
    assign sin_val[11] = 32'h0000D880;
    // 12: 135 deg
    assign cos_val[12] = 32'hFFFF4AFC;
    assign sin_val[12] = 32'h0000B504;
    // 13: 146.25 deg
    assign cos_val[13] = 32'hFFFF2768;
    assign sin_val[13] = 32'h00007C98;
    // 14: 157.5 deg
    assign cos_val[14] = 32'hFFFF137D;
    assign sin_val[14] = 32'h00005A82;
    // 15: 168.75 deg
    assign cos_val[15] = 32'hFFFF09DB;
    assign sin_val[15] = 32'h0000302B;

    // Projections storage (Q32.32 format)
    reg signed [63:0] projections [0:7];

    // Multiplier intermediates
    reg signed [63:0] prod_x;
    reg signed [63:0] prod_y;

    // Window width: 2.0 in Q32.32 (0x2_0000_0000)
    wire signed [63:0] window_width;
    assign window_width = 64'h0000000200000000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_slices <= 0;
            dir_idx <= 0;
            pt_idx <= 0;
            max_count_dir <= 0;
            proj_phase <= 0;
            k <= 0;
            current_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COMPUTE_DIR;
                        max_slices <= 0;
                        dir_idx <= 0;
                    end
                end

                COMPUTE_DIR: begin
                    pt_idx <= 0;
                    proj_phase <= 0;
                    state <= PROJECT;
                end

                PROJECT: begin
                    // Loop to fill projections array
                    if (pt_idx < num_circles) begin
                        if (proj_phase == 0) begin
                            // Trigger Mult: x*sin - y*cos (using lower 32 bits as Q16.16)
                            prod_x <= $signed(circle_x[pt_idx][31:0]) * $signed(sin_val[dir_idx]);
                            prod_y <= $signed(circle_y[pt_idx][31:0]) * $signed(cos_val[dir_idx]);
                            proj_phase <= 1;
                        end else begin
                            // Store Result (Full Q32.32)
                            projections[pt_idx] <= prod_x - prod_y;
                            pt_idx <= pt_idx + 1;
                            proj_phase <= 0;
                        end
                    end else begin
                        state <= SORT;
                        pt_idx <= 0;
                        k <= 0;
                    end
                end

                SORT: begin
                    // Bubble Sort (Passes: 0 to N-2)
                    if (pt_idx < num_circles - 1) begin
                        // Inner loop (Index: 0 to N - 2 - pt_idx)
                        if (k < num_circles - 1 - pt_idx) begin
                            if (projections[k] > projections[k+1]) begin
                                projections[k] <= projections[k+1];
                                projections[k+1] <= projections[k];
                            end
                            k <= k + 1;
                        end else begin
                            // End of pass
                            pt_idx <= pt_idx + 1;
                            k <= 0;
                        end
                    end else begin
                        state <= COUNT;
                        pt_idx <= 0;
                        k <= 0;
                        max_count_dir <= 0;
                    end
                end

                COUNT: begin
                    // Sliding Window
                    if (pt_idx < num_circles) begin
                        if (k == pt_idx) begin
                            // Start of new window
                            current_count <= 1;
                            k <= pt_idx + 1;
                            // Handle single point case
                            if (pt_idx + 1 >= num_circles) begin
                                if (1 > max_count_dir) max_count_dir <= 1;
                                pt_idx <= pt_idx + 1;
                                k <= pt_idx + 1;
                            end
                        end else if (k < num_circles) begin
                            // Inner scan
                            if ($signed(projections[k]) <= ($signed(projections[pt_idx]) + window_width)) begin
                                current_count <= current_count + 1;
                                k <= k + 1;
                                if (k + 1 >= num_circles) begin
                                    if (current_count + 1 > max_count_dir) max_count_dir <= current_count + 1;
                                    pt_idx <= pt_idx + 1;
                                    k <= pt_idx + 1;
                                end
                            end else begin
                                // Window broken
                                if (current_count > max_count_dir) max_count_dir <= current_count;
                                pt_idx <= pt_idx + 1;
                                k <= pt_idx + 1;
                            end
                        end
                    end else begin
                        // Done all windows for this direction
                        if (max_count_dir > max_slices) begin
                            max_slices <= max_count_dir;
                        end
                        state <= NEXT_DIR;
                    end
                end

                NEXT_DIR: begin
                    // Prepare next direction
                    if (dir_idx == 15) begin
                        state <= DONE;
                    end else begin
                        dir_idx <= dir_idx + 1;
                        state <= COMPUTE_DIR;
                    end
                    // Reset per-direction registers
                    pt_idx <= 0;
                    k <= 0;
                    max_count_dir <= 0;
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule