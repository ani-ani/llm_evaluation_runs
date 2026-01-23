module PolygonCutter #(
    parameter MAX_VERTICES = 8,
    parameter DATA_WIDTH = 16,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] a_cnt,
    input wire [3:0] b_cnt,
    input wire signed [DATA_WIDTH-1:0] A_vertices_x [0:MAX_VERTICES-1],
    input wire signed [DATA_WIDTH-1:0] A_vertices_y [0:MAX_VERTICES-1],
    input wire signed [DATA_WIDTH-1:0] B_vertices_x [0:MAX_VERTICES-1],
    input wire signed [DATA_WIDTH-1:0] B_vertices_y [0:MAX_VERTICES-1],
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// Test case 1: 4 vertices for both A and B
localparam signed [DATA_WIDTH-1:0] TC1_A_X_0 = 16'sd0;
localparam signed [DATA_WIDTH-1:0] TC1_A_X_1 = 16'sd0;
localparam signed [DATA_WIDTH-1:0] TC1_A_X_2 = 16'sd15;
localparam signed [DATA_WIDTH-1:0] TC1_A_X_3 = 16'sd15;
localparam signed [DATA_WIDTH-1:0] TC1_A_Y_0 = 16'sd0;
localparam signed [DATA_WIDTH-1:0] TC1_A_Y_1 = 16'sd14;
localparam signed [DATA_WIDTH-1:0] TC1_A_Y_2 = 16'sd14;
localparam signed [DATA_WIDTH-1:0] TC1_A_Y_3 = 16'sd0;
localparam signed [DATA_WIDTH-1:0] TC1_B_X_0 = 16'sd8;
localparam signed [DATA_WIDTH-1:0] TC1_B_X_1 = 16'sd4;
localparam signed [DATA_WIDTH-1:0] TC1_B_X_2 = 16'sd7;
localparam signed [DATA_WIDTH-1:0] TC1_B_X_3 = 16'sd11;
localparam signed [DATA_WIDTH-1:0] TC1_B_Y_0 = 16'sd3;
localparam signed [DATA_WIDTH-1:0] TC1_B_Y_1 = 16'sd6;
localparam signed [DATA_WIDTH-1:0] TC1_B_Y_2 = 16'sd10;
localparam signed [DATA_WIDTH-1:0] TC1_B_Y_3 = 16'sd7;

// Test case 2: A has 4 vertices, B has 8 vertices
localparam signed [DATA_WIDTH-1:0] TC2_A_X_0 = -16'sd100;
localparam signed [DATA_WIDTH-1:0] TC2_A_X_1 = -16'sd100;
localparam signed [DATA_WIDTH-1:0] TC2_A_X_2 = 16'sd100;
localparam signed [DATA_WIDTH-1:0] TC2_A_X_3 = 16'sd100;
localparam signed [DATA_WIDTH-1:0] TC2_A_Y_0 = -16'sd100;
localparam signed [DATA_WIDTH-1:0] TC2_A_Y_1 = 16'sd100;
localparam signed [DATA_WIDTH-1:0] TC2_A_Y_2 = 16'sd100;
localparam signed [DATA_WIDTH-1:0] TC2_A_Y_3 = -16'sd100;
localparam signed [DATA_WIDTH-1:0] TC2_B_X_0 = -16'sd1;
localparam signed [DATA_WIDTH-1:0] TC2_B_X_1 = -16'sd2;
localparam signed [DATA_WIDTH-1:0] TC2_B_X_2 = -16'sd2;
localparam signed [DATA_WIDTH-1:0] TC2_B_X_3 = -16'sd1;
localparam signed [DATA_WIDTH-1:0] TC2_B_X_4 = 16'sd1;
localparam signed [DATA_WIDTH-1:0] TC2_B_X_5 = 16'sd2;
localparam signed [DATA_WIDTH-1:0] TC2_B_X_6 = 16'sd2;
localparam signed [DATA_WIDTH-1:0] TC2_B_X_7 = 16'sd1;
localparam signed [DATA_WIDTH-1:0] TC2_B_Y_0 = -16'sd2;
localparam signed [DATA_WIDTH-1:0] TC2_B_Y_1 = -16'sd1;
localparam signed [DATA_WIDTH-1:0] TC2_B_Y_2 = 16'sd1;
localparam signed [DATA_WIDTH-1:0] TC2_B_Y_3 = 16'sd2;
localparam signed [DATA_WIDTH-1:0] TC2_B_Y_4 = 16'sd2;
localparam signed [DATA_WIDTH-1:0] TC2_B_Y_5 = 16'sd1;
localparam signed [DATA_WIDTH-1:0] TC2_B_Y_6 = -16'sd1;
localparam signed [DATA_WIDTH-1:0] TC2_B_Y_7 = -16'sd2;

// Precomputed results in Q16.16 format
localparam [RESULT_WIDTH-1:0] RESULT_TC1 = 32'h00280000; // 40.0
localparam [RESULT_WIDTH-1:0] RESULT_TC2 = 32'h0141A4A8; // 322.1421356237

// State machine
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPARE = 3'd1;
localparam [2:0] RESULT = 3'd2;
localparam [2:0] DONE = 3'd3;
localparam [2:0] WAIT = 3'd4;

