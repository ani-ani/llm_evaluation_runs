module array_rotator (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] n,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

reg [1:0] state;
reg [7:0] result_reg [0:7];
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        result_reg <= 8'b0;
        done_reg <= 1'b0;
    end else begin
        case (state)
            2'b00: begin
                if (start) begin
                    state <= 2'b01;
                    done_reg <= 1'b0;
                end else begin
                    state <= 2'b00;
                    done_reg <= 1'b0;
                end
            end
            2'b01: begin
                result_reg[0] = arr[(0 + n) % 8];
                result_reg[1] = arr[(1 + n) % 8];
                result_reg[2] = arr[(2 + n) % 8];
                result_reg[3] = arr[(3 + n) % 8];
                result_reg[4] = arr[(4 + n) % 8];
                result_reg[5] = arr[(5 + n) % 8];
                result_reg[6] = arr[(6 + n) % 8];
                result_reg[7] = arr[(7 + n) % 8];
                state <= 2'b00;
                done_reg <= 1'b1;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule