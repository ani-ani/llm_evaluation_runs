module hack_cows (
   input clk,
   input rst_n, // active low
   input start,
   input [3:0] str_len,
   input [15:0] binary_string,
   output reg [7:0] result,
   output reg done
);

localparam IDLE = 2'd0;
localparam SCAN_STRING = 2'd1;
localparam CALCULATE_RESULT = 2'd2;
localparam DONE_STATE = 2'd3;

reg [2:0] state;
reg [3:0] captured_str_len;
reg [15:0] captured_binary_string;
reg [15:0] scan_counter;
reg [15:0] transitions_count;
reg [15:0] adjacent_count;
reg [2:0] calc_counter;
reg [7:0] result_reg;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      captured_str_len <= 4'd0;
      captured_binary_string <= 16'd0;
      scan_counter <= 16'd0;
      transitions_count <= 16'd0;
      adjacent_count <= 16'd0;
      calc_counter <= 3'd0;
      result_reg <= 8'd0;
      result <= 8'd0;
      done <= 1'b0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               captured_str_len <= str_len;
               captured_binary_string <= binary_string;
               state <= SCAN_STRING;
               transitions_count <= 16'd0;
               adjacent_count <= 16'd0;
               scan_counter <= 16'd0;
               calc_counter <= 3'd0;
               result_reg <= 8'd0;
            end
         end
         SCAN_STRING: begin
            if (scan_counter < 16) begin
               integer i;
               i = scan_counter;
               if (i < captured_str_len) begin
                  bit current_bit;
                  current_bit = captured_binary_string[i];
                  if (i < captured_str_len - 1) begin
                     bit next_bit;
                     next_bit = captured_binary_string[i + 1];
                     if (current_bit != next_bit) begin
                        transitions_count <= transitions_count + 1;
                     end else begin
                        adjacent_count <= adjacent_count + 1;
                     end
                  end
               end
               scan_counter <= scan_counter + 1;
               state <= SCAN_STRING;
            end else begin
               state <= CALCULATE_RESULT;
            end
         end
         CALCULATE_RESULT: begin
            if (calc_counter < 3) begin
               if (calc_counter == 0) begin
                  integer min_val;
                  min_val = (adjacent_count >= 2) ? 2 : adjacent_count;
                  result_reg <= transitions_count + 1 + min_val;
               end
               calc_counter <= calc_counter + 1;
               state <= CALCULATE_RESULT;
            end else begin
               state <= DONE_STATE;
               result <= result_reg;
               done <= 1'b1;
            end
         end
         DONE_STATE: begin
            state <= DONE_STATE;
            done <= 1'b1;
         end
      endcase
   end
endmodule