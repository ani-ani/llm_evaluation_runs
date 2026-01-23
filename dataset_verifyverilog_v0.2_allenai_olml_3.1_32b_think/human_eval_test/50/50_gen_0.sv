module caesar_decode (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [7:0] char_in,
   input char_valid,
   input char_done,
   output reg [7:0] char_out,
   output reg char_out_valid,
   output reg done
);

localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;

reg [1:0] state;
reg [7:0] next_output;
reg next_valid;
reg [7:0] final_output;
reg final_valid;
reg done_reg;
reg exit_flag;

function automatic [7:0] process_char;
   input [7:0] char_in;
begin
   if (char_in >= 8'h61 && char_in <= 8'h7a) begin
      integer val = char_in - 8'h61;
      val = (val + 21) % 26;
      process_char = 8'h61 + val;
   end else begin
      process_char = char_in;
   end
endfunction

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      next_output <= 8'b0;
      next_valid <= 1'b0;
      final_output <= 8'b0;
      final_valid <= 1'b0;
      done_reg <= 1'b0;
      exit_flag <= 1'b0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            state <= PROCESSING;
         end
      end else if (state == PROCESSING) begin
         if (char_valid) begin
            next_output <= process_char(char_in);
            next_valid <= 1'b1;
         end
         if (next_valid) begin
            final_output <= next_output;
            final_valid <= next_valid;
            next_valid <= 1'b0;
         end
         if (char_done) begin
            exit_flag <= 1'b1;
         end
         if (exit_flag) begin
            state <= IDLE;
            done_reg <= 1'b1;
            exit_flag <= 1'b0;
         end
      end
   end
end

assign char_out = final_output;
assign char_out_valid = final_valid;
assign done = done_reg;

endmodule