module max_average_subarray (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] data_in,
    input [2:0] index,
    input write_en,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

// Internal registers
reg [7:0] data_array [7:0];
reg [2:0] n_reg;
reg [15:0] current_max;
reg [15:0] result_reg;
reg done_reg, valid_reg;
reg [3:0] state; // 0: IDLE, 1: COMPUTE_INIT, 2: COMPUTE_SUBARRAY, 3: COMPUTE_SUM, 4: DONE
reg [4:0] subarray_count;
reg [3:0] L, i, j;
reg [11:0] sum;
reg computing_sum;

// State machine
always @(posedge clk) if (!rst_n) begin
   data_array <= 8'b0;
   n_reg <= 3'b000;
   current_max <= 16'b0;
   result_reg <= 16'b0;
   done_reg <= 1'b0;
   valid_reg <= 1'b0;
   state <= 4'b0000;
   subarray_count <= 5'b00000;
   L <= 4'b0000;
   i <= 4'b0000;
   j <= 4'b0000;
   sum <= 12'b000000000000;
   computing_sum <= 1'b0;
end else begin
   case (state)
      4'b0000: // IDLE
         if (start) begin
            if (n < 3) begin
               current_max <= 16'b0;
               result_reg <= current_max;
               done_reg <= 1'b1;
               valid_reg <= 1'b1;
               state <= 4'b0100; // DONE
            end else begin
               n_reg <= n;
               state <= 4'b0001; // COMPUTE_INIT
               current_max <= 16'b0;
            end
         end
      end

      4'b0001: // COMPUTE_INIT
         subarray_count <= 5'b00000;
         state <= 4'b0010; // COMPUTE_SUBARRAY;
      end

      4'b0010: // COMPUTE_SUBARRAY: process each subarray_count
         if (subarray_count < 21) begin
            // Decode L and i
            if (subarray_count <6) begin // L=3
               L <=3;
               i <= subarray_count;
            end else if (subarray_count <6+5) begin // L=4 (5 elements)
               L <=4;
               i <= subarray_count -6;
            end else if (subarray_count <6+5+4) begin // L=5 (4)
               L <=5;
               i <= subarray_count -11;
            end else if (subarray_count <6+5+4+3) begin // L=6 (3)
               L <=6;
               i <= subarray_count -15;
            end else if (subarray_count <6+5+4+3+2) begin // L=7 (2)
               L <=7;
               i <= subarray_count -18;
            end else begin // L=8 (1)
               L <=8;
               i <=0;
            end

            if (L > n_reg) begin
               subarray_count <= subarray_count +1;
            end else begin
               j <=0;
               sum <=12'b000000000000;
               computing_sum <=1'b1;
               state <= 4'b0011; // COMPUTE_SUM
            end
         end else begin
            result_reg <= current_max;
            done_reg <=1'b1;
            valid_reg <=1'b1;
            state <=4'b0100; // DONE
         end
      end

      4'b0011: // COMPUTE_SUM: accumulate sum
         if (computing_sum) begin
            if (j < L) begin
               sum <= sum + data_array[i + j];
               j <= j +1;
            end else begin
               // Compute average with rounding
               reg [15:0] temp_avg;
               case (L)
                  3: temp_avg = (sum <<8 + 1) /3;
                  4: temp_avg = (sum <<8 + 2) /4;
                  5: temp_avg = (sum <<8 + 2) /5;
                  6: temp_avg = (sum <<8 +3) /6;
                  7: temp_avg = (sum <<8 +3) /7;
                  8: temp_avg = (sum <<8 +4) /8;
                  default: temp_avg =0;
               endcase

               if (temp_avg > current_max) begin
                  current_max <= temp_avg;
               end

               // Move to next subarray
               subarray_count <= subarray_count +1;
               state <=4'b0010; // back to COMPUTE_SUBARRAY
               j <=0;
               sum <=12'b000000000000;
               computing_sum <=1'b0;
            end
         end
      end

      4'b0100: // DONE
         state <=4'b0100;
      endcase
end

// Handle data_array writes
always @(posedge clk) if (!rst_n) begin
   data_array <= 8'b0;
end else begin
   if (write_en) begin
      if (index < n) begin // Use input n, not n_reg
         data_array[index] <= data_in;
      end
   end
end

// Assign outputs
assign result = result_reg;
assign done = done_reg;
assign valid = valid_reg;

endmodule