module aesthetic_path_solver (
input clk,
input rst_n,
input start,
input [31:0] n,
output reg [31:0] result,
output reg done
);
localparam IDLE = 3'd0,
CHECK_2 =3'd1,
HANDLE_POW2=3'd2,
CHECK_ODD=3'd3,
VERIFY_POWER=3'd4,
ITERATE=3'd5,
DONE=3'd6;
reg [2:0] state;
reg [31:0] n_reg;
reg [31:0] result_reg;
reg done_reg;
reg [31:0] d_reg;
always_ff @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      n_reg <= 32'd0;
      result_reg <= 32'd0;
      done_reg <= 1'b0;
      d_reg <= 32'd0;
   end else begin
      state <= next_state;
      n_reg <= next_n_reg;
      result_reg <= next_result_reg;
      done_reg <= next_done_reg;
      d_reg <= next_d_reg;
   end
end
wire [2:0] next_state;
wire [31:0] next_n_reg;
wire [31:0] next_result_reg;
wire next_done_reg;
wire [31:0] next_d_reg;
assign next_n_reg = (state == IDLE && start) ? n : n_reg;
always_comb begin
   next_state = state;
   if (state == IDLE) begin
      if (start)
         next_state = CHECK_2;
   end else if (state == CHECK_2) begin
      if (n_reg == 1) begin
         next_state = DONE;
      end else if (n_reg % 2 == 0) begin
         next_state = HANDLE_POW2;
      end else begin
         next_state = CHECK_ODD;
      end
   end else if (state == HANDLE_POW2) begin
      next_state = DONE;
   end else if (state == CHECK_ODD) begin
      next_state = ITERATE;
   end else if (state == ITERATE) begin
      if (d_reg > 32'd46340) begin
         next_state = DONE;
      end else begin
         bit [31:0] d_sq = d_reg * d_reg;
         if (d_sq > n_reg) begin
            next_state = DONE;
         end else if (n_reg % d_reg == 0) begin
            next_state = VERIFY_POWER;
         end else begin
            next_state = ITERATE;
         end
      end
   end else if (state == VERIFY_POWER) begin
      next_state = DONE;
   end else if (state == DONE) begin
   end
end
always_comb begin
   next_result_reg = result_reg;
   if (state == CHECK_2 && n_reg == 1) begin
      next_result_reg = 32'd1;
   end else if (state == HANDLE_POW2) begin
      bit [31:0] temp = n_reg;
      bit [31:0] temp_minus = temp - 1;
      bit [31:0] and_result = temp & temp_minus;
      if (and_result == 32'd0) begin
         next_result_reg = 32'd2;
      end else begin
         next_result_reg = 32'd1;
      end
   end else if (state == ITERATE) begin
      if (d_reg > 32'd46340 || (d_reg * d_reg > n_reg)) begin
         next_result_reg = n_reg;
      end
   end else if (state == VERIFY_POWER) begin
      bit [31:0] temp = n_reg;
      bit [31:0] d = d_reg;
      if (temp % d != 0) begin
         next_result_reg = 32'd1;
      end else begin
         bit [31:0] temp_after = temp;
         while (temp_after % d == 0) begin
            temp_after = temp_after / d;
         end
         if (temp_after == 1) begin
            next_result_reg = d;
         end else begin
            next_result_reg = 32'd1;
         end
      end
   end
end
always_comb begin
   next_done_reg = done_reg;
   if (state == CHECK_2 && n_reg == 1) begin
      next_done_reg = 1'b1;
   end else if (state == HANDLE_POW2) begin
      next_done_reg = 1'b1;
   end else if (state == ITERATE) begin
      if (d_reg > 32'd46340 || (d_reg * d_reg > n_reg)) begin
         next_done_reg = 1'b1;
      end
   end else if (state == VERIFY_POWER) begin
      next_done_reg = 1'b1;
   end
end
always_comb begin
   next_d_reg = d_reg;
   if (state == CHECK_ODD) begin
      next_d_reg = 32'd3;
   end else if (state == ITERATE) begin
      if (n_reg % d_reg != 0) begin
         next_d_reg = d_reg + 2;
      end
   end
end
assign next_state = next_state;
assign next_n_reg = next_n_reg;
assign next_result_reg = next_result_reg;
assign next_done_reg = next_done_reg;
assign next_d_reg = next_d_reg;
endmodule