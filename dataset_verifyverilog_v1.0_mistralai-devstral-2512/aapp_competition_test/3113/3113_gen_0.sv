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
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd600;

    // Triangle storage
    reg signed [3:0] setA_x1 [0:7], setA_y1 [0:7];
    reg signed [3:0] setA_x2 [0:7], setA_y2 [0:7];
    reg signed [3:0] setA_x3 [0:7], setA_y3 [0:7];
    reg signed [3:0] setB_x1 [0:7], setB_y1 [0:7];
    reg signed [3:0] setB_x2 [0:7], setB_y2 [0:7];
    reg signed [3:0] setB_x3 [0:7], setB_y3 [0:7];

    // Pixel computation
    reg [3:0] px, py;
    reg signed [15:0] area_diff;
    localparam [15:0] THRESHOLD = 16'd16;

    // Edge function computation
    reg signed [7:0] e1, e2, e3;
    reg signed [7:0] e1_a, e2_a, e3_a;
    reg signed [7:0] e1_b, e2_b, e3_b;
    reg [0:0] inside_a, inside_b;

    // Load counters
    reg [2:0] load_a_idx;
    reg [2:0] load_b_idx;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            same <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            area_diff <= 16'd0;
            px <= 4'd0;
            py <= 4'd0;
            load_a_idx <= 3'd0;
            load_b_idx <= 3'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_A;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_A: begin
                if (load_a_idx == setA_count - 1) begin
                    next_state = LOAD_B;
                end else begin
                    next_state = LOAD_A;
                end
            end

            LOAD_B: begin
                if (load_b_idx == setB_count - 1) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = LOAD_B;
                end
            end

            COMPUTE: begin
                if (px == 4'd15 && py == 4'd15) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load set A triangles
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_a_idx <= 3'd0;
        end else if (state == LOAD_A) begin
            setA_x1[load_a_idx] <= setA_tri_n[load_a_idx][3:0];
            setA_y1[load_a_idx] <= setA_tri_n[load_a_idx][7:4];
            setA_x2[load_a_idx] <= setA_tri_n[load_a_idx][11:8];
            setA_y2[load_a_idx] <= setA_tri_n[load_a_idx][15:12];
            setA_x3[load_a_idx] <= setA_tri_n[load_a_idx][19:16];
            setA_y3[load_a_idx] <= setA_tri_n[load_a_idx][23:20];
            load_a_idx <= load_a_idx + 3'd1;
        end
    end

    // Load set B triangles
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_b_idx <= 3'd0;
        end else if (state == LOAD_B) begin
            setB_x1[load_b_idx] <= setB_tri_n[load_b_idx][3:0];
            setB_y1[load_b_idx] <= setB_tri_n[load_b_idx][7:4];
            setB_x2[load_b_idx] <= setB_tri_n[load_b_idx][11:8];
            setB_y2[load_b_idx] <= setB_tri_n[load_b_idx][15:12];
            setB_x3[load_b_idx] <= setB_tri_n[load_b_idx][19:16];
            setB_y3[load_b_idx] <= setB_tri_n[load_b_idx][23:20];
            load_b_idx <= load_b_idx + 3'd1;
        end
    end

    // Pixel computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px <= 4'd0;
            py <= 4'd0;
        end else if (state == COMPUTE) begin
            // Compute for current pixel
            if (px == 4'd15) begin
                px <= 4'd0;
                if (py == 4'd15) begin
                    py <= 4'd0;
                end else begin
                    py <= py + 4'd1;
                end
            end else begin
                px <= px + 4'd1;
            end
        end
    end

    // Edge function computation for set A
    always @(*) begin
        if (state == COMPUTE) begin
            e1_a = (setA_x2[0] - setA_x1[0]) * (py - setA_y1[0]) - (setA_y2[0] - setA_y1[0]) * (px - setA_x1[0]);
            e2_a = (setA_x3[0] - setA_x2[0]) * (py - setA_y2[0]) - (setA_y3[0] - setA_y2[0]) * (px - setA_x2[0]);
            e3_a = (setA_x1[0] - setA_x3[0]) * (py - setA_y3[0]) - (setA_y1[0] - setA_y3[0]) * (px - setA_x3[0]);
            inside_a = (e1_a >= 0 && e2_a >= 0 && e3_a >= 0) || (e1_a <= 0 && e2_a <= 0 && e3_a <= 0);
        end else begin
            inside_a = 1'b0;
        end
    end

    // Edge function computation for set B
    always @(*) begin
        if (state == COMPUTE) begin
            e1_b = (setB_x2[0] - setB_x1[0]) * (py - setB_y1[0]) - (setB_y2[0] - setB_y1[0]) * (px - setB_x1[0]);
            e2_b = (setB_x3[0] - setB_x2[0]) * (py - setB_y2[0]) - (setB_y3[0] - setB_y2[0]) * (px - setB_x2[0]);
            e3_b = (setB_x1[0] - setB_x3[0]) * (py - setB_y3[0]) - (setB_y1[0] - setB_y3[0]) * (px - setB_x3[0]);
            inside_b = (e1_b >= 0 && e2_b >= 0 && e3_b >= 0) || (e1_b <= 0 && e2_b <= 0 && e3_b <= 0);
        end else begin
            inside_b = 1'b0;
        end
    end

    // Area difference accumulation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            area_diff <= 16'd0;
        end else if (state == COMPUTE) begin
            if (inside_a != inside_b) begin
                area_diff <= area_diff + 16'd1;
            end
        end
    end

    // Done signal and result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            same <= 1'b0;
        end else begin
            done <= (state == DONE_STATE);
            if (state == DONE_STATE) begin
                same <= (area_diff <= THRESHOLD);
            end
        end
    end

endmodule