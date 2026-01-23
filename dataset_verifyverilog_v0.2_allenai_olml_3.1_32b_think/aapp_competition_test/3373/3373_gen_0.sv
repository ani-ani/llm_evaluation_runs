module balanced_parentheses_solver (
input clk,
input rst_n,
input start,
input [5:0] num_pieces,
input [7:0][15:0] pieces,
output reg [9:0] max_length,
output reg done
);

reg [5:0] reg_num_pieces;
reg [7:0][15:0] reg_pieces;
reg [4:0] state;
reg [9:0] max_len;
reg done_reg;

always @(posedge clk) begin
  if (!rst_n) begin
    reg_num_pieces <= 6'd0;
    reg_pieces <= 8'd0;
    state <= 4'd0;
    max_len <= 10'd0;
    done_reg <= 1'b0;
  end else begin
    if (start) begin
      reg_num_pieces <= num_pieces;
      reg_pieces <= pieces;
      state <= 4'd1;  
    end
    if (state == 4'd1) begin
      state <= 4'd2;  
    end
    if (state == 4'd2) begin
      state <= 4'd4;  
    end
    if (state == 4'd4) begin
      done_reg <= 1'b1;
    end
  end
end

assign done = done_reg;
assign max_length = max_len;

endmodule