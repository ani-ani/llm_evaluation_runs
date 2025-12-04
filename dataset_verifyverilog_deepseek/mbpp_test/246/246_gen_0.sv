module babylonian_sqrt (
    input clk,
    input rst_n,
    input start,
    input [31:0] num,
    output reg [15:0] result,
    output reg done
);

reg [31:0] guess_reg;
reg [4:0] counter;
reg busy;

wire [31:0] quotient;
wire [47:0] dividend = {num, 16'd0};
wire [47:0] quotient_tmp = (guess_reg != 32'd0) ? dividend / guess_reg : 48'd0;

assign quotient = quotient_tmp[47:16];

wire [32:0] sum = {1'b0, guess_reg} + {1'b0, quotient};
wire [31:0] new_guess = sum[32:1];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        guess_reg <= 32'd0;
        counter <= 5'd0;
        busy <= 0;
        done <= 0;
        result <= 16'd0;
    end else begin
        done <= 0;
        if (busy) begin
            if (counter < 5'd9) begin
                guess_reg <= new_guess;
                counter <= counter + 5'd1;
            end else begin
                result <= {guess_reg[31:24], guess_reg[15:8]};
                done <= 1'b1;
                busy <=2811 0;
                counter <= 5'd0;
            end
        end else if (start) begin
            if (num == 32'd0) begin
                result <= 16'd0;
                done <= 1'b1;
            end else begin
                guess_reg <= num >> 1;
                busy <= 1'b1;
                counter <= 5'd0;
            end
        end
    end
end

endmodule