module perfect_squares (
   input clk,
   input rst_n,
   input start,
   input [7:0] a,
   input [7:0] b,
   output reg [7:0] result,
   output reg [3:0] count,
   output reg done,
   output reg valid
);
reg [2:0] state;
reg [7:0] index;
reg [3:0] internal_count;
reg [7:0] result_array [7:0];
reg [2:0] result_ptr;
reg [3:0] j_counter;
reg is_square;
reg done_reg;
localparam IDLE = 3'd0;
localparam CHECK_NUMBER = 3'd1;
localparam FIND_SQUARE = 3'd2;
localparam STORE_RESULT = 3'd3;
localparam OUTPUT_RESULTS = 3'd4;
localparam DONE = 3'd5;
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      index <= 8'd0;
      internal_count <= 4'd0;
      result_array <= {8{8'b0}};
      result_ptr <= 3'd0;
      j_counter <= 4'd0;
      is_square <= 1'b0;
      done_reg <= 1'b0;
   end else begin
      case(state)
         IDLE: begin
             if (start) begin
                 state <= CHECK_NUMBER;
                 index <= a;
                 internal_count <= 4'd0;
                 result_array <= {8{8'b0}};
                 result_ptr <= 3'd0;
                 j_counter <= 4'd0;
                 is_square <= 1'b0;
             end else begin
                 state <= IDLE;
             end
         end
         CHECK_NUMBER: begin
             if (index > b) begin
                 if (internal_count > 4'd0) begin
                     state <= OUTPUT_RESULTS;
                 end else begin
                     state <= DONE;
                 end
             end else begin
                 state <= FIND_SQUARE;
                 j_counter <= 4'd1;
                 is_square <= 1'b0;
             end
         end
         FIND_SQUARE: begin
             if (j_counter > 15) begin
                 if (is_square) begin
                     state <= STORE_RESULT;
                 end else begin
                     state <= CHECK_NUMBER;
                     index <= index + 1;
                 end
             end else begin
                 state <= FIND_SQUARE;
                 j_counter <= j_counter + 1;
                 if (j_counter * j_counter == index) begin
                     is_square <= 1'b1;
                 end
             end
         end
         STORE_RESULT: begin
             if (internal_count < 4'd8) begin
                 result_array[internal_count] <= index;
             end
             internal_count <= (internal_count < 4'd8) ? internal_count + 1 : 4'd8;
             index <= index + 1;
             state <= CHECK_NUMBER;
         end
         OUTPUT_RESULTS: begin
             if (result_ptr < internal_count) begin
                 state <= OUTPUT_RESULTS;
                 result_ptr <= result_ptr + 1;
             end else begin
                 state <= DONE;
                 done_reg <= 1'b1;
             end
         end
         DONE: begin
             state <= DONE;
         end
      endcase
   end
end
always @(*) begin
   count = internal_count;
   done = done_reg;
   if (state == OUTPUT_RESULTS) begin
      if (result_ptr < internal_count) begin
          result = result_array[result_ptr];
          valid = 1'b1;
      end else begin
          result = 8'b0;
          valid = 1'b0;
      end
   end else begin
      result = 8'b0;
      valid = 1'b0;
   end
end
endmodule