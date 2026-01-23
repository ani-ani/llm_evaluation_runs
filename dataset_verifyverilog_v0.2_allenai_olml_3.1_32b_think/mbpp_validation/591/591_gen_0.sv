module swap_list (
    input clk,
    input rst_n,
    input start,
    input [4:0][7:0] data_in,
    output reg [4:0][7:0] data_out,
    output reg done
);

parameter N =5;

reg [1:0] state;
reg [4:0][7:0] data_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 2'b00;
        data_reg <= 0;
        data_out <= 0;
        done <=0;
    end else begin
        case(state)
            2'b00: begin
                if (start) begin
                    data_reg <= data_in;
                    state <= 2'b01;
                end
            end
            2'b01: begin
                data_out = { data_reg[N-1], data_reg[1], data_reg[2], data_reg[3], data_reg[0] };
                state <= 2'b10;
                done <= 1'b1;
            end
            2'b10: begin
                if (!start) begin
                    state <= 2'b00;
                    done <=0;
                end
            end
        endcase
    end
end

endmodule