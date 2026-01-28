module TriangleSetEqualityDetector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [47:0] setA_tri_n [0:7],
    input wire [47:0] setB_tri_n [0:7],
    input wire [3:0] setA_count,
    input wire [3:0] setB_count,
    output reg same,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD_A  = 3'd1;
    localparam [2:0] LOAD_B  = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE    = 3'd4;
    localparam [2:0] STORE   = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] x_coord;          // 0..15
    reg [7:0] y_coord;          // 0..15
    reg [2:0] tri_idx;          // 0..7
    reg [15:0] diff_acc;        // Signed 16-bit accumulator
    reg signed [15:0] areaA;
    reg signed [15:0] areaB;
    reg signed [15:0] edgeA_sum;
    reg signed [15:0] edgeB_sum;
    reg signed [15:0] edgeA;
    reg signed [15:0] edgeB;
    reg [2:0] stage;            // 0-2 for edge functions
    reg signA, signB;           // Sign storage for comparison
    reg [7:0] cycle_count;      // Max 256 cycles for safety
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Constants
    localparam signed [7:0] MAX_COORD = 4'd15;
    localparam signed [15:0] THRESHOLD = 16'd16;

    // Triangle fields for current triangle
    reg signed [3:0] tri_x1, tri_y1, tri_x2, tri_y2, tri_x3, tri_y3;

    // Signed versions of pixel coordinates
    wire signed [7:0] px_signed = {4'd0, x_coord[3:0]};
    wire signed [7:0] py_signed = {4'd0, y_coord[3:0]};

    // Edge function intermediate calculations
    reg signed [15:0] edge_temp1;  // (x2-x1)*(py-y1) - (y2-y1)*(px-x1)
    reg signed [15:0] edge_temp2;
    reg signed [15:0] edge_temp3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            same <= 1'b0;
            done <= 1'b0;
            x_coord <= 8'd0;
            y_coord <= 8'd0;
            tri_idx <= 3'd0;
            diff_acc <= 16'd0;
            areaA <= 16'd0;
            areaB <= 16'd0;
            edgeA_sum <= 16'd0;
            edgeB_sum <= 16'd0;
            edgeA <= 16'd0;
            edgeB <= 16'd0;
            stage <= 3'd0;
            cycle_count <= 8'd0;
            tri_x1 <= 4'd0; tri_y1 <= 4'd0;
            tri_x2 <= 4'd0; tri_y2 <= 4'd0;
            tri_x3 <= 4'd0; tri_y3 <= 4'd0;
            edge_temp1 <= 16'd0;
            edge_temp2 <= 16'd0;
            edge_temp3 <= 16'd0;
            signA <= 1'b0;
            signB <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    x_coord <= 8'd0;
                    y_coord <= 8'd0;
                    tri_idx <= 3'd0;
                    diff_acc <= 16'd0;
                    areaA <= 16'd0;
                    areaB <= 16'd0;
                    edgeA_sum <= 16'd0;
                    edgeB_sum <= 16'd0;
                    edgeA <= 16'd0;
                    edgeB <= 16'd0;
                    stage <= 3'd0;
                end

                LOAD_A: begin
                    if (tri_idx < setA_count) begin
                        tri_x1 <= setA_tri_n[tri_idx][3:0];
                        tri_y1 <= setA_tri_n[tri_idx][7:4];
                        tri_x2 <= setA_tri_n[tri_idx][11:8];
                        tri_y2 <= setA_tri_n[tri_idx][15:12];
                        tri_x3 <= setA_tri_n[tri_idx][19:16];
                        tri_y3 <= setA_tri_n[tri_idx][23:20];
                        stage <= 3'd0;
                        edgeA_sum <= 16'd0;
                        edgeB_sum <= 16'd0;
                    end else begin
                        edgeA <= edgeA_sum;
                        edgeB <= edgeB_sum;
                        tri_idx <= 3'd0;
                    end
                end

                LOAD_B: begin
                    if (tri_idx < setB_count) begin
                        tri_x1 <= setB_tri_n[tri_idx][3:0];
                        tri_y1 <= setB_tri_n[tri_idx][7:4];
                        tri_x2 <= setB_tri_n[tri_idx][11:8];
                        tri_y2 <= setB_tri_n[tri_idx][15:12];
                        tri_x3 <= setB_tri_n[tri_idx][19:16];
                        tri_y3 <= setB_tri_n[tri_idx][23:20];
                        stage <= 3'd0;
                        edgeB_sum <= 16'd0;
                    end else begin
                        tri_idx <= 3'd0;
                    end
                end

                COMPUTE: begin
                    if (tri_idx < setA_count) begin
                        case (stage)
                            3'd0: begin
                                // Edge 1: (x2-x1)*(py-y1) - (y2-y1)*(px-x1)
                                edge_temp1 <= (signed'(tri_x2) - signed'(tri_x1)) * (py_signed - signed'(tri_y1)) -
                                             (signed'(tri_y2) - signed'(tri_y1)) * (px_signed - signed'(tri_x1));
                                stage <= 3'd1;
                            end
                            3'd1: begin
                                // Edge 2: (x3-x2)*(py-y2) - (y3-y2)*(px-x2)
                                edge_temp2 <= (signed'(tri_x3) - signed'(tri_x2)) * (py_signed - signed'(tri_y2)) -
                                             (signed'(tri_y3) - signed'(tri_y2)) * (px_signed - signed'(tri_x2));
                                stage <= 3'd2;
                            end
                            3'd2: begin
                                // Edge 3: (x1-x3)*(py-y3) - (y1-y3)*(px-x3)
                                edge_temp3 <= (signed'(tri_x1) - signed'(tri_x3)) * (py_signed - signed'(tri_y3)) -
                                             (signed'(tri_y1) - signed'(tri_y3)) * (px_signed - signed'(tri_x3));
                                stage <= 3'd3;
                            end
                            3'd3: begin
                                // Check if point is inside (all edges same sign)
                                signA <= (edge_temp1 >= 0) && (edge_temp2 >= 0) && (edge_temp3 >= 0);
                                stage <= 3'd4;
                            end
                            3'd4: begin
                                if (signA || ((edge_temp1 <= 0) && (edge_temp2 <= 0) && (edge_temp3 <= 0))) begin
                                    edgeA_sum <= edgeA_sum + 16'd1;
                                end
                                tri_idx <= tri_idx + 3'd1;
                                stage <= 3'd0;
                            end
                        endcase
                    end else if (tri_idx < setB_count) begin
                        case (stage)
                            3'd0: begin
                                edge_temp1 <= (signed'(tri_x2) - signed'(tri_x1)) * (py_signed - signed'(tri_y1)) -
                                             (signed'(tri_y2) - signed'(tri_y1)) * (px_signed - signed'(tri_x1));
                                stage <= 3'd1;
                            end
                            3'd1: begin
                                edge_temp2 <= (signed'(tri_x3) - signed'(tri_x2)) * (py_signed - signed'(tri_y2)) -
                                             (signed'(tri_y3) - signed'(tri_y2)) * (px_signed - signed'(tri_x2));
                                stage <= 3'd2;
                            end
                            3'd2: begin
                                edge_temp3 <= (signed'(tri_x1) - signed'(tri_x3)) * (py_signed - signed'(tri_y3)) -
                                             (signed'(tri_y1) - signed'(tri_y3)) * (px_signed - signed'(tri_x3));
                                stage <= 3'd3;
                            end
                            3'd3: begin
                                signB <= (edge_temp1 >= 0) && (edge_temp2 >= 0) && (edge_temp3 >= 0);
                                stage <= 3'd4;
                            end
                            3'd4: begin
                                if (signB || ((edge_temp1 <= 0) && (edge_temp2 <= 0) && (edge_temp3 <= 0))) begin
                                    edgeB_sum <= edgeB_sum + 16'd1;
                                end
                                tri_idx <= tri_idx + 3'd1;
                                stage <= 3'd0;
                            end
                        endcase
                    end else begin
                        // Accumulate difference
                        diff_acc <= diff_acc + ((edgeA_sum > edgeB_sum) ? (edgeA_sum - edgeB_sum) : (edgeB_sum - edgeA_sum));
                        tri_idx <= 3'd0;
                    end
                end

                STORE: begin
                    // Move to next pixel
                    if (x_coord < 8'd15) begin
                        x_coord <= x_coord + 8'd1;
                    end else begin
                        x_coord <= 8'd0;
                        if (y_coord < 8'd15) begin
                            y_coord <= y_coord + 8'd1;
                        end
                    end
                    edgeA_sum <= 16'd0;
                    edgeB_sum <= 16'd0;
                end

                DONE: begin
                    same <= (diff_acc <= THRESHOLD);
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_A;
            end
            LOAD_A: begin
                if (tri_idx < setA_count) next_state = COMPUTE;
                else next_state = LOAD_B;
            end
            LOAD_B: begin
                if (tri_idx < setB_count) next_state = COMPUTE;
                else next_state = COMPUTE;
            end
            COMPUTE: begin
                if (setA_count == 0 && setB_count == 0 && tri_idx == 0) begin
                    next_state = DONE;
                end else if (tri_idx >= setA_count && tri_idx >= setB_count) begin
                    if (x_coord == 8'd15 && y_coord == 8'd15) begin
                        next_state = DONE;
                    end else begin
                        next_state = STORE;
                    end
                end else if (stage == 3'd5) begin
                    next_state = LOAD_A;
                end
            end
            STORE: begin
                next_state = LOAD_A;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase

        // Cycle counter protection
        if (cycle_count >= MAX_CYCLES) begin
            next_state = DONE;
        end
    end

endmodule