module equation_solver (input clk, input rst_n, input start, input [63:0] a_in, input [7:0] s_in, output reg [255:0] result, output reg done);
reg [2:0] state;
reg [7:0] digits [7:0];
reg [255:0] result_reg;
reg done_reg;
reg [7:0] counter;
localparam IDLE = 3'b000, PARSE=3'b001, COMPUTE=3'b010, WAIT=3'b011, DONE=3'b100;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        digits <= 8'b0;
        result_reg <= 256'b0;
        done_reg <= 0;
        counter <= 8'b0;
    end else begin
        case(state)
            IDLE: begin
                if (start) state <= PARSE;
                else state <= IDLE;
            end
            PARSE: begin
                digits[0] = a_in[63:56] - 48;
                digits[1] = a_in[55:48] - 48;
                digits[2] = a_in[47:40] - 48;
                digits[3] = a_in[39:32] - 48;
                digits[4] = a_in[31:24] - 48;
                digits[5] = a_in[23:16] - 48;
                digits[6] = a_in[15:8]  - 48;
                digits[7] = a_in[7:0]   - 48;
                state <= COMPUTE;
            end
            COMPUTE: begin
                integer total = digits[0] + digits[1] + digits[2] + digits[3] + digits[4] + digits[5] + digits[6] + digits[7];
                if (total == s_in) begin
                    result_reg = 256'b0;
                    for (int i=0; i<7; i++) begin
                        result_reg = {result_reg, 8'h00 + digits[i] + 48, 8'h2B};
                    end
                    result_reg = {result_reg, 8'h00 + digits[7] + 48, 8'h3D};
                    integer s_tens = s_in / 10;
                    integer s_units = s_in % 10;
                    result_reg = {result_reg, 8'h00 + s_tens + 48, 8'h00 + s_units + 48};
                    state <= WAIT;
                    counter <= 99;
                } else begin
                    state <= WAIT;
                    counter <= 99;
                end
            end
            WAIT: begin
                if (counter == 0) begin
                    state <= DONE;
                    done_reg <= 1;
                end else begin
                    counter <= counter - 1;
                end
            end
            DONE: begin
                state <= DONE;
                done_reg <= 1;
            end
        endcase
    end
end
assign result = result_reg;
assign done = done_reg;
endmodule