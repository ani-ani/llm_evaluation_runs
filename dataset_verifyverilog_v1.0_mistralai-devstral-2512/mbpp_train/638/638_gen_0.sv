module windchill_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] v,
    input wire signed [7:0] t,
    output reg signed [7:0] result,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Fixed-point constants (Q16.16)
    localparam [31:0] CONST_13_12 = 32'h000D1EB8;
    localparam [31:0] CONST_0_6215 = 32'h0009E5C2;
    localparam [31:0] CONST_11_37 = 32'h000B5D17;
    localparam [31:0] CONST_0_3965 = 32'h00066147;
    localparam [31:0] CONST_0_5 = 32'h00008000;

    // Lookup table for v^0.16 (Q16.16)
    localparam [31:0] LUT [0:15] = '{32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
                                      32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
                                      32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
                                      32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000};

    // Intermediate signals
    reg signed [31:0] t_fixed;
    reg signed [31:0] v_fixed;
    reg signed [31:0] v_exp;
    reg signed [31:0] term1;
    reg signed [31:0] term2;
    reg signed [31:0] term3;
    reg signed [31:0] term4;
    reg signed [31:0] windchill_fixed;
    reg signed [31:0] windchill_rounded;

    // Clamp inputs
    always @(*) begin
        if (t < -40) begin
            t_fixed = -40 << 16;
        end else if (t > 40) begin
            t_fixed = 40 << 16;
        end else begin
            t_fixed = t << 16;
        end
        
        if (v > 128) begin
            v_fixed = 128 << 16;
        end else begin
            v_fixed = v << 16;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            v_exp <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            term3 <= 32'd0;
            term4 <= 32'd0;
            windchill_fixed <= 32'd0;
            windchill_rounded <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute v^0.16 using LUT (simplified for this example)
                    // In a real implementation, you would use linear interpolation
                    v_exp <= LUT[v[7:4]];
                    
                    // Compute terms
                    term1 <= $signed({16'd0, t_fixed[31:16]}) * CONST_0_6215;
                    term2 <= $signed({16'd0, v_exp[31:16]}) * CONST_11_37;
                    term3 <= $signed({16'd0, t_fixed[31:16]}) * $signed({16'd0, v_exp[31:16]}) * CONST_0_3965;
                    
                    // Combine terms
                    windchill_fixed <= CONST_13_12 + term1 - term2 + term3;
                    
                    // Round to nearest integer
                    windchill_rounded <= windchill_fixed + CONST_0_5;
                    
                    // Saturate result to [-50, 50]
                    if (windchill_rounded[31:16] > 50) begin
                        result <= 8'd50;
                    end else if (windchill_rounded[31:16] < -50) begin
                        result <= 8'd-50;
                    end else begin
                        result <= windchill_rounded[31:16];
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule