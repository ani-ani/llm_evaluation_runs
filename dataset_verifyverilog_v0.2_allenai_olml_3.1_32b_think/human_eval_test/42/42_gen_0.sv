module incr_list (
input clk,
input rst_n,
input start,
input [2:0] length,
input [7:0] data_in,
input data_in_valid,
output reg [7:0] data_out,
output reg data_out_valid,
output reg done);

// Internal registers
reg [1:0] state;
reg [2:0] length_reg;
reg [2:0] element_count;
reg [2:0] output_index;
reg [7:0] data_array [7:0];

parameter IDLE = 2'b00;
parameter PROCESSING = 2'b01;
parameter DONE = 2'b10;

// Default assignments
always @(*) begin
   state <= IDLE;
   length_reg <= 3'b000;
   element_count <= 3'b000;
   output_index <= 3'b000;
   // data_array is initialized to 0 by default
end

// State machine and control logic
always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      length_reg <= 3'b000;
      element_count <= 3'b000;
      output_index <= 3'b000;
   end else begin
      if (state == IDLE) begin
          if (start) begin
              length_reg <= length;
              element_count <= 3'b000;
              output_index <= 3'b000;
              state <= PROCESSING;
          end
          // Ensure outputs are 0 in IDLE
          data_out <= 8'b00000000;
          data_out_valid <= 1'b0;
      end else if (state == PROCESSING) begin
          if (element_count < length_reg) begin
              // Collection phase
              if (data_in_valid) begin
                  data_array[element_count] <= data_in;
                  element_count <= element_count + 1;
              end
              // No output during collection
              data_out <= 8'b00000000;
              data_out_valid <= 1'b0;
          end else begin
              // Output phase
              if (output_index < length_reg) begin
                  data_out <= data_array[output_index] + 1;
                  data_out_valid <= 1'b1;
                  output_index <= output_index + 1;
              end else begin
                  // All outputs done
                  data_out <= 8'b00000000;
                  data_out_valid <= 1'b0;
                  done <= 1'b1;
                  state <= DONE;
              end
          end
      end else if (state == DONE) begin
          // Remain in DONE, keep done high
          data_out <= 8'b00000000;
          data_out_valid <= 1'b0;
      end
   end
endmodule