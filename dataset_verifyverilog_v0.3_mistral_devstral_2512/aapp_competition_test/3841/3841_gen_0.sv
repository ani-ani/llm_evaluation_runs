module find_polynomial (
    input clk,
    input rst_n,
    input start,
    input [59:0] p_in,
    input [11:0] k_in,
    output reg [11:0] coeff,
    output reg valid,
    output reg done
);

// States
localparam [0:0] IDLE = 1'b0;
localparam [0:0] COMPUTE = 1'b1;

reg [0:0] state;
reg signed [59:0] p_reg;
reg signed [11:0] k_reg;

// Combinational quotient and remainder
wire signed [59:0] quotient;
wire signed [11:0] remainder;

assign quotient = p_reg / k_reg;
assign remainder = p_reg % k_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        p_reg <= 60'd0;
        k_reg <= 12'd0;
        coeff <= 12'd0;
        valid <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    p_reg <= $signed(p_in);
                    k_reg <= $signed(k_in);
                    done <= 1'b0;
                    valid <= 1'b0;
                    state <= COMPUTE;
                end
            end
            COMPUTE: begin
                if (p_reg != 60'd0) begin
                    if (remainder < 12'd0) begin
                        coeff <= $unsigned(remainder + k_reg);
                        p_reg <= - (quotient + 60'd1);
                    end else begin
                        coeff <= $unsigned(remainder);
                        p_reg <= - quotient;
                    end
                    valid <= 1'b1;
                    done <= 1'b0;
                end else begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    state <= IDLE;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule