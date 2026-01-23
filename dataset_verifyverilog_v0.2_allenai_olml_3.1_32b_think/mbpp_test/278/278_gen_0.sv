module count_first_elements (
   input clk,
   input rst_n, // active low
   input start,
   input [7:0][1:0] data_types,
   output reg [3:0] result,
   output reg done
);

// Registers
reg [1:0] state; // 00:IDLE, 01:PROCESSING, 10:DONE
reg [3:0] count;
reg [3:0] index;
reg done_reg;

// Assign outputs
assign result = count;
assign done = done_reg;

always @(posedge clk) begin
   if (!rst_n) begin // active low reset
      state <= 2'b00;
      count <= 4'b0;
      index <= 4'b0;
      done_reg <= 1'b0;
   end else begin
      case (state)
         2'b00: // IDLE
            if (start) begin
               state <= 2'b01;
               count <= 4'b0;
               index <= 4'b0;
            end
            else begin
               state <= 2'b00;
            end
         2'b01: // PROCESSING
            if (index < 8) begin
               if (data_types[index] == 1) begin // found tuple
                  state <= 2'b10;
               end else begin // scalar
                  count <= count + 1;
                  index <= index + 1;
                  if (index == 8) begin
                     state <= 2'b10;
                  end else begin
                     state <= 2'b01;
                  end
               end
            end else begin // index >=8, all elements processed
               state <= 2'b10;
            end
         2'b10: // DONE
            done_reg <= 1'b1;
            state <= 2'b10; // stay in DONE
      endcase
   end
endmodule
