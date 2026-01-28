module min_slanted_distance (
    input wire clk,
    input wire rst_n,
    input wire start,
    // Rectangle 0 (outer)
    input wire [7:0] h0_0, h1_0,
    input wire signed [7:0] x0_min, x0_max, y0_min, y0_max,
    // Rectangle 1 (inner)
    input wire [7:0] h0_1, h1_1,
    input wire signed [7:0] x1_min, x1_max, y1_min, y1_max,
    input wire use_rect1,
    output reg [15:0] result,
    output reg done
);

// State machine definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] CALC_IN = 4'd1;
localparam [3:0] CALC_DIST0 = 4'd2;
localparam [3:0] CALC_DIST1 = 4'd3;
localparam [3:0] SQRT0 = 4'd4;
localparam [3:0] SQRT1 = 4'd5;
localparam [3:0] COMPARE = 4'd6;
localparam [3:0] FINISH = 4'd7;

reg [3:0] state, next_state;

// Inside flags
reg inside0, inside1;

// Distance squared registers
reg [15:0] dist_sq0, dist_sq1;
reg [15:0] height_sq0, height_sq1;
reg [15:0] sum0, sum1;

// Square root computation
reg [31:0] sqrt_input;
reg [15:0] sqrt_result;
reg sqrt_valid;
reg [4:0] sqrt_bit;
reg [15:0] sqrt_reg;
reg [15:0] sqrt_rem;
reg sqrt_active;

// Candidate values
reg [15:0] cand_A, cand_B, cand_C;
reg [15:0] min_val;

// Sequential state transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = CALC_IN;
        CALC_IN: next_state = CALC_DIST0;
        CALC_DIST0: if (!inside0) next_state = SQRT0; else next_state = CALC_DIST1;
        CALC_DIST1: if (use_rect1 && inside0 && !inside1) next_state = SQRT1; else next_state = COMPARE;
        SQRT0: if (sqrt_valid) next_state = (use_rect1 && inside0 && !inside1) ? CALC_DIST1 : COMPARE;
        SQRT1: if (sqrt_valid) next_state = COMPARE;
        COMPARE: next_state = FINISH;
        FINISH: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        inside0 <= 0;
        inside1 <= 0;
        dist_sq0 <= 0;
        dist_sq1 <= 0;
        height_sq0 <= 0;
        height_sq1 <= 0;
        sum0 <= 0;
        sum1 <= 0;
        sqrt_input <= 0;
        sqrt_result <= 0;
        sqrt_valid <= 0;
        sqrt_bit <= 0;
        sqrt_reg <= 0;
        sqrt_rem <= 0;
        sqrt_active <= 0;
        cand_A <= 16'hFFFF;
        cand_B <= 16'hFFFF;
        cand_C <= 16'hFFFF;
        min_val <= 16'hFFFF;
        result <= 0;
        done <= 0;
    end else begin
        case (state)
            CALC_IN: begin
                inside0 <= ($signed(0) >= x0_min && $signed(0) <= x0_max && $signed(0) >= y0_min && $signed(0) <= y0_max);
                if (use_rect1) begin
                    inside1 <= ($signed(0) >= x1_min && $signed(0) <= x1_max && $signed(0) >= y1_min && $signed(0) <= y1_max);
                end else begin
                    inside1 <= 0;
                end
                if (use_rect1) begin
                    cand_C <= h1_1 * 8'd256;
                end else begin
                    cand_C <= h1_0 * 8'd256;
                end
            end
            CALC_DIST0: begin
                if (!inside0) begin
                    // Compute distance squared for rectangle 0
                    reg signed [7:0] dx0, dy0;
                    if ($signed(0) < x0_min) begin
                        dx0 = x0_min - 0;
                    end else if ($signed(0) > x0_max) begin
                        dx0 = 0 - x0_max;
                    end else begin
                        dx0 = 0;
                    end
                    if ($signed(0) < y0_min) begin
                        dy0 = y0_min - 0;
                    end else if ($signed(0) > y0_max) begin
                        dy0 = 0 - y0_max;
                    end else begin
                        dy0 = 0;
                    end
                    dist_sq0 <= dx0*dx0 + dy0*dy0;
                    height_sq0 <= h0_0 * h0_0;
                end
            end
            CALC_DIST1: begin
                if (use_rect1 && inside0 && !inside1) begin
                    // Compute distance squared for rectangle 1
                    reg signed [7:0] dx1, dy1;
                    if ($signed(0) < x1_min) begin
                        dx1 = x1_min - 0;
                    end else if ($signed(0) > x1_max) begin
                        dx1 = 0 - x1_max;
                    end else begin
                        dx1 = 0;
                    end
                    if ($signed(0) < y1_min) begin
                        dy1 = y1_min - 0;
                    end else if ($signed(0) > y1_max) begin
                        dy1 = 0 - y1_max;
                    end else begin
                        dy1 = 0;
                    end
                    dist_sq1 <= dx1*dx1 + dy1*dy1;
                    height_sq1 <= h0_1 * h0_1;
                end
            end
            SQRT0: begin
                if (!sqrt_active && !sqrt_valid) begin
                    sum0 <= dist_sq0 + height_sq0;
                    sqrt_input <= {sum0, 16'd0};
                    sqrt_active <= 1;
                    sqrt_bit <= 15;
                    sqrt_reg <= 0;
                    sqrt_rem <= 0;
                end
            end
            SQRT1: begin
                if (!sqrt_active && !sqrt_valid) begin
                    sum1 <= dist_sq1 + height_sq1;
                    sqrt_input <= {sum1, 16'd0};
                    sqrt_active <= 1;
                    sqrt_bit <= 15;
                    sqrt_reg <= 0;
                    sqrt_rem <= 0;
                end
            end
            COMPARE: begin
                if (!inside0) begin
                    cand_A <= sqrt_result;
                end
                if (use_rect1 && inside0 && !inside1) begin
                    cand_B <= sqrt_result;
                end
                min_val <= cand_C;
                if (cand_A < min_val) min_val <= cand_A;
                if (cand_B < min_val) min_val <= cand_B;
            end
            FINISH: begin
                result <= min_val;
                done <= 1;
            end
            IDLE: begin
                done <= 0;
            end
        endcase
    end
end

// Square root computation (sequential)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sqrt_active <= 0;
        sqrt_reg <= 0;
        sqrt_rem <= 0;
        sqrt_bit <= 0;
        sqrt_result <= 0;
        sqrt_valid <= 0;
    end else begin
        if (sqrt_active) begin
            sqrt_rem <= (sqrt_rem << 2) | ((sqrt_input >> (sqrt_bit*2)) & 2'd3);
            sqrt_reg <= sqrt_reg << 1;
            if (sqrt_rem >= (2*sqrt_reg + 1)) begin
                sqrt_rem <= sqrt_rem - (2*sqrt_reg + 1);
                sqrt_reg <= sqrt_reg + 1;
            end
            sqrt_bit <= sqrt_bit - 1;
            if (sqrt_bit == 0) begin
                sqrt_active <= 0;
                sqrt_result <= sqrt_reg;
                sqrt_valid <= 1;
            end
        end
    end
end

endmodule