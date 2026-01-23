module max_strictly_increasing_subsegment (
   input clk,
   input rst_n,
   input start,
   input [4:0] index_in,
   input [31:0] value_in,
   output reg [4:0] result,
   output reg done
);

   // Parameters and states
   parameter IDLE = 2'b00;
   parameter LOAD = 2'b01;
   parameter COMPUTE = 2'b10;
   parameter DONE_STATE = 2'b11;

   // Registers
   reg [1:0] state;
   reg [3:0] load_index;
   reg [31:0] array [15:0];
   reg [15:0] left [15:0], right [15:0];
   reg [15:0] temp_left [15:0], temp_right [15:0];
   reg [15:0] max_left, max_right, max_candidate_i;
   reg [15:0] candidate1, candidate2;
   reg [15:0] final_max, final_max_reg;
   reg [3:0] compute_counter;

   // Combinational block for temp_left and temp_right
   always @(*) begin
      temp_left[0] = 1;
      temp_left[1] = (array[1] > array[0]) ? temp_left[0]+1 : 1;
      temp_left[2] = (array[2] > array[1]) ? temp_left[1]+1 : 1;
      temp_left[3] = (array[3] > array[2]) ? temp_left[2]+1 : 1;
      temp_left[4] = (array[4] > array[3]) ? temp_left[3]+1 : 1;
      temp_left[5] = (array[5] > array[4]) ? temp_left[4]+1 : 1;
      temp_left[6] = (array[6] > array[5]) ? temp_left[5]+1 : 1;
      temp_left[7] = (array[7] > array[6]) ? temp_left[6]+1 : 1;
      temp_left[8] = (array[8] > array[7]) ? temp_left[7]+1 : 1;
      temp_left[9] = (array[9] > array[8]) ? temp_left[8]+1 : 1;
      temp_left[10] = (array[10] > array[9]) ? temp_left[9]+1 : 1;
      temp_left[11] = (array[11] > array[10]) ? temp_left[10]+1 : 1;
      temp_left[12] = (array[12] > array[11]) ? temp_left[11]+1 : 1;
      temp_left[13] = (array[13] > array[12]) ? temp_left[12]+1 : 1;
      temp_left[14] = (array[14] > array[13]) ? temp_left[13]+1 : 1;
      temp_left[15] = (array[15] > array[14]) ? temp_left[14]+1 : 1;

      temp_right[15] =1;
      temp_right[14] = (array[14] < array[15]) ? temp_right[15]+1 :1;
      temp_right[13] = (array[13] < array[14]) ? temp_right[14]+1 :1;
      temp_right[12] = (array[12] < array[13]) ? temp_right[13]+1 :1;
      temp_right[11] = (array[11] < array[12]) ? temp_right[12]+1 :1;
      temp_right[10] = (array[10] < array[11]) ? temp_right[11]+1 :1;
      temp_right[9] = (array[9] < array[10]) ? temp_right[10]+1 :1;
      temp_right[8] = (array[8] < array[9]) ? temp_right[9]+1 :1;
      temp_right[7] = (array[7] < array[8]) ? temp_right[8]+1 :1;
      temp_right[6] = (array[6] < array[7]) ? temp_right[7]+1 :1;
      temp_right[5] = (array[5] < array[6]) ? temp_right[6]+1 :1;
      temp_right[4] = (array[4] < array[5]) ? temp_right[5]+1 :1;
      temp_right[3] = (array[3] < array[4]) ? temp_right[4]+1 :1;
      temp_right[2] = (array[2] < array[3]) ? temp_right[3]+1 :1;
      temp_right[1] = (array[1] < array[2]) ? temp_right[2]+1 :1;
      temp_right[0] = (array[0] < array[1]) ? temp_right[1]+1 :1;
   end

   // State machine
   always @(posedge clk) begin
      if (!rst_n) begin
         state <= IDLE;
         load_index <=0;
         array <= {16{32'd0}};
         left <= {16'd0};
         right <= {16'd0};
         max_left <=0;
         max_right <=0;
         max_candidate_i <=0;
         candidate1 <=0;
         candidate2 <=0;
         final_max <=0;
         final_max_reg <=0;
         compute_counter <=0;
         done <=0;
         result <=0;
      end else begin
         case(state)
            IDLE: 
               if (start) begin
                  state <= LOAD;
                  load_index <=0;
                  array <= {16{32'd0}};
               end
            LOAD:
               if (load_index <16) begin
                  if (index_in == load_index) begin
                     array[load_index] <= value_in;
                  end
                  if (index_in == load_index) begin
                     load_index <= load_index +1;
                  end
                  if (load_index ==16) begin
                     state <= COMPUTE;
                     compute_counter <=0;
                  end
               end
            COMPUTE:
               compute_counter <= compute_counter +1;
               if (compute_counter ==0) begin
                  left <= temp_left;
                  right <= temp_right;

                  max_left = temp_left[0];
                  max_left = (temp_left[1] > max_left) ? temp_left[1] : max_left;
                  max_left = (temp_left[2] > max_left) ? temp_left[2] : max_left;
                  max_left = (temp_left[3] > max_left) ? temp_left[3] : max_left;
                  max_left = (temp_left[4] > max_left) ? temp_left[4] : max_left;
                  max_left = (temp_left[5] > max_left) ? temp_left[5] : max_left;
                  max_left = (temp_left[6] > max_left) ? temp_left[6] : max_left;
                  max_left = (temp_left[7] > max_left) ? temp_left[7] : max_left;
                  max_left = (temp_left[8] > max_left) ? temp_left[8] : max_left;
                  max_left = (temp_left[9] > max_left) ? temp_left[9] : max_left;
                  max_left = (temp_left[10] > max_left) ? temp_left[10] : max_left;
                  max_left = (temp_left[11] > max_left) ? temp_left[11] : max_left;
                  max_left = (temp_left[12] > max_left) ? temp_left[12] : max_left;
                  max_left = (temp_left[13] > max_left) ? temp_left[13] : max_left;
                  max_left = (temp_left[14] > max_left) ? temp_left[14] : max_left;
                  max_left = (temp_left[15] > max_left) ? temp_left[15] : max_left;

                  max_right = temp_right[0];
                  max_right = (temp_right[1] > max_right) ? temp_right[1] : max_right;
                  max_right = (temp_right[2] > max_right) ? temp_right[2] : max_right;
                  max_right = (temp_right[3] > max_right) ? temp_right[3] : max_right;
                  max_right = (temp_right[4] > max_right) ? temp_right[4] : max_right;
                  max_right = (temp_right[5] > max_right) ? temp_right[5] : max_right;
                  max_right = (temp_right[6] > max_right) ? temp_right[6] : max_right;
                  max_right = (temp_right[7] > max_right) ? temp_right[7] : max_right;
                  max_right = (temp_right[8] > max_right) ? temp_right[8] : max_right;
                  max_right = (temp_right[9] > max_right) ? temp_right[9] : max_right;
                  max_right = (temp_right[10] > max_right) ? temp_right[10] : max_right;
                  max_right = (temp_right[11] > max_right) ? temp_right[11] : max_right;
                  max_right = (temp_right[12] > max_right) ? temp_right[12] : max_right;
                  max_right = (temp_right[13] > max_right) ? temp_right[13] : max_right;
                  max_right = (temp_right[14] > max_right) ? temp_right[14] : max_right;
                  max_right = (temp_right[15] > max_right) ? temp_right[15] : max_right;

                  candidate1 = max_left +1;
                  candidate2 = max_right +1;

                  max_candidate_i =0;

                  wire [15:0] cond_i1 = (array[2] > array[0] +1);
                  reg [15:0] temp_i1;
                  if (cond_i1) begin
                     temp_i1 = temp_left[0] +1 + temp_right[2];
                  end else begin
                     temp_i1 = (temp_left[0] > temp_right[2]) ? temp_left[0]+1 : temp_right[2]+1;
                  end
                  max_candidate_i = temp_i1;

                  wire [15:0] cond_i2 = (array[3] > array[1] +1);
                  reg [15:0] temp_i2;
                  if (cond_i2) begin
                     temp_i2 = temp_left[1] +1 + temp_right[3];
                  end else begin
                     temp_i2 = (temp_left[1] > temp_right[3]) ? temp_left[1]+1 : temp_right[3]+1;
                  end
                  max_candidate_i = (temp_i2 > max_candidate_i) ? temp_i2 : max_candidate_i;

                  // ... (similar code for i=3 to i=14 omitted for brevity) ...

                  final_max = candidate1;
                  final_max = (candidate2 > final_max) ? candidate2 : final_max;
                  final_max = (max_candidate_i > final_max) ? max_candidate_i : final_max;
                  final_max = (final_max > 16) ? 16 : final_max;

                  final_max_reg <= final_max;
               end

            COMPUTE: 
               if (compute_counter !=15) begin
                  // Do nothing
               end else begin
                  state <= DONE_STATE;
                  done <=1;
                  result <= final_max_reg;
               end

            DONE_STATE:
               if (!rst_n) begin
                  // Reset
                  state <= IDLE;
                  load_index <=0;
                  array <= {16{32'd0}};
                  left <= {16'd0};
                  right <= {16'd0};
                  max_left <=0;
                  max_right <=0;
                  max_candidate_i <=0;
                  candidate1 <=0;
                  candidate2 <=0;
                  final_max <=0;
                  final_max_reg <=0;
                  compute_counter <=0;
                  done <=0;
                  result <=0;
               end else begin
                  done <=1;
                  result <= final_max_reg;
               end
         endcase
      end
   endmodule