module next_smallest_palindrome (
input clk,
input rst_n,
input start,
input [15:0] num_in,
output reg [15:0] result,
output reg done);

   reg [15:0] current_candidate;
   reg [15:0] result_candidate;
   reg found;
   reg [6:0] count;
   reg [15:0] initial_num;

   always_ff @(posedge clk) begin
      if (!rst_n) begin
         current_candidate <= 0;
         result_candidate <=0;
         found <=0;
         count <=0;
         initial_num <=0;
         result <=0;
         done <=0;
      end else begin
         if (start) begin
            if (initial_num == 0) begin
               initial_num <= num_in;
               current_candidate <= (num_in +1) % 65536;
            end
         end

         if (count == 64) begin
            if (initial_num == 65535) begin
               result <= 0;
            end else if (found) begin
               result <= result_candidate;
            end else begin
               result <= current_candidate -1;
            end
            done <=1;
         end else begin
            if (count < 64) begin
               count <= count +1;
               if (is_palindrome(current_candidate)) begin
                  if (initial_num !=65535 || current_candidate ==0) begin
                     result_candidate <= current_candidate;
                     found <=1;
                  end
               end
               current_candidate <= (current_candidate +1) % 65536;
            end
         end
      end
   end

   function automatic is_palindrome;
      input [15:0] num;
      automatic [4:0] digits [4:0];
      digits[0] = num % 10;
      num = num / 10;
      digits[1] = num % 10;
      num = num / 10;
      digits[2] = num % 10;
      num = num / 10;
      digits[3] = num % 10;
      num = num / 10;
      digits[4] = num % 10;
      if (num !=0) return 0;
      if (digits[4] !=0) return (digits[0]==digits[4] && digits[1]==digits[3]);
      else if (digits[3] !=0) return (digits[0]==digits[3] && digits[1]==digits[2]);
      else if (digits[2] !=0) return (digits[0]==digits[2]);
      else if (digits[1] !=0) return (digits[0]==digits[1]);
      else return 1;
   endfunction
endmodule