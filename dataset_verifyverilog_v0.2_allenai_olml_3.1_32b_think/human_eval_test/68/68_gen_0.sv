module pluck_module (
   input clk,
   input rst_n,
   input start,
   input [15:0] arr_in,
   input [3:0] arr_index,
   input valid_in,
   input last_in,
   output reg [31:0] result,
   output reg done,
   output reg ready
);

localparam IDLE = 3'd0, COLLECT = 3'd1, FINALIZE = 3'd2, DONE = 3'd3;

reg [15:0] smallest_value;
reg [3:0] smallest_index;
reg found;
reg [4:0] state;
reg [31:0] result_reg;
reg done;
reg ready;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      smallest_value <= 16'hFFFF;
      smallest_index <= 4'd0;
      found <= 1'b0;
      state <= IDLE;
      result_reg <= 0;
      done <= 1'b0;
      ready <= 1'b0;
   end else begin
      case (state)
         IDLE: begin
             if (start) begin
                 state <= COLLECT;
                 smallest_value <= 16'hFFFF;
                 smallest_index <= 4'd0;
                 found <= 1'b0;
                 result_reg <= 0;
                 done <= 1'b0;
                 ready <= 1'b1;
             end else begin
                 state <= IDLE;
                 ready <= 1'b0;
             end
         end
         COLLECT: begin
             if (valid_in && ready) begin
                 if (arr_in[0] == 0) begin
                     if (arr_in < smallest_value || (arr_in == smallest_value && arr_index < smallest_index)) begin
                         smallest_value <= arr_in;
                         smallest_index <= arr_index;
                         found <= 1'b1;
                     end
                 end
                 if (last_in) begin
                     state <= FINALIZE;
                     ready <= 1'b0;
                 end else begin
                     state <= COLLECT;
                     ready <= 1'b1;
                 end
             end else begin
                 state <= COLLECT;
                 ready <= 1'b1;
             end
         end
         FINALIZE: begin
             result_reg <= (found) ? {smallest_index, smallest_value} : 0;
             done <= 1'b1;
             state <= DONE;
         end
         DONE: begin
             state <= DONE;
         end
      endcase
      result <= result_reg;
   end
endmodule