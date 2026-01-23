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
localparam [3:0] IDLE       = 4'd0;
localparam [3:0] CALC_IN    = 4'd1;
localparam [3:0] CALC_DIST0 = 4'd2;
localparam [3:0] CALC_DIST1 = 4'd3;
localparam [3:0] SQRT0      = 4'd4;
localparam [3:0] SQRT1      = 4'd5;
localparam [3:0] COMPARE    = 4'd6;
localparam [3:0] FINISH     = 4'd7;

reg [3:0] state, next_state;

// Inside flags
reg inside0, inside1;

// Distance squared registers
reg [15:0] dist_sq0, dist_sq1; // max 512
reg [15:0] height_sq0, height_sq1; // max 16129
reg [15:0] sum0, sum1; // max 16641
reg [31:0] sqrt_input; // {sum, 16'b0}
reg [15:0] sqrt_result; // distance * 256
reg sqrt_valid;
reg [2:0] sqrt_cnt; // counter for sqrt steps

// Candidate values
reg [15:0] cand_A, cand_B, cand_C; // slanted distances * 256
reg [15:0] min_val;

// Sqrt computation registers
reg [15:0] sqrt_reg; // temporary for algorithm
reg [15:0] sqrt_rem; // remainder
reg [4:0] sqrt_bit;  // bit counter
reg sqrt_active;

// Helper: compute dx, dy for a rectangle (combinational)
function [15:0] calc_dist_sq;
    input signed [7:0] x_min, x_max, y_min, y_max;
    reg signed [7:0] dx, dy;
    begin
        if ($signed(0) >= x_min && $signed(0) <= x_max && $signed(0) >= y_min && $signed(0) <= y_max) begin
            calc_dist_sq = 16'd0;
        end else begin
            dx = ($signed(0) < x_min) ? (x_min) : (($signed(0) > x_max) ? (-x_max) : 0);
            dy = ($signed(0) < y_min) ? (y_min) : (($signed(0) > y_max) ? (-y_max) : 0);
            calc_dist_sq = dx*dx + dy*dy;
        end
    end
endfunction

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

// Main datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        inside0 <= 1'b0;
        inside1 <= 1'b0;
        dist_sq0 <= 16'd0;
        dist_sq1 <= 16'd0;
        height_sq0 <= 16'd0;
        height_sq1 <= 16'd0;
        sum0 <= 16'd0;
        sum1 <= 16'd0;
        sqrt_input <= 32'd0;
        sqrt_result <= 16'd0;
        sqrt_valid <= 1'b0;
        sqrt_cnt <= 3'd0;
        cand_A <= 16'hFFFF;
        cand_B <= 16'hFFFF;
        cand_C <= 16'hFFFF;
        min_val <= 16'hFFFF;
        result <= 16'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                sqrt_valid <= 1'b0;
            end
            CALC_IN: begin
                // Determine inside flags
                inside0 <= ($signed(0) >= x0_min && $signed(0) <= x0_max && $signed(0) >= y0_min && $signed(0) <= y0_max);
                if (use_rect1) begin
                    inside1 <= ($signed(0) >= x1_min && $signed(0) <= x1_max && $signed(0) >= y1_min && $signed(0) <= y1_max);
                end else begin
                    inside1 <= 1'b0;
                end
                // Precompute height scaled by 256 for candidate C
                if (use_rect1) begin
                    cand_C <= h1_1 * 8'd256;
                end else begin
                    cand_C <= h1_0 * 8'd256;
                end
                sqrt_cnt <= 3'd0;
            end
            CALC_DIST0: begin
                if (!inside0) begin
                    dist_sq0 <= calc_dist_sq(x0_min, x0_max, y0_min, y0_max);
                    height_sq0 <= h0_0 * h0_0;
                end
            end
            CALC_DIST1: begin
                if (use_rect1 && inside0 && !inside1) begin
                    dist_sq1 <= calc_dist_sq(x1_min, x1_max, y1_min, y1_max);
                    height_sq1 <= h0_1 * h0_1;
                end
            end
            SQRT0: begin
                if (sqrt_cnt == 3'd0) begin
                    sum0 <= dist_sq0 + height_sq0;
                    sqrt_cnt <= sqrt_cnt + 3'd1;
                end else if (sqrt_cnt == 3'd1) begin
                    sqrt_input <= {sum0, 16'd0};
                    sqrt_cnt <= sqrt_cnt + 3'd1;
                end
                // sqrt_valid is handled by sqrt sequencer
                if (sqrt_valid) begin
                    sqrt_cnt <= 3'd0;
                end
            end
            SQRT1: begin
                if (sqrt_cnt == 3'd0) begin
                    sum1 <= dist_sq1 + height_sq1;
                    sqrt_cnt <= sqrt_cnt + 3'd1;
                end else if (sqrt_cnt == 3'd1) begin
                    sqrt_input <= {sum1, 16'd0};
                    sqrt_cnt <= sqrt_cnt + 3'd1;
                end
                if (sqrt_valid) begin
                    sqrt_cnt <= 3'd0;
                end
            end
            COMPARE: begin
                // Update candidates based on computed values
                if (!inside0) begin // region A exists
                    cand_A <= sqrt_result;
                end
                if (use_rect1 && inside0 && !inside1) begin // region B exists
                    cand_B <= sqrt_result;
                end
                // Compare and find minimum (sequentially for simple hardware)
                min_val <= cand_C;
                if (cand_A < min_val) min_val <= cand_A;
                if (cand_B < min_val) min_val <= cand_B;
            end
            FINISH: begin
                result <= min_val;
                done <= 1'b1;
            end
        endcase
    end
end

// Combinational sqrt sequencer (runs during SQRT states)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sqrt_active <= 1'b0;
        sqrt_reg <= 16'd0;
        sqrt_rem <= 16'd0;
        sqrt_bit <= 5'd0;
        sqrt_result <= 16'd0;
        sqrt_valid <= 1'b0;
    end else begin
        if (state == SQRT0 || state == SQRT1) begin
            if (!sqrt_active && !sqrt_valid) begin
                // Start new sqrt
                sqrt_active <= 1'b1;
                sqrt_reg <= 16'd0;
                sqrt_rem <= 16'd0;
                sqrt_bit <= 5'd15; // 16-bit result
                sqrt_valid <= 1'b0;
            end else if (sqrt_active) begin
                // One iteration per clock
                // Add two bits of input to remainder
                sqrt_rem <= (sqrt_rem << 2) | ((sqrt_input >> (sqrt_bit * 2)) & 2'd3);
                sqrt_reg <= sqrt_reg << 1;
                // Try to subtract (2*sqrt_reg + 1) from remainder
                if (sqrt_rem >= ((sqrt_reg << 1) + 16'd1)) begin
                    sqrt_rem <= sqrt_rem - ((sqrt_reg << 1) + 16'd1);
                    sqrt_reg <= sqrt_reg + 16'd1;
                end
                sqrt_bit <= sqrt_bit - 5'd1;
                if (sqrt_bit == 5'd0) begin
                    sqrt_active <= 1'b0;
                    sqrt_result <= sqrt_reg;
                    sqrt_valid <= 1'b1;
                end
            end
        end else begin
            sqrt_active <= 1'b0;
            sqrt_valid <= 1'b0;
        end
    end
end

endmodule