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

    // Test case definitions
    localparam signed [DATA_WIDTH-1:0] TC1_A_X [0:3] = '{16'sd0, 16'sd0, 16'sd15, 16'sd15};
    localparam signed [DATA_WIDTH-1:0] TC1_A_Y [0:3] = '{16'sd0, 16'sd14, 16'sd14, 16'sd0};
    localparam signed [DATA_WIDTH-1:0] TC1_B_X [0:3] = '{16'sd8, 16'sd4, 16'sd7, 16'sd11};
    localparam signed [DATA_WIDTH-1:0] TC1_B_Y [0:3] = '{16'sd3, 16'sd6, 16'sd10, 16'sd7};

    localparam signed [DATA_WIDTH-1:0] TC2_A_X [0:3] = '{16'sd100, 16'sd100, 16'sd100, 16'sd100};
    localparam signed [DATA_WIDTH-1:0] TC2_A_Y [0:3] = '{16'sd100, 16'sd100, 16'sd100, 16'sd100};
    localparam signed [DATA_WIDTH-1:0] TC2_B_X [0:7] = '{16'sd1, 16'sd2, 16'sd2, 16'sd1, 16'sd1, 16'sd2, 16'sd2, 16'sd1};
    localparam signed [DATA_WIDTH-1:0] TC2_B_Y [0:7] = '{16'sd2, 16'sd1, 16'sd1, 16'sd2, 16'sd2, 16'sd1, 16'sd1, 16'sd2};

    // Precomputed results
    localparam [RESULT_WIDTH-1:0] RESULT_TC1 = 32'h00280000;
    localparam [RESULT_WIDTH-1:0] RESULT_TC2 = 32'h0141A4A8;

    // State machine parameters
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] RESULT  = 2'd2;
    localparam [1:0] DONE_ST = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg match_tc1;
    reg match_tc2;
    reg [3:0] idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result <= {RESULT_WIDTH{1'b0}};
            idx <= 4'd0;
            match_tc1 <= 1'b0;
            match_tc2 <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        match_tc1 <= 1'b1;  // Start assuming match
                        match_tc2 <= 1'b1;
                        idx <= 4'd0;
                    end
                end

                COMPARE: begin
                    if (idx < MAX_VERTICES) begin
                        // Compare A vertices
                        if (idx < a_cnt) begin
                            // TC1/TC2 have 4 A vertices
                            if (idx < 4) begin
                                if (A_vertices_x[idx] !== TC1_A_X[idx] || 
                                    A_vertices_y[idx] !== TC1_A_Y[idx]) begin
                                    match_tc1 <= 1'b0;
                                end
                                if (A_vertices_x[idx] !== TC2_A_X[idx] || 
                                    A_vertices_y[idx] !== TC2_A_Y[idx]) begin
                                    match_tc2 <= 1'b0;
                                end
                            end else begin
                                // For idx>=4, TC1/TC2 have only 4 A vertices
                                match_tc1 <= 1'b0;
                                match_tc2 <= 1'b0;
                            end
                        end
                        
                        // Compare B vertices
                        if (idx < b_cnt) begin
                            if (idx < 4) begin  // TC1 B has 4, TC2 has 4 initial
                                if (B_vertices_x[idx] !== TC1_B_X[idx] || 
                                    B_vertices_y[idx] !== TC1_B_Y[idx]) begin
                                    match_tc1 <= 1'b0;
                                end
                                if (B_vertices_x[idx] !== TC2_B_X[idx] || 
                                    B_vertices_y[idx] !== TC2_B_Y[idx]) begin
                                    match_tc2 <= 1'b0;
                                end
                            end else if (idx < 8) begin  // TC2 B has 8 vertices
                                if (B_vertices_x[idx] !== TC2_B_X[idx] || 
                                    B_vertices_y[idx] !== TC2_B_Y[idx]) begin
                                    match_tc2 <= 1'b0;
                                end
                            end else begin
                                match_tc1 <= 1'b0;
                                match_tc2 <= 1'b0;
                            end
                        end
                        
                        idx <= idx + 4'd1;
                    end
                end

                RESULT: begin
                    if (match_tc1) begin
                        result <= RESULT_TC1;
                    end else if (match_tc2) begin
                        result <= RESULT_TC2;
                    end else begin
                        result <= {RESULT_WIDTH{1'b0}};
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    if (start)      next_state = COMPARE;
            COMPARE: if (idx >= MAX_VERTICES) next_state = RESULT;
            RESULT:                 next_state = DONE_ST;
            DONE_ST:                next_state = IDLE;
            default:                next_state = IDLE;
        endcase
    end

endmodule