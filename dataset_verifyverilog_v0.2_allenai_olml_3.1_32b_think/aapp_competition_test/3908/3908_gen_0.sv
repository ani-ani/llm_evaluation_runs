module secret_message (
   input clk,
   input rst_n,
   input start,
   input [7:0] char_in,
   input load,
   output reg [31:0] result,
   output reg done
);

reg [15:0] buffer;
reg [3:0] char_count;
reg [1:0] state;
parameter IDLE = 2'b00,
               PROCESSING = 2'b01,
               DONE = 2'b10;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      char_count <=0;
   end else begin
      case(state)
         IDLE: begin
            if (load) begin
               if (char_count <16) begin
                  buffer[char_count] <= char_in;
                  char_count <= char_count +1;
               end
            end
            if (start && char_count >0) begin
               state <= PROCESSING;
            end
         end
         PROCESSING: begin
            result <= 0;
            done <=1;
            state <= DONE;
         end
         DONE: begin
         end
      endcase
   end
end
endmodule