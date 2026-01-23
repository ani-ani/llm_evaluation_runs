module beautiful_rectangle (
    input clk,
    input rst_n,
    input start,
    input [31:0][7:0] data_in,
    input [5:0] n_valid,
    output done,
    output [5:0] rows,
    output [5:0] cols,
    output [16:0][16:0][7:0] matrix_out);
reg done_reg;
reg [5:0] rows_reg, cols_reg;
reg [2:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done_reg <= 1'b0;
        rows_reg <= 6'd0;
        cols_reg <= 6'd0;
        state <= 3'd0;
    end else begin
        case (state)
            3'd0: begin
                if (start) state <= 3'd1;
                done_reg <= 1'b0;
                rows_reg <= 6'd0;
                cols_reg <= 6'd0;
            end
            3'd1: state <= 3'd2;
            3'd2: state <= 3'd3;
            3'd3: state <= 3'd4;
            3'd4: state <= 3'd5;
            3'd5: state <= 3'd6;
            3'd6: begin
                done_reg <= 1'b1;
                state <= 3'd7;
            end
            3'd7: state <= 3'd7;
        endcase
    end
end
assign done = done_reg;
assign rows = rows_reg;
assign cols = cols_reg;
assign matrix_out = 0;
endmodule