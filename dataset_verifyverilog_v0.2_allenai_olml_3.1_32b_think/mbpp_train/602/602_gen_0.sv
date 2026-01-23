module first_repeated_char (
input clk,
input rst_n, // active-low reset
input start,
input [7:0] char_in,
input [2:0] char_count,
output reg [7:0] result,
output reg done 
);

localparam IDLE = 3'd0;
localparam READING = IDLE +1;
localparam PROCESSING = READING +1;
localparam DONE = PROCESSING +1;

reg [2:0] state;
reg [7:0] char_count_reg;
reg [7:0] read_count;
reg [7:0] char_mem [0:7];
reg [7:0] result;
reg first_found;
reg [3:0] proc_count;

assign done = (state == DONE);

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      char_count_reg <=0;
      read_count <=0;
      char_mem[0] <=0;
      char_mem[1] <=0;
      char_mem[2] <=0;
      char_mem[3] <=0;
      char_mem[4] <=0;
      char_mem[5] <=0;
      char_mem[6] <=0;
      char_mem[7] <=0;
      result <=0;
      first_found <=0;
      proc_count <=0;
   end else begin
      case(state)
         IDLE: begin
            if (start) begin
               char_count_reg <= char_count;
               read_count <= char_count_reg;
               first_found <=0;
               result <=0;
               state <= READING;
            end
         end
         READING: begin
            if (read_count >0) begin
               if (char_count_reg - read_count >=0 && char_count_reg - read_count <8) begin
                  char_mem[char_count_reg - read_count] = char_in;
                  if (char_count_reg - read_count >0) begin
                     if (char_mem[0] == char_in && !first_found) begin
                        result = char_in;
                        first_found =1;
                     end
                  end
                  if (char_count_reg - read_count >1) begin
                     if (char_mem[1] == char_in && !first_found) begin
                        result = char_in;
                        first_found =1;
                     end
                  end
                  if (char_count_reg - read_count >2) begin
                     if (char_mem[2] == char_in && !first_found) begin
                        result = char_in;
                        first_found =1;
                     end
                  end
                  if (char_count_reg - read_count >3) begin
                     if (char_mem[3] == char_in && !first_found) begin
                        result = char_in;
                        first_found =1;
                     end
                  end
                  if (char_count_reg - read_count >4) begin
                     if (char_mem[4] == char_in && !first_found) begin
                        result = char_in;
                        first_found =1;
                     end
                  end
                  if (char_count_reg - read_count >5) begin
                     if (char_mem[5] == char_in && !first_found) begin
                        result = char_in;
                        first_found =1;
                     end
                  end
                  if (char_count_reg - read_count >6) begin
                     if (char_mem[6] == char_in && !first_found) begin
                        result = char_in;
                        first_found =1;
                     end
                  end
                  read_count <= read_count -1;
               end else begin
                  read_count <= read_count -1;
               end
            end else begin
               state <= PROCESSING;
               proc_count <= 8 - char_count_reg;
            end
         end
         PROCESSING: begin
            if (proc_count ==0) begin
               state <= DONE;
            end else begin
               proc_count <= proc_count -1;
            end
         end
         DONE: begin
         end
      endcase
   end
endmodule