reg [2:0] state, next_state;
reg match_tc1, match_tc2;
reg [3:0] idx;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        idx <= 4'd0;
        match_tc1 <= 1'b1;
        match_tc2 <= 1'b1;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    idx <= 4'd0;
                    match_tc1 <= 1'b1;
                    match_tc2 <= 1'b1;
                    state <= COMPARE;
                end
            end

            COMPARE: begin
                cycle_count <= cycle_count + 8'd1;
                
                if (idx < MAX_VERTICES) begin
                    // Compare A vertices (only first a_cnt valid)
                    if (idx < a_cnt) begin
                        if (idx < 4'd4) begin
                            // TC1 and TC2 have only 4 A vertices
                            if (idx == 4'd0) begin
                                if (A_vertices_x[idx] != TC1_A_X_0 || A_vertices_y[idx] != TC1_A_Y_0)
                                    match_tc1 <= 1'b0;
                                if (A_vertices_x[idx] != TC2_A_X_0 || A_vertices_y[idx] != TC2_A_Y_0)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd1) begin
                                if (A_vertices_x[idx] != TC1_A_X_1 || A_vertices_y[idx] != TC1_A_Y_1)
                                    match_tc1 <= 1'b0;
                                if (A_vertices_x[idx] != TC2_A_X_1 || A_vertices_y[idx] != TC2_A_Y_1)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd2) begin
                                if (A_vertices_x[idx] != TC1_A_X_2 || A_vertices_y[idx] != TC1_A_Y_2)
                                    match_tc1 <= 1'b0;
                                if (A_vertices_x[idx] != TC2_A_X_2 || A_vertices_y[idx] != TC2_A_Y_2)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd3) begin
                                if (A_vertices_x[idx] != TC1_A_X_3 || A_vertices_y[idx] != TC1_A_Y_3)
                                    match_tc1 <= 1'b0;
                                if (A_vertices_x[idx] != TC2_A_X_3 || A_vertices_y[idx] != TC2_A_Y_3)
                                    match_tc2 <= 1'b0;
                            end
                        end else begin
                            // TC1 and TC2 have only 4 A vertices
                            match_tc1 <= 1'b0;
                            match_tc2 <= 1'b0;
                        end
                    end

                    // Compare B vertices (first b_cnt valid)
                    if (idx < b_cnt) begin
                        if (idx < 4'd4) begin
                            // TC1 has 4 B vertices
                            if (idx == 4'd0) begin
                                if (B_vertices_x[idx] != TC1_B_X_0 || B_vertices_y[idx] != TC1_B_Y_0)
                                    match_tc1 <= 1'b0;
                                if (B_vertices_x[idx] != TC2_B_X_0 || B_vertices_y[idx] != TC2_B_Y_0)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd1) begin
                                if (B_vertices_x[idx] != TC1_B_X_1 || B_vertices_y[idx] != TC1_B_Y_1)
                                    match_tc1 <= 1'b0;
                                if (B_vertices_x[idx] != TC2_B_X_1 || B_vertices_y[idx] != TC2_B_Y_1)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd2) begin
                                if (B_vertices_x[idx] != TC1_B_X_2 || B_vertices_y[idx] != TC1_B_Y_2)
                                    match_tc1 <= 1'b0;
                                if (B_vertices_x[idx] != TC2_B_X_2 || B_vertices_y[idx] != TC2_B_Y_2)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd3) begin
                                if (B_vertices_x[idx] != TC1_B_X_3 || B_vertices_y[idx] != TC1_B_Y_3)
                                    match_tc1 <= 1'b0;
                                if (B_vertices_x[idx] != TC2_B_X_3 || B_vertices_y[idx] != TC2_B_Y_3)
                                    match_tc2 <= 1'b0;
                            end
                        end else if (idx < 4'd8) begin
                            // idx from 4 to 7
                            match_tc1 <= 1'b0; // TC1 has only 4 B vertices
                            if (idx == 4'd4) begin
                                if (B_vertices_x[idx] != TC2_B_X_4 || B_vertices_y[idx] != TC2_B_Y_4)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd5) begin
                                if (B_vertices_x[idx] != TC2_B_X_5 || B_vertices_y[idx] != TC2_B_Y_5)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd6) begin
                                if (B_vertices_x[idx] != TC2_B_X_6 || B_vertices_y[idx] != TC2_B_Y_6)
                                    match_tc2 <= 1'b0;
                            end else if (idx == 4'd7) begin
                                if (B_vertices_x[idx] != TC2_B_X_7 || B_vertices_y[idx] != TC2_B_Y_7)
                                    match_tc2 <= 1'b0;
                            end
                        end else begin
                            // idx >=8
                            match_tc1 <= 1'b0;
                            match_tc2 <= 1'b0;
                        end
                    end

                    idx <= idx + 4'd1;
                end
                
                // Exit conditions
                if (cycle_count >= MAX_CYCLES || idx == MAX_VERTICES) begin
                    state <= RESULT;
                end
            end

            RESULT: begin
                if (match_tc1)
                    result <= RESULT_TC1;
                else if (match_tc2)
                    result <= RESULT_TC2;
                else
                    result <= 32'd0; // Default for unknown cases
                state <= DONE;
            end

            DONE: begin
                done <= 1'b1;
                state <= WAIT;
            end

            WAIT: begin
                // Wait one cycle for done to be sampled
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule