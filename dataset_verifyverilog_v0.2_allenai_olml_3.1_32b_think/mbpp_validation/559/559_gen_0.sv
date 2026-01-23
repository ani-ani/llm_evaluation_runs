module max_subarray_sum (
   input clk,
   input rst_n, // active-low reset
   input start,
   input signed [7:0] data_in,
   input [2:0] index, // unused
   output reg signed [7:0] result,
   output reg done
);
reg [2:0] state;
reg [7:0] buffer [7:0];
reg signed [7:0] current_sum;
reg signed [7:0] max_sum;
reg [2:0] load_counter;
reg [2:0] process_counter;
always @(posedge clk) begin
   if (!rst_n) begin
      state <= 3'b000;
      load_counter <= 3'b000;
      process_counter <= 3'b000;
      buffer <= 8'b00000000;
      current_sum <= 8'b00000000;
      max_sum <= 8'b00000000;
   end else begin
      if (state == 3'b000) begin // IDLE
         if (start == 1) begin
            state <= 3'b001;
            load_counter <= 3'b000;
         end
      end else if (state == 3'b001) begin // LOAD
         if (load_counter == 3'b111) begin // 7
            buffer[load_counter] <= data_in;
            state <= 3'b010; // PROCESS
         end else begin
            buffer[load_counter] <= data_in;
            load_counter <= load_counter + 1;
         end
      end else if (state == 3'b010) begin // PROCESS
         // Update current_sum and max_sum
         current_sum <= ( (current_sum + buffer[process_counter]) < 0 ) ? 0 : (current_sum + buffer[process_counter]);
         max_sum <= ( ( (current_sum + buffer[process_counter]) <0 ) ? 0 : (current_sum + buffer[process_counter]) ) > max_sum ? ( (current_sum + buffer[process_counter]) <0 ) ? 0 : (current_sum + buffer[process_counter]) : max_sum;
         process_counter <= process_counter + 1;
         if (process_counter == 3'b111) begin // 7
            state <= 3'b011; // DONE
            result <= max_sum;
         end
      end else if (state == 3'b011) begin // DONE
         // No action
      end
   end
end
assign done = state == 3'b011;
endmodule