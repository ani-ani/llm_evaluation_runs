module count_vowels (
   input clk,
   input rst_n, // active low
   input start,
   input [5:0] str_len,
   input [127:0] str_data,
   output reg [5:0] result,
   output reg done
);

localparam MAX_LEN =16;

function automatic bit is_vowel;
   input [7:0] c;
   begin
      is_vowel = (c == 8'h61 || c ==8'h65 || c ==8'h69 || c ==8'h6F || c ==8'h75);
   end
endfunction

wire [5:0] total_count;
assign total_count =0;
generate
   for (integer i=0; i<MAX_LEN; i++) begin: sum_loop
      wire [7:0] c_i = str_data[(i*8 +7): i*8];
      wire is_vowel_i = is_vowel(c_i);
      wire contribute =1'b0;
      if (i < str_len) begin
         if (!is_vowel_i) begin
            if (i ==0) begin
               if (str_len >1) begin
                  wire [7:0] c_next = str_data[15:8];
                  contribute = is_vowel(c_next);
               end
            end else if (i == str_len-1) begin
               if (str_len >1) begin
                  wire [7:0] c_prev = str_data[((i-1)*8 +7): (i-1)*8];
                  contribute = is_vowel(c_prev);
               end
            end else begin
               wire [7:0] c_prev = str_data[((i-1)*8 +7): (i-1)*8];
               wire [7:0] c_next = str_data[((i+1)*8 +7): (i+1)*8];
               contribute = is_vowel(c_prev) || is_vowel(c_next);
            end
         end
      end
      total_count = total_count + contribute;
   end
endgenerate

typedef enum {IDLE=2'd0, CHECK=2'd1, DONE=2'd2} state_t;
reg state_t state;
reg [5:0] result_reg;
reg [4:0] count_down;
reg done_reg; // optional, but let's use it

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      result_reg <=0;
      count_down <=0;
      done_reg <=0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               state <= CHECK;
               result_reg <= total_count;
               count_down <= 17; // 18 cycles total
            end else begin
               state <= IDLE;
            end
         end
         CHECK: begin
            if (count_down ==0) begin
               state <= DONE;
               done_reg <=1;
            end else begin
               count_down <= count_down -1;
               done_reg <=0;
            end
         end
         DONE: begin
            state <= DONE;
            done_reg <=1;
         end
      endcase
   end
end

assign result = state == DONE ? result_reg : 0;
assign done = done_reg;

endmodule