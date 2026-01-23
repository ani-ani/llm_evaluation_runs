module house_puzzle(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n,
    input wire [3:0] k,
    output reg [29:0] result,
    output reg done
);
    parameter MOD = 30'd1000000007;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_A = 4'd1;
    localparam [3:0] EXP_START = 4'd2;
    localparam [3:0] EXP_CHECK = 4'd3;
    localparam [3:0] EXP_MULT = 4'd4;
    localparam [3:0] EXP_MULT_RESULT = 4'd5;
    localparam [3:0] EXP_SQUARE = 4'd6;
    localparam [3:0] EXP_SQUARE_RESULT = 4'd7;
    localparam [3:0] MULT_RESULT = 4'd8;
    localparam [3:0] FINISHED = 4'd9;
    
    reg [3:0] state;
    reg [29:0] a_result, b_result;
    reg [29:0] exp_base, exp_exp, exp_result;
    reg [29:0] mul_a, mul_b;
    
    // Combinational multiply and mod
    wire [59:0] mul_product = mul_a * mul_b;
    wire [29:0] mul_result = mul_product % MOD;
    
    // k^(k-1) LUT (for k 1-8)
    wire [29:0] k_pow;
    assign k_pow = (k == 4'd1) ? 30'd1 :
                  (k == 4'd2) ? 30'd2 :
                  (k == 4'd3) ? 30'd9 :
                  (k == 4'd4) ? 30'd64 :
                  (k == 4'd5) ? 30'd625 :
                  (k == 4'd6) ? 30'd7776 :
                  (k == 4'd7) ? 30'd117649 :
                  (k == 4'd8) ? 30'd2097152 : 30'd0;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 30'd0;
            a_result <= 30'd0;
            b_result <= 30'd0;
            exp_base <= 30'd0;
            exp_exp <= 30'd0;
            exp_result <= 30'd0;
            mul_a <= 30'd0;
            mul_b <= 30'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (k == 4'd0) begin  // Handle k=0 edge case
                            result <= 30'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= LOAD_A;
                        end
                    end
                end
                
                LOAD_A: begin
                    a_result <= k_pow;  // Set a_result = k^(k-1)
                    state <= EXP_START;
                end
                
                EXP_START: begin
                    exp_base <= (n - k);
                    exp_exp <= (n - k);
                    exp_result <= 30'd1;
                    state <= EXP_CHECK;
                end
                
                EXP_CHECK: begin
                    if (exp_exp == 30'd0) begin  // Exponentiation complete
                        b_result <= exp_result;
                        state <= MULT_RESULT;
                    end
                    else if (exp_exp[0]) begin  // LSB set -> multiply
                        state <= EXP_MULT;
                    end
                    else begin                // Square step
                        state <= EXP_SQUARE;
                    end
                end
                
                EXP_MULT: begin
                    mul_a <= exp_result;
                    mul_b <= exp_base;
                    state <= EXP_MULT_RESULT;
                end
                
                EXP_MULT_RESULT: begin
                    exp_result <= mul_result;
                    state <= EXP_SQUARE;
                end
                
                EXP_SQUARE: begin
                    mul_a <= exp_base;
                    mul_b <= exp_base;
                    state <= EXP_SQUARE_RESULT;
                end
                
                EXP_SQUARE_RESULT: begin
                    exp_base <= mul_result;
                    exp_exp <= exp_exp >> 1;  // Shift right for next iteration
                    state <= EXP_CHECK;
                end
                
                MULT_RESULT: begin
                    mul_a <= a_result;
                    mul_b <= b_result;
                    state <= FINISHED;
                end
                
                FINISHED: begin
                    result <= mul_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule