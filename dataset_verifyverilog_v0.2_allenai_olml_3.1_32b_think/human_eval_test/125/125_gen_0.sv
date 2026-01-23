module split_words (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [7:0] char_in,
   input [3:0] str_len,
   output reg [127:0] word0, word1, word2, word3,
   output reg [3:0] result_count,
   output reg result_is_count,
   output reg done
);

reg [15:0] buffer [0:15];
reg [3:0] char_count;
reg [3:0] target_length;
reg [2:0] state;
reg [3:0] result_count_int;
reg result_is_count_int;
reg done_int;

wire [3:0] lowercase_odd_count_w;
assign lowercase_odd_count_w = ( (buffer[0] >= 'a' && buffer[0] <= 'z') ? ( (buffer[0] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[1] >= 'a' && buffer[1] <= 'z') ? ( (buffer[1] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[2] >= 'a' && buffer[2] <= 'z') ? ( (buffer[2] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[3] >= 'a' && buffer[3] <= 'z') ? ( (buffer[3] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[4] >= 'a' && buffer[4] <= 'z') ? ( (buffer[4] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[5] >= 'a' && buffer[5] <= 'z') ? ( (buffer[5] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[6] >= 'a' && buffer[6] <= 'z') ? ( (buffer[6] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[7] >= 'a' && buffer[7] <= 'z') ? ( (buffer[7] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[8] >= 'a' && buffer[8] <= 'z') ? ( (buffer[8] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[9] >= 'a' && buffer[9] <= 'z') ? ( (buffer[9] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[10] >= 'a' && buffer[10] <= 'z') ? ( (buffer[10] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[11] >= 'a' && buffer[11] <= 'z') ? ( (buffer[11] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[12] >= 'a' && buffer[12] <= 'z') ? ( (buffer[12] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[13] >= 'a' && buffer[13] <= 'z') ? ( (buffer[13] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[14] >= 'a' && buffer[14] <= 'z') ? ( (buffer[14] - 'a') % 2 == 1 ? 1 : 0 ) : 0 ) + ( (buffer[15] >= 'a' && buffer[15] <= 'z') ? ( (buffer[15] - 'a') % 2 == 1 ? 1 : 0 ) : 0 );

always @(posedge clk) begin
   if (!rst_n) begin
      buffer <= 16'd0;
      char_count <= 4'd0;
      target_length <=4'd0;
      state <= 2'd0;
      result_count_int <=4'd0;
      result_is_count_int <=1'b0;
      done_int <=1'b0;
      word0 <= 128'd0;
      word1 <= 128'd0;
      word2 <= 128'd0;
      word3 <= 128'd0;
   end else begin
      case (state)
         2'd0: begin
            if (start) begin
               target_length <= str_len;
               char_count <=4'd0;
               state <= 2'd1;
            end
            else begin
               state <=2'd0;
            end
         end
         2'd1: begin
            if (char_count < target_length) begin
               buffer[char_count] <= char_in;
               char_count <= char_count +1;
               state <=2'd1;
            end else begin
               state <=2'd2;
            end
         end
         2'd2: begin
            reg [2:0] delim_type =2'd2;
            if (target_length >0) begin
               if (buffer[0] ==32) delim_type <=2'd0;
               else if (buffer[0]==44) delim_type <=2'd1;
            end
            if (delim_type ==2'd2) begin
               result_is_count_int <=1'b1;
               result_count_int <= lowercase_odd_count_w;
               state <=2'd3;
            end else begin
               reg [127:0] full_buffer_word;
               full_buffer_word = {buffer, {128 - 8*target_length}{1'b0}};
               word0 <= full_buffer_word;
               word1 <=128'd0;
               word2 <=128'd0;
               word3 <=128'd0;
               result_is_count_int <=1'b0;
               result_count_int <=4'd0;
               state <=2'd3;
            end
         end
         2'd3: begin
            state <=2'd4;
         end
         2'd4: begin
            state <=2'd5;
            done_int <=1'b1;
         end
         2'd5: begin
            state <=2'd5;
            done_int <=1'b1;
         end
      endcase
   end
end

assign word0 = word0;
assign word1 = word1;
assign word2 = word2;
assign word3 = word3;
assign result_count = result_count_int;
assign result_is_count = result_is_count_int;
assign done = done_int;

endmodule