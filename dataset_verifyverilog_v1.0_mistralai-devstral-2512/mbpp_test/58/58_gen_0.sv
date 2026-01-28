module opposite_signs(
    input clk,
    input rst_n,
    input start,
    input signed [31:0] x,
    input signed [31:0] y,
    output reg result,
    output reg done
);

    reg [31:0] x_reg;
    reg [31:0] y_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= 32'd0;
            y_reg <= 32'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            if (start) begin
                x_reg <= x;
                y_reg <= y;
            end
            
            result <= x_reg[31] ^ y_reg[31];
            done <= start;
        end
    end

endmodule