module swap_numbers(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] out_first,
    output reg [7:0] out_second,
    output reg done
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_first <= 8'd0;
        out_second <= 8'd0;
        done <= 1'b0;
    end else if (start) begin
        out_first <= b;
        out_second <= a;
        done <= 1'b1;
    end else begin
        done <= 1'b0;
    end
end

endmodule