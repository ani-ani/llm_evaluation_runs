module probability_calculator (input clk, input rst_n, input start, input [19:0] g_mask, input [19:0] k_mask, input [7:0] g_len, input [7:0] k_len, input [15:0] p_fixed, output reg [31:0] result, output reg done);
reg [2:0] state;
reg [31:0] temp_result;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'b000;
        done <= 1'b0;
        result <= 32'd0;
    end else begin
        case (state)
            3'b000: if (start) state <= 3'b001;
            3'b001: state <= 3'b010;
            3'b010: state <= 3'b011;
            3'b011: state <= 3'b100;
            3'b100: begin done <=1'b1; result <=32'd0; end
            default: state <=3'b000;
        endcase
    end
end
endmodule