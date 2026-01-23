module bidirectional_counter (
   input clk,
   input rst_n, // active low
   input start,
   input [7:0] tuple_first [0:7], // 8 elements of 8 bits
   input [7:0] tuple_second [0:7],
   output reg [3:0] result,
   output reg done
);

// State definitions
localparam IDLE = 2'd0,
          PROCESSING = 2'd1,
          DONE = 2'd2;

reg [1:0] state_reg;

// Counters
reg [2:0] i_count, j_count;

// Result and done
reg [3:0] result_reg;
reg done_reg;

// Default assignments to avoid latches
always @(*) begin
   i_count = 0;
   j_count = 1;
   result_reg = 0;
   done_reg = 0;
   state_reg = IDLE;
end

// State machine
always @(posedge clk) begin
   if (!rst_n) begin
      i_count <= 0;
      j_count <= 1;
      result_reg <=0;
      done_reg <=0;
      state_reg <= IDLE;
   end else begin
      case (state_reg)
         IDLE: if (start) begin
                state_reg <= PROCESSING;
                i_count <=0;
                j_count <=1;
                result_reg <=0;
                done_reg <=0;
             end else begin
                state_reg <= IDLE;
             end

         PROCESSING: begin
             // Check for valid pair and update result
             if (i_count < j_count && tuple_first[i_count][j_count] == tuple_second[j_count] && tuple_second[i_count][j_count] == tuple_first[j_count]) begin
                 result_reg <= result_reg +1;
             end

             // Update counters
             j_count <= j_count +1;
             if (j_count == 8) begin
                 i_count <= i_count +1;
                 if (i_count <7) begin
                     j_count <= i_count +1;
                 end
             end

             // Check if done
             if (i_count >=7) begin
                 state_reg <= DONE;
                 done_reg <=1;
             end else begin
                 state_reg <= PROCESSING;
             end
         end

         DONE: if (start) begin
                // Optionally restart on start in DONE? Or not.
                // According to behavioral description, wait for reset or new start.
                // So if start is high, go back to IDLE.
                state_reg <= IDLE;
                i_count <=0;
                j_count <=1;
                result_reg <=0;
                done_reg <=0;
             end else if (!rst_n) begin
                state_reg <= IDLE;
                i_count <=0;
                j_count <=1;
                result_reg <=0;
                done_reg <=0;
             end else begin
                state_reg <= DONE;
             end
      endcase
   end
end

// Assign outputs
assign result = result_reg;
assign done = done_reg;
endmodule