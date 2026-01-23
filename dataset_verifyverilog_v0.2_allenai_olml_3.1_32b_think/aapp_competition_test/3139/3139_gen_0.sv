module student_mentor_finder (
   input clk,
   input rst_n,
   input start,
   input [2:0] query_idx,
   input [2:0] num_students,
   input [7:0][15:0] student_A,
   input [7:0][15:0] student_B,
   output reg [2:0] mentor_idx,
   output reg done,
   output reg valid
),

parameter IDLE = 3'd0;
parameter SEARCH = 3'd1;
parameter COMPARE = 3'd2;
parameter DONE = 3'd3;

reg [1:0] state;
reg [2:0] current_index;
reg [2:0] query_idx_reg;
reg [2:0] num_students_reg;
reg [15:0] query_A;
reg [15:0] query_B;
reg [2:0] best_index;
reg [15:0] best_delta_B;
reg [15:0] best_delta_A;
reg found;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      current_index <= 3'b0;
      query_idx_reg <= 3'b0;
      num_students_reg <= 3'b0;
      query_A <= 16'b0;
      query_B <= 16'b0;
      best_index <= 3'b0;
      best_delta_B <= 16'b0;
      best_delta_A <= 16'b0;
      found <= 1'b0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            query_idx_reg <= query_idx;
            num_students_reg <= num_students;
            query_A <= student_A[query_idx_reg];
            query_B <= student_B[query_idx_reg];
            state <= SEARCH;
         end
      end
      else if (state == SEARCH) begin
         if (current_index < num_students_reg) begin
            if (current_index == query_idx_reg) begin
               current_index <= current_index + 1;
            end
            else begin
               if (student_A[current_index] >= query_A && student_B[current_index] >= query_B) begin
                  state <= COMPARE;
               end
               else begin
                  current_index <= current_index + 1;
               end
            end
         end
         else begin
            state <= DONE;
         end
      end
      else if (state == COMPARE) begin
         if (!found) begin
            best_index <= current_index;
            best_delta_B <= student_B[current_index] - query_B;
            best_delta_A <= student_A[current_index] - query_A;
            found <= 1'b1;
         end
         else begin
            if (student_B[current_index] - query_B < best_delta_B) begin
               best_index <= current_index;
               best_delta_B <= student_B[current_index] - query_B;
               best_delta_A <= student_A[current_index] - query_A;
            end
            else if (student_B[current_index] - query_B == best_delta_B) begin
               if (student_A[current_index] - query_A < best_delta_A) begin
                  best_index <= current_index;
                  best_delta_A <= student_A[current_index] - query_A;
               end
            end
         end
         current_index <= current_index + 1;
         state <= SEARCH;
      end
      else if (state == DONE) begin
         // stay in DONE
      end
   end
end

assign done = (state == DONE);
assign valid = done && found;
assign mentor_idx = done ? (found ? best_index : 3'b0) : 3'b0;
endmodule
