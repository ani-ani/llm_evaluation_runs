module JumpCalculator (
    input clk,
    input rst_n,
    input start,
    input [15:0] step_a,
    input [15:0] step_b,
    input [15:0] d,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    
    reg [1:0] state;
    
    // Internal registers
    reg [15:0] a_reg;
    reg [15:0] b_reg;
    reg [15:0] d_reg;
    
    // Division variables
    reg [31:0] dividend;
    reg [31:0] divisor;
    reg [5:0] div_count;
    wire [31:0] quotient;
    wire [31:0] remainder;
    
    // Division algorithm (restoring division)
    reg [63:0] div_temp;
    reg [31:0] div_quotient;
    reg [31:0] div_remainder;
    reg div_done;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            a_reg <= 16'd0;
            b_reg <= 16'd0;
            d_reg <= 16'd0;
            div_count <= 6'd0;
            div_done <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Determine a and b
                        if (step_a <= step_b) begin
                            a_reg <= step_a;
                            b_reg <= step_b;
                        end else begin
                            a_reg <= step_b;
                            b_reg <= step_a;
                        end
                        d_reg <= d;
                        state <= CALC;
                        
                        // Initialize division
                        div_done <= 1'b0;
                        div_count <= 6'd0;
                        div_quotient <= 32'd0;
                        div_remainder <= 32'd0;
                    end
                end
                
                CALC: begin
                    // Check conditions based on a_reg, b_reg, d_reg
                    if (d_reg == 16'd0) begin
                        result <= 32'd0;
                        state <= OUTPUT;
                    end else if (d_reg == a_reg) begin
                        // Return 1 (in Q16.16: 1.0 = 32'h00010000)
                        result <= 32'h00010000;
                        state <= OUTPUT;
                    end else if (d_reg == b_reg) begin
                        // Return 1 (in Q16.16: 1.0 = 32'h00010000)
                        result <= 32'h00010000;
                        state <= OUTPUT;
                    end else if (d_reg < a_reg) begin
                        // Return 2 (in Q16.16: 2.0 = 32'h00020000)
                        result <= 32'h00020000;
                        state <= OUTPUT;
                    end else begin
                        // d >= b case: Compute (d + b - 1) / b
                        // Shift left by 16 for fixed-point (Q16.16)
                        // Numerator: (d_reg + b_reg - 1) << 16
                        dividend <= {d_reg + b_reg - 16'd1, 16'd0};
                        divisor <= {16'd0, b_reg};
                        
                        // Reset division state
                        div_quotient <= 32'd0;
                        div_remainder <= 32'd0;
                        div_temp <= 64'd0;
                        div_count <= 6'd0;
                        div_done <= 1'b0;
                        
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    // Perform division if needed (combinational in practice,
                    // but implemented sequentially here for synthesis)
                    if (!div_done && divisor != 32'd0) begin
                        if (div_count < 6'd32) begin
                            // Shift left remainder and dividend
                            div_temp <= {div_remainder[30:0], dividend[31], dividend[30:0], 1'b0};
                            
                            // Compare with divisor
                            if ({div_remainder[30:0], dividend[31]} >= divisor) begin
                                div_remainder <= {div_remainder[30:0], dividend[31]} - divisor;
                                div_quotient <= {div_quotient[30:0], 1'b1};
                            end else begin
                                div_quotient <= {div_quotient[30:0], 1'b0};
                            end
                            
                            dividend <= dividend << 1;
                            div_count <= div_count + 6'd1;
                        end else begin
                            // Division complete
                            result <= {16'd0, div_quotient};
                            div_done <= 1'b1;
                            done <= 1'b1;
                        end
                    end else if (div_done) begin
                        done <= 1'b1;
                    end
                    
                    // Return to IDLE after done is asserted
                    if (done) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule