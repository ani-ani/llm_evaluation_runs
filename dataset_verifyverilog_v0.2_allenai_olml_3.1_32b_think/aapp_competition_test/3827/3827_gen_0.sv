module string_validator (
   input clk,
   input rst_n,
   input start,
   input [7:0] char_in,
   input [2:0] idx,
   output reg result,
   output reg done
);

   reg [3:0] count_a, count_b, count_c;
   reg [7:0] prev_char;
   reg end_of_string;
   reg error_flag;
   reg [1:0] state;
   reg [3:0] cycle_count;

   parameter IDLE = 2'b00;
   parameter READ = 2'b01;
   parameter VALIDATE = 2'b10;
   parameter DONE = 2'b11;

   initial begin
      count_a = 0;
      count_b = 0;
      count_c = 0;
      prev_char = 0;
      end_of_string = 0;
      error_flag = 0;
      state = IDLE;
      cycle_count = 0;
   end

   always @(negedge rst_n) begin
      if (!rst_n) begin
         count_a <= 0;
         count_b <= 0;
         count_c <= 0;
         prev_char <= 0;
         end_of_string <= 0;
         error_flag <= 0;
         state <= IDLE;
         cycle_count <= 0;
         result <= 0;
         done <= 0;
      end
   end

   always @(posedge clk) begin
      if (!rst_n) begin
         state <= IDLE;
         result <= 0;
         done <= 0;
         cycle_count <= 0;
      end else begin
         case (state)
            IDLE: begin
               if (start) begin
                  count_a <= 0;
                  count_b <= 0;
                  count_c <= 0;
                  prev_char <= 0;
                  end_of_string <= 0;
                  error_flag <= 0;
                  cycle_count <= 0;
                  state <= READ;
               end else begin
                  state <= IDLE;
               end
            end
            READ: begin
               if (cycle_count < 8) begin
                  if (char_in == 'a') begin
                     count_a <= count_a + 1;
                     if (char_in < prev_char) error_flag <= 1;
                     prev_char <= char_in;
                  end else if (char_in == 'b') begin
                     count_b <= count_b + 1;
                     if (char_in < prev_char) error_flag <= 1;
                     prev_char <= char_in;
                  end else if (char_in == 'c') begin
                     count_c <= count_c + 1;
                     if (char_in < prev_char) error_flag <= 1;
                     prev_char <= char_in;
                  end else if (char_in == 0) begin
                     end_of_string <= 1;
                  end else begin
                     error_flag <= 1;
                  end
                  cycle_count <= cycle_count + 1;
                  state <= READ;
               end else begin
                  cycle_count <= 0;
                  state <= VALIDATE;
               end
            end
            VALIDATE: begin
               if (cycle_count < 4) begin
                  cycle_count <= cycle_count + 1;
                  state <= VALIDATE;
               end else begin
                  if (error_flag) begin
                     result <= 0;
                  end else begin
                     if (count_a == 0 || count_b == 0) begin
                        result <= 0;
                     end else if (count_c != count_a && count_c != count_b) begin
                        result <= 0;
                     end else begin
                        result <= 1;
                     end
                  end
                  done <= 1;
                  state <= DONE;
                  cycle_count <= 0;
               end
            end
            DONE: begin
               state <= DONE;
               done <= 1;
            end
            default: state <= IDLE;
         endcase
      end
   end

   endmodule