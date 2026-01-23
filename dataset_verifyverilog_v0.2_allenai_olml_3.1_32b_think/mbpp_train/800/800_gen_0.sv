module remove_all_spaces (
   input clk,
   input rst_n,
   input start,
   input [7:0] char_in,
   input input_valid,
   input input_done,
   output reg [7:0] output_char,
   output reg output_valid,
   output reg done
);

localparam BUFFER_SIZE = 16;

localparam IDLE = 3'd0,
        COLLECT = 3'd1,
        PROCESS = 3'd2,
        COMPLETE = 3'd3;

reg [3:0] write_ptr;
reg [3:0] read_ptr;
reg [7:0] buffer [0:BUFFER_SIZE-1];
reg [2:0] state;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      write_ptr <= 0;
      read_ptr <= 0;
      done <= 0;
      output_char <= 8'h00;
      output_valid <= 0;
   end else begin
      case (state)
         IDLE: begin
            output_valid <= 0;
            output_char <= 8'h00;
            if (start) begin
               state <= COLLECT;
               write_ptr <= 0;
               read_ptr <= 0;
            end
         end
         COLLECT: begin
            output_valid <= 0;
            output_char <= 8'h00;
            if (input_valid) begin
               if (write_ptr < BUFFER_SIZE) begin
                  buffer[write_ptr] <= char_in;
                  write_ptr <= write_ptr + 1;
               end
            end
            if (input_done) begin
               state <= PROCESS;
            end
         end
         PROCESS: begin
            output_valid <= 0;
            output_char <= 8'h00;
            if (read_ptr < write_ptr) begin
               if ( (buffer[read_ptr] == 9) || (buffer[read_ptr] == 10) || (buffer[read_ptr] == 13) || (buffer[read_ptr] == 32) ) begin
                  read_ptr <= read_ptr + 1;
               end
               else begin
                  output_char <= buffer[read_ptr];
                  output_valid <= 1;
                  read_ptr <= read_ptr + 1;
               end
            end
            else begin
               state <= COMPLETE;
               done <= 1;
            end
         end
         COMPLETE: begin
            output_valid <= 0;
            output_char <= 8'h00;
         end
      endcase
   end
end
endmodule