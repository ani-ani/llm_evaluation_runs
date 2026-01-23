module house_purchase_counter (
   input clk,
   input rst_n,
   input start,
   input [7:0] L,
   input [7:0] R,
   output reg [31:0] result,
   output reg done
);

function automatic is_valid;
input [7:0] N;
reg [3:0] digit_count;
reg [3:0] lucky_count;
reg has_four;
reg [7:0] d;
reg [7:0] digit2, digit1, digit0;
digit2 = N / 100;
digit1 = (N /10) %10;
digit0 = N %10;

if (N ==0) begin
   has_four =0;
digit_count =1;
lucky_count =0;
is_valid = (2*lucky_count == digit_count);
   return;
end

has_four =0;
lucky_count =0;
digit_count =0;

if (digit2 !=0) begin
   digit_count =3;
   if (digit2 ==4 || digit1 ==4 || digit0 ==4) begin
      has_four =1;
   end
   if (digit2 ==6 || digit2 ==8) lucky_count++;
   if (digit1 ==6 || digit1 ==8) lucky_count++;
   if (digit0 ==6 || digit0 ==8) lucky_count++;
is_valid = !has_four && (2*lucky_count == digit_count);
   return;
elseif (digit1 !=0) begin
   digit_count =2;
   if (digit1 ==4 || digit0 ==4) begin
      has_four =1;
   end
   if (digit1 ==6 || digit1 ==8) lucky_count++;
   if (digit0 ==6 || digit0 ==8) lucky_count++;
is_valid = !has_four && (2*lucky_count == digit_count);
   return;
else begin
   digit_count =1;
   if (digit0 ==4) begin
      has_four =1;
   end
   if (digit0 ==6 || digit0 ==8) lucky_count++;
is_valid = !has_four && (2*lucky_count == digit_count);
   return;
end
end
endfunction

reg [8:0] counter;
reg [31:0] total;
reg [2:0] state;
localparam IDLE = 3'b000, COUNTING =3'b001, DONE=3'b010;

always @(posedge clk) begin
   if (!rst_n) begin
      counter <=9'd0;
total <=0;
state <= IDLE;
done <=0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               counter <=9'd0;
total <=0;
state <= COUNTING;
            end
            done <=0;
         end
         COUNTING: begin
            reg [7:0] current_num;
current_num = counter;
            if (current_num >= L && current_num <= R) begin
               if (is_valid(current_num)) begin
total <= total +1;
               end
            end

            reg [8:0] next_counter;
next_counter = counter +1;

            if (next_counter > 256) begin
               state <= DONE;
done <=1;
            end else begin
               counter <= next_counter;
state <= COUNTING;
done <=0;
            end
         end
         DONE: begin
            result <= total;
state <= DONE;
done <=1;
         end
      endcase
   end
end

endmodule