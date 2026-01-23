module swap_list (
   input clk,
   input rst_n, // active low reset
   input start,
   input [2:0] size,
   input [7:0] arr_in [0:7],
   output reg [7:0] arr_out [0:7],
   output reg done
);

// Internal registers
reg [2:0] state; // 0: IDLE, 1: PROCESSING, 2: DONE
reg [7:0] captured_arr [0:7];
reg [2:0] captured_size;

// Default values on reset
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= 3'b000;
      captured_arr <= 8'b0;
      captured_size <= 3'b000;
      arr_out <= 8'b0;
      done <= 1'b0;
   end else begin
      if (state == 3'b000) begin // IDLE state
          if (start) begin
             // Capture the input array and size
             captured_arr <= arr_in;
             captured_size <= size;
             state <= 3'b001; // Move to PROCESSING
          end
      end else if (state == 3'b001) begin // PROCESSING state
          // Copy the captured array to output
          arr_out <= captured_arr;
          // Swap first and last elements if size >=2
          if (captured_size >= 3'd2) begin
             arr_out[0] <= captured_arr[captured_size - 1];
             arr_out[captured_size - 1] <= captured_arr[0];
          end
          // Move to DONE and set done high
          done <= 1'b1;
          state <= 3'b010; // DONE
      end else if (state == 3'b010) begin // DONE state
          // Transition back to IDLE
          state <= 3'b000;
      end
   end
endmodule
