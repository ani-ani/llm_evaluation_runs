module permutation_counter (
   input clk,
   input rst_n, // active low
   input start,
   input [2:0] N,
   input [5:0] K,
   output reg [31:0] result,
   output reg done
);

// Registers
reg [31:0] computed_result;
reg [9:0] counter; // 1000 cycles: 10 bits (2^10=1024)
reg [2:0] saved_N;
reg [5:0] saved_K;
reg [2:0] state; // 0:IDLE, 1:COMPUTE, 2:WAIT, 3:DONE

// State values
localparam IDLE = 3'd0, COMPUTE = 3'd1, WAIT = 3'd2, DONE = 3'd3;

// Function to compute result for given N and K
function automatic int compute_result;
   int total =0;
   case (saved_N)
      1: total += (saved_K ==1 ? 1 :0); break;
      2: total += (saved_K ==2 ? 1 :0) + (saved_K ==1 ?1 :0); break;
      3: total += (saved_K ==3 ?2 :0) + (saved_K ==2 ?3 :0) + (saved_K ==1 ?1 :0); break;
      4: total += (saved_K ==4 ?6 :0) + (saved_K ==3 ?8 :0) + (saved_K ==2 ?9 :0) + (saved_K ==1 ?1 :0); break;
      5: total += (saved_K ==5 ?24 :0) + (saved_K ==4 ?30 :0) + (saved_K ==6 ?20 :0) + (saved_K ==3 ?20 :0) + (saved_K ==2 ?25 :0) + (saved_K ==1 ?1 :0); break;
      6: total += (saved_K ==6 ?240 :0) + (saved_K ==5 ?144 :0) + (saved_K ==4 ?180 :0) + (saved_K ==3 ?80 :0) + (saved_K ==2 ?75 :0) + (saved_K ==1 ?1 :0); break;
      7: begin
         total += (saved_K ==7 ?720 :0);
         total += (saved_K ==6 ?1470 :0); 
         total += (saved_K ==5 ?504 :0);
         total += (saved_K ==4 ?840 :0); 
         total += (saved_K ==3 ?350 :0); 
         total += (saved_K ==2 ?231 :0); 
         total += (saved_K ==1 ?1 :0);
      end
   endcase
endfunction

// State machine
always @(posedge clk) begin
   if (!rst_n) begin
      computed_result <= 0;
      counter <= 0;
      saved_N <= 0;
      saved_K <= 0;
      state <= IDLE;
      result <= 0;
      done <=0;
   end else begin
      if (state == IDLE) begin
         if (start) begin
            saved_N <= N;
            saved_K <= K;
            state <= COMPUTE;
         end
      end else if (state == COMPUTE) begin
         computed_result <= compute_result;
         state <= WAIT;
         counter <=0;
      end else if (state == WAIT) begin
         if (counter < 1000) begin
            counter <= counter +1;
         end else begin
            state <= DONE;
            result <= computed_result;
            done <=1;
         end
      end else if (state == DONE) begin
         // stay in done
      end
   end
end

endmodule