module binary_string_cost (
input clk,
input rst_n,
input start,
input [7:0] str_len,
input [7:0] char_in,
input valid_in,
output reg [31:0] result,
output reg done
);

localparam X_VAL = 10;
localparam Y_VAL = 1;

reg [7:0] data_count;
reg [1:0] state;
reg [7:0] group_count;
reg prev_bit;
reg [3:0] delay_counter;

always_ff @(posedge clk) begin
   if (!rst_n) begin
      data_count <= 8'd0;
      state <= 2'd0;
      group_count <= 8'd0;
      prev_bit <= 1'b1;
      delay_counter <= 4'd0;
      result <= 32'd0;
      done <= 1'b0;
   end else begin
      data_count <= data_count;
      state <= state;
      group_count <= group_count;
      prev_bit <= prev_bit;
      delay_counter <= delay_counter;
      result <= result;
      done <= done;
   end
end

always_comb begin
   result = 32'd0;
   done = 1'b0;
   state_next = state;

   if (valid_in && data_count < str_len) begin
      bit current_bit = char_in[0];
      if (current_bit == 0 && prev_bit == 1) begin
          group_count = group_count + 1;
      end
      prev_bit = current_bit;
      data_count = data_count + 1;
   end

   case (state)
      IDLE: begin
          if (start && data_count < str_len) begin
              state_next = READING;
          end else if (start && data_count == str_len) begin
              state_next = COMPUTING;
          end
      end
      READING: begin
          if (data_count == str_len) begin
              state_next = COMPUTING;
          end else begin
              state_next = READING;
          end
      end
      COMPUTING: begin
          if (delay_counter > 0) begin
              state_next = COMPUTING;
              delay_counter_next = delay_counter - 1;
          end else begin
              if (group_count == 0) begin
                  result = 32'd0;
              end else begin
                  result = group_count * Y_VAL;
              end
              done = 1'b1;
              state_next = DONE;
          end
      end
      DONE: begin
          state_next = DONE;
          done = 1'b1;
      end
   endcase
end

localparam IDLE = 2'd0,
        READING = 2'd1,
        COMPUTING = 2'd2,
        DONE = 2'd3;

endmodule