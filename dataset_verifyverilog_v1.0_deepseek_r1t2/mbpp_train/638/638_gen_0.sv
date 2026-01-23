module WindChillCalculator (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] temp_in,
    input [15:0] wind_in,
    output reg signed [15:0] result,
    output reg done
);
    // State declarations
    localparam [3:0] IDLE   = 4'd0;
    localparam [3:0] LOOKUP = 4'd1;
    localparam [3:0] MULT1  = 4'd2;
    localparam [3:0] MULT2  = 4'd3;
    localparam [3:0] MULT3  = 4'd4;
    localparam [3:0] MULT4  = 4'd5;
    localparam [3:0] ACCUM  = 4'd6;
    localparam [3:0] ROUND  = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;
    
    // Q16.16 constants
    localparam signed [31:0] CONST_13_12 = 32'h000D1F70;
    localparam signed [31:0] CONST_0_6215 = 32'h00009E5A;
    localparam signed [31:0] CONST_11_37 = 32'h000B5E85;
    localparam signed [31:0] CONST_0_3965 = 32'h0000659F;
    localparam signed [31:0] ROUNDING = 32'h00008000; // 0.5 in Q16.16
    
    reg [3:0] state;
    reg signed [31:0] temp_reg;
    reg [15:0] wind_reg;
    
    // Intermediate values
    reg signed [31:0] v_power;
    reg signed [31:0] term1, term2, term3;
    reg signed [31:0] product_t_v;
    reg signed [31:0] sum_total;
    reg signed [15:0] rounded_result;
    reg [7:0] cycle_count;
    
    // Power lookup table (v^0.16)
    reg signed [31:0] power_lut [0:255];
    
    // Initialize LUT with dummy values (must be precomputed)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 256; i = i + 1) begin
                power_lut[i] <= 32'd0; // Replace with actual Q16.16 values
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            temp_reg <= 32'd0;
            wind_reg <= 16'd0;
            v_power <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            term3 <= 32'd0;
            product_t_v <= 32'd0;
            sum_total <= 32'd0;
            rounded_result <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        temp_reg <= {temp_in, 16'd0}; // Convert temp to Q16.16
                        wind_reg <= wind_in;
                        state <= LOOKUP;
                    end
                end
                
                LOOKUP: begin
                    if (wind_reg == 16'd0) begin
                        v_power <= 32'd0;
                    end else begin
                        v_power <= power_lut[wind_reg[7:0]];
                    end
                    state <= MULT1;
                end
                
                MULT1: begin  // term1 = 0.6215 * t
                    term1 <= ($signed({temp_reg[31:16], 16'd0}) * CONST_0_6215) >>> 16;
                    state <= MULT2;
                end
                
                MULT2: begin  // term2 = -11.37 * v^0.16
                    term2 <= (CONST_11_37 * v_power) >>> 16;
                    state <= MULT3;
                end
                
                MULT3: begin  // product_t_v = t * v_power
                    product_t_v <= (temp_reg * v_power) >>> 16;
                    state <= MULT4;
                end
                
                MULT4: begin  // term3 = 0.3965 * product_t_v
                    term3 <= (CONST_0_3965 * product_t_v) >>> 16;
                    state <= ACCUM;
                end
                
                ACCUM: begin  // sum_total = 13.12 + term1 - term2 + term3
                    sum_total <= CONST_13_12 + term1 - term2 + term3;
                    state <= ROUND;
                end
                
                ROUND: begin
                    rounded_result <= (sum_total + ROUNDING) >>> 16; // Round to integer
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    // Clamp result (-80 to +50)
                    if (rounded_result < -80) begin
                        result <= -16'sd80;
                    end else if (rounded_result > 50) begin
                        result <= 16'sd50;
                    end else begin
                        result <= rounded_result;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule