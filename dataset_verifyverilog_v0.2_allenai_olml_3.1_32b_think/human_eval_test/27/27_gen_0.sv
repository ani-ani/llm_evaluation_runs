module flip_case (
input clk,
input rst_n, // active low
input start,
input [7:0] char_in,
input [3:0] char_index,
input valid_in,
output reg [7:0] char_out,
output reg [3:0] char_index_out,
output reg valid_out,
output reg done
);
   reg [7:0] current_char;
   reg [3:0] current_index;
   reg [1:0] cycle_count;
   reg [4:0] char_count;
   reg [1:0] state; // IDLE=0, PROCESSING=1, DONE=2
   reg prev_valid_in;
   localparam IDLE = 2'b00;
   localparam PROCESSING = 2'b01;
   localparam DONE = 2'b10;
   always @(posedge clk) begin
      if (!rst_n) begin
         current_char <= 8'b0;
         current_index <= 4'b0;
         cycle_count <= 2'b00;
         char_count <= 5'b0;
         state <= IDLE;
         prev_valid_in <= 1'b0;
         char_out <= 8'b0;
         valid_out <= 1'b0;
         char_index_out <= 4'b0;
         done <= 1'b0;
      end else begin
         prev_valid_in <= valid_in;
         case(state)
            IDLE: 
               if (start)
                  state <= PROCESSING;
               else
                  state <= IDLE;
               char_out <=8'b0;
               valid_out <=1'b0;
               char_index_out <=4'b0;
               done <=1'b0;
            PROCESSING:
               if (valid_in && !prev_valid_in && cycle_count == 2'b00) begin
                  current_char <= char_in;
                  current_index <= char_index;
                  cycle_count <= 2'b10;
               end
               if (cycle_count != 2'b00) begin
                  cycle_count <= cycle_count - 1;
               end else begin
                  wire [7:0] flipped_char;
                  wire is_alpha;
                  is_alpha = ( (current_char >= 8'h41 && current_char <= 8'h5A) || (current_char >= 8'h61 && current_char <= 8'h7A) );
                  if (is_alpha)
                     flipped_char = current_char ^ (1<<5);
                  else
                     flipped_char = current_char;
                  char_out <= flipped_char;
                  valid_out <= 1'b1;
                  char_index_out <= current_index;
                  if (char_count < 16) begin
                     char_count <= char_count + 1;
                     if (char_count == 16) begin
                        state <= DONE;
                     end
                  end
               end
            DONE:
               state <= DONE;
               done <= 1'b1;
         endcase
      end
   end
endmodule