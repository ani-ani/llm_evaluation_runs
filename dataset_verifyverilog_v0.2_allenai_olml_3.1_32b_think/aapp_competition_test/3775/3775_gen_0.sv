module deduce_common(input clk, input rst_n, input start, output reg [3:0] result, output reg done);

reg [2:0] state;
reg [3:0] result_reg;
reg done_reg;
reg [2:0] next_state;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'b000;
        result_reg <= 4'b0000;
        done_reg <= 1'b0;
    end else begin
        case (state)
            3'b000: begin
                if (start) next_state = 3'b001;
                else next_state = 3'b000;
            end
            3'b001: next_state = 3'b100;
            3'b100: next_state = 3'b100;
        endcase
        state <= next_state;

        if (state == 3'b100) begin
            result_reg <= 4'b0000;
            done_reg <= 1'b1;
        end
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule