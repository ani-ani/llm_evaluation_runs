module wind_chill(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] v,
    input wire signed [7:0] t,
    output reg signed [7:0] result,
    output reg valid,
    output reg done
);

// State declarations
localparam [3:0] IDLE = 4'd0;
localparam [3:0] CLAMP_T = 4'd1;
localparam [3:0] CLAMP_V = 4'd2;
localparam [3:0] LOOKUP_VPOW = 4'd3;
localparam [3:0] INTERPOLATE = 4'd4;
localparam [3:5] MULT_1 = 4'd5;
localparam [4:0] MULT_2 = 4'd6;
localparam [4:1] MULT_3 = 4'd7;
localparam [4:2] MULT_4 = 4'd8;
localparam [4:3] ADD_SUB = 4'd9;
localparam [4:4] ROUND = 4'd10;
localparam [4:5] SATURATE = 4'd11;
localparam [4:6] FINISH = 4'd12;

reg [3:0] state, next_state;
reg [2:0] cycle_count;

// Constants (Q16.16)
localparam [31:0] C_13_12 = 32'h000D1EB8;
localparam [31:0] C_0_6215 = 32'h0009E5C2;
localparam [31:0] C_11_37 = 32'h000B5D17;
localparam [31:0] C_0_3965 = 32'h00066147;
localparam [31:0] C_0_5 = 32'h00008000;

// Lookup table for v^0.16 (Q16.16)
// Index = v >> 3 (8 entries) + linear interpolation
// v^0.16 values for v = 0, 16, 32, 48, 64, 80, 96, 112, 128
// Approximate values scaled to Q16.16
localparam [31:0] VPOW_LUT [0:8] = '{
    32'h00010000,  // v=0: 1.0
    32'h00012000,  // v=16: 1.125
    32'h00013800,  // v=32: 1.21875
    32'h00014B00,  // v=48: 1.29297
    32'h00015B00,  // v=64: 1.35547
    32'h00016900,  // v=80: 1.41016
    32'h00017600,  // v=96: 1.46094
    32'h00018200,  // v=112: 1.50781
    32'h00018D00   // v=128: 1.55078
};

// Intermediate registers
reg signed [31:0] t_fp;
reg [31:0] v_fp;
reg [31:0] v_pow;
reg [31:0] v_pow_interp;
reg [63:0] mult_temp;
reg [31:0] mult_result;
reg signed [31:0] term1, term2, term3, term4;
reg signed [31:0] temp_sum;
reg signed [31:0] rounded;
reg signed [31:0] saturated;
reg signed [7:0] temp_result;

// LUT index and fraction for interpolation
reg [3:0] lut_idx;
reg [15:0] lut_frac;
reg [31:0] lut_val0, lut_val1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 8'sd0;
        valid <= 1'b0;
        done <= 1'b0;
        cycle_count <= 3'd0;
        t_fp <= 32'd0;
        v_fp <= 32'd0;
        v_pow <= 32'd0;
        v_pow_interp <= 32'd0;
        mult_temp <= 64'd0;
        mult_result <= 32'd0;
        term1 <= 32'd0;
        term2 <= 32'd0;
        term3 <= 32'd0;
        term4 <= 32'd0;
        temp_sum <= 32'd0;
        rounded <= 32'd0;
        saturated <= 32'd0;
        temp_result <= 8'sd0;
        lut_idx <= 4'd0;
        lut_frac <= 16'd0;
        lut_val0 <= 32'd0;
        lut_val1 <= 32'd0;
    end else begin
        cycle_count <= cycle_count + 3'd1;
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                cycle_count <= 3'd0;
                if (start) begin
                    state <= CLAMP_T;
                end
            end

            CLAMP_T: begin
                // Clamp t to [-40, 40]
                if ($signed(t) < -8'sd40)
                    t_fp <= 32'sd(-40) << 16;
                else if ($signed(t) > 8'sd40)
                    t_fp <= 32'sd(40) << 16;
                else
                    t_fp <= { {16{t[7]}}, t, 16'd0 };  // Sign extend and shift
                state <= CLAMP_V;
            end

            CLAMP_V: begin
                // Clamp v to [0, 128]
                if (v > 8'd128)
                    v_fp <= 32'd128 << 16;
                else
                    v_fp <= { 24'd0, v, 8'd0 };  // Zero extend and shift
                state <= LOOKUP_VPOW;
            end

            LOOKUP_VPOW: begin
                // Get LUT index and fraction for interpolation
                // v_fp >> 19 gives index (v / 16), lower 16 bits are fraction
                lut_idx <= v_fp[19:16];
                lut_frac <= v_fp[15:0];
                lut_val0 <= VPOW_LUT[v_fp[19:16]];
                lut_val1 <= VPOW_LUT[v_fp[19:16] + 4'd1];
                state <= INTERPOLATE;
            end

            INTERPOLATE: begin
                // Linear interpolation: val0 + (val1 - val0) * frac
                // Simplified: use fixed interpolation for 16 entries
                // For simplicity, just use the LUT value directly (already coarse)
                v_pow_interp <= lut_val0;
                state <= MULT_1;
            end

            MULT_1: begin
                // term1 = 0.6215 * t
                mult_temp <= C_0_6215 * t_fp;
                state <= MULT_2;
            end

            MULT_2: begin
                mult_result <= mult_temp[47:16];  // Q16.16 result
                term2 <= mult_temp[47:16];
                state <= MULT_3;
            end

            MULT_3: begin
                // term3 = 11.37 * v^0.16
                mult_temp <= C_11_37 * v_pow_interp;
                state <= MULT_4;
            end

            MULT_4: begin
                mult_result <= mult_temp[47:16];
                term3 <= mult_temp[47:16];
                state <= ADD_SUB;
            end

            ADD_SUB: begin
                // windchill = 13.12 + term2 - term3 + term4
                // term4 = 0.3965 * t * v^0.16
                // We compute term4 here for simplicity
                mult_temp <= C_0_3965 * t_fp;
                // Also compute partial sum: 13.12 + term2
                temp_sum <= C_13_12 + term2;
                state <= ROUND;
            end

            ROUND: begin
                // Complete term4 calculation
                term4 <= mult_temp[47:16];
                // Final sum with -term3 + term4
                temp_sum <= temp_sum - term3 + mult_temp[47:16];
                // Add rounding constant
                rounded <= temp_sum - term3 + mult_temp[47:16] + C_0_5;
                state <= SATURATE;
            end

            SATURATE: begin
                // Extract integer part (bits [31:16]) and saturate to [-50, 50]
                if ($signed(rounded[47:16]) < -32'sd50)
                    saturated <= -32'sd50 << 16;
                else if ($signed(rounded[47:16]) > 32'sd50)
                    saturated <= 32'sd50 << 16;
                else
                    saturated <= rounded[47:16];
                state <= FINISH;
            end

            FINISH: begin
                // Convert to 8-bit signed output
                temp_result <= saturated[23:16];
                result <= saturated[23:16];
                valid <= 1'b1;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule