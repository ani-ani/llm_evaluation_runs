module true_false_hints (input clk, input rst_n, input start, input [7:0] n, input [7:0] m, input [2:0] hint_l [0:19], input [2:0] hint_r [0:19], input [0:0] hint_type [0:19], output reg [31:0] result, output reg done, output reg error);
reg [7:0] n_val;
reg [4:0] m_val;
reg [2:0] hint_l_reg [0:19];
reg [2:0] hint_r_reg [0:19];
reg [0:0] hint_type_reg [0:19];
reg [31:0] total;
reg [7:0] count;
reg [2:0] state;
reg [31:0] mod = 32'd1000000007;

always @(posedge clk or posedge rst_n) begin
  if (!rst_n) begin
    state <= 0;
    n_val <= 0;
    m_val <= 0;
    total <= 0;
    count <= 0;
    error <= 0;
    done <= 0;
    result <= 0;
    mod <= 32'd1000000007;
    for (int i=0; i<20; i++) begin
      hint_l_reg[i] <= 3'b000;
      hint_r_reg[i] <= 3'b000;
      hint_type_reg[i] <= 1'b0;
    end
  end else begin
    if (state == 0) begin
      if (start) state <= 1;
    end
  end
end

endmodule