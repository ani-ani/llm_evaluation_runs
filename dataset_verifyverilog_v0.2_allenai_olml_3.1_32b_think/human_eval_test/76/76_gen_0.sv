module simple_power (
   input clk,
   input rst_n, // active low reset
   input start,
   input [7:0] x,
   input [7:0] n,
   output reg result,
   output reg done
);

reg [31:0] current_power_reg;
reg [4:0] k_reg;
reg [31:0] x_reg;
reg [31:0] n_reg;
reg [1:0] state_reg;
reg result_reg;
reg done_reg;

always @(posedge clk) begin
   if (!rst_n) begin
      state_reg <= 2'b00;
      current_power_reg <= 32'd0;
      k_reg <= 5'd0;
      x_reg <= 32'd0;
      n_reg <= 32'd0;
      result_reg <= 1'b0;
      done_reg <= 1'b0;
   end else if (start) begin
      x_reg <= {24'b0, x};
      n_reg <= {24'b0, n};
      state_reg <= 2'b01;
      current_power_reg <= 32'd1;
      k_reg <= 5'd0;
      result_reg <= 1'b0;
      done_reg <= 1'b0;
   end else begin
      if (state_reg == 2'b00) begin
         state_reg <= 2'b00;
         result_reg <= 1'b0;
         done_reg <= 1'b0;
      end else if (state_reg == 2'b01) begin
         if (current_power_reg == x_reg) begin
            result_reg <= 1'b1;
            done_reg <= 1'b1;
            state_reg <= 2'b10;
         end else if (current_power_reg > x_reg) begin
            result_reg <= 1'b0;
            done_reg <= 1'b1;
            state_reg <= 2'b10;
         end else begin
            current_power_reg <= current_power_reg * n_reg;
            k_reg <= k_reg + 1;
            if (k_reg > 31) begin
               result_reg <= 1'b0;
               done_reg <= 1'b1;
               state_reg <= 2'b10;
            end else begin
               state_reg <= 2'b01;
            end
         end
      end else begin // state 10
         state_reg <= 2'b10;
         result_reg <= result_reg;
         done_reg <= 1'b1;
      end
   end
end

assign result = result_reg;
assign done = done_reg;

endmodule