module find_polynomial (
    input clk,
    input rst_n,
    input start,
    input signed [59:0] p_in,
    input signed [11:0] k_in,
    output reg [11:0] coeff,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTE   = 2'd1;
    localparam [1:0] FINISH    = 2'd2;
    
    reg [1:0] state;
    reg signed [59:0] p_reg;
    reg signed [59:0] next_p_reg;
    reg signed [11:0] k_reg;
    reg signed [11:0] remainder_reg;
    reg [3:0] cycle_count;
    
    localparam [3:0] MAX_CYCLES = 4'd10;

    // Combinational logic for division and modulo
    wire signed [59:0] quotient;
    wire signed [11:0] remainder;
    wire signed [59:0] p_reg_neg;
    wire signed [59:0] p_reg_neg_add_one;
    wire signed [11:0] remainder_add_k;
    wire signed [59:0] quotient_neg;
    wire signed [59:0] quotient_neg_sub_one;
    
    // Computation for quotient and remainder
    assign quotient = p_reg / k_reg;
    assign remainder = p_reg % k_reg;
    
    // Pre-calculate values for next_p_reg
    assign p_reg_neg = -quotient;
    assign quotient_neg = -quotient;
    assign quotient_neg_sub_one = quotient_neg - 59'd1;
    assign p_reg_neg_add_one = -(quotient + 59'd1);
    
    // Pre-calculate remainder + k for comparison
    assign remainder_add_k = remainder + k_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            p_reg <= 60'sd0;
            k_reg <= 12'sd0;
            remainder_reg <= 12'sd0;
            coeff <= 12'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        p_reg <= p_in;
                        k_reg <= k_in;
                        remainder_reg <= 12'sd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (p_reg != 60'sd0) begin
                        if (remainder < 12'sd0) begin
                            // remainder < 0 case
                            coeff <= $unsigned(remainder_add_k);
                            p_reg <= p_reg_neg_add_one;
                        end else begin
                            // remainder >= 0 case
                            coeff <= $unsigned(remainder);
                            p_reg <= p_reg_neg;
                        end
                        valid <= 1'b1;
                        done <= 1'b0;
                    end else begin
                        // p_reg == 0, computation complete
                        state <= FINISH;
                        done <= 1'b0;
                        valid <= 1'b0;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        done <= 1'b0;
                        valid <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule