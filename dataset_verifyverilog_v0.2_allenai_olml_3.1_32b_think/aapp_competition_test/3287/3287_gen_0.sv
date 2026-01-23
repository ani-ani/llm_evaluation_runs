module thieves_loot (
 input clk,
 input rst_n,   // active-low reset
 input start,
 input [7:0] x0, x1, x2, x3,
 output reg [8:0] result,
 output reg done
);

// Parameters
localparam K =4;
localparam MAX_SUM =240;
localparam WIDTH=8;
localparam VALUE_WIDTH=9;

// Registers
reg [8:0] total_val;
reg [7:0] captured_x [4]; // x0-x3 captured at start
reg [3:0] coin_iter [K]; // for each coin, count how many iterations done
reg [3:0] current_coin;
reg [7:0] count_iter;
reg [9:0] current_sum;
reg [8:0] found_S;
reg [2:0] state; // main state machine
reg [2:0] substate; // substate for UPDATE_DP
reg [9:0] current_s_find; // for FIND_MAX

// DP memory: 8 regs of 32 bits each (total 256 bits, covering 0-240)
reg [31:0] dp_reg [8];

// State definitions
localparam IDLE =3'd0;
localparam COMPUTE_TOTAL =3'd1;
localparam INIT_DP =3'd2;
localparam UPDATE_DP =3'd3;
localparam FIND_MAX =3'd4;
localparam COMPUTE_RESULT =3'd5;
localparam DONE =3'd6;

// Reset handler
always @(negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      total_val <= 0;
      captured_x <= 0;
      coin_iter <=0;
      current_coin <=0;
      count_iter <=0;
      current_sum <=0;
      found_S <=0;
      // Initialize dp_reg: set bit0 of first reg to 1, others 0.
      dp_reg[0] <= 32'd1;
      dp_reg[1] <=0;
      dp_reg[2] <=0;
      dp_reg[3] <=0;
      dp_reg[4] <=0;
      dp_reg[5] <=0;
      dp_reg[6] <=0;
      dp_reg[7] <=0;
      substate <=0;
      current_s_find <=0;
   end
end

// Main state machine
always @(posedge clk) begin
   if (state == IDLE) begin
      if (start) begin
         state <= COMPUTE_TOTAL;
      end else begin
         state <= IDLE;
      end
   end else if (state == COMPUTE_TOTAL) begin
      captured_x[0] <= x0;
      captured_x[1] <= x1;
      captured_x[2] <= x2;
      captured_x[3] <= x3;
      total_val <= x0 + (x1 <<1) + (x2 <<2) + (x3 <<3);
      state <= INIT_DP;
   end else if (state == INIT_DP) begin
      // Re-initialize DP: set bit0 to 1, others 0.
      dp_reg[0] <= 32'd1;
      dp_reg[1] <=0;
      dp_reg[2] <=0;
      dp_reg[3] <=0;
      dp_reg[4] <=0;
      dp_reg[5] <=0;
      dp_reg[6] <=0;
      dp_reg[7] <=0;
      state <= UPDATE_DP;
      substate <= COIN_SELECT; // start with selecting coin
   end else if (state == UPDATE_DP) begin
      case (substate)
         COIN_SELECT: begin
            if (coin_iter[0] < captured_x[0]) begin
               current_coin <=0;
               count_iter <=0;
               current_sum <= MAX_SUM;
               substate <= COUNT_ITER;
               state <= UPDATE_DP;
            end else if (coin_iter[1] < captured_x[1]) begin
               current_coin <=1;
               count_iter <=0;
               current_sum <= MAX_SUM;
               substate <= COUNT_ITER;
               state <= UPDATE_DP;
            end else if (coin_iter[2] < captured_x[2]) begin
               current_coin <=2;
               count_iter <=0;
               current_sum <= MAX_SUM;
               substate <= COUNT_ITER;
               state <= UPDATE_DP;
            end else if (coin_iter[3] < captured_x[3]) begin
               current_coin <=3;
               count_iter <=0;
               current_sum <= MAX_SUM;
               substate <= COUNT_ITER;
               state <= UPDATE_DP;
            end else begin
               state <= FIND_MAX;
               substate <=0;
            end
         end
         COUNT_ITER: begin
            if (count_iter < captured_x[current_coin]) begin
               substate <= SUM_LOOP;
            end else begin
               // increment coin_iter for this coin
               coin_iter[current_coin] <= coin_iter[current_coin] +1;
               count_iter <=0;
               substate <= COIN_SELECT;
            end
         end
         SUM_LOOP: begin
            int v = 1 << current_coin;
            if (current_sum >= v) begin
               int reg_idx = (current_sum - v) >>5;
               int bit_in_reg = (current_sum - v) &31;
               bit bit_set = (reg_idx <8) ? dp_reg[reg_idx][bit_in_reg] :0;
               if (bit_set) begin
                  reg_idx = current_sum >>5;
                  bit_in_reg = current_sum &31;
                  if (reg_idx <8) begin 
                     dp_reg[reg_idx][bit_in_reg] <=1;
                  end
               end
               current_sum <= current_sum -1;
               substate <= SUM_LOOP;
            end else begin
               count_iter <= count_iter +1;
               substate <= COUNT_ITER;
            end
         end
      endcase
   end else if (state == FIND_MAX) begin
      if (found_S ==0) begin
         // Initialize current_s_find if not done
         if (total_val %2 ==0) begin
            current_s_find <= total_val;
         end else begin
            current_s_find <= total_val -1;
         end
      end
      if (found_S ==0) begin
         if (current_s_find >=0) begin
            int reg_idx = current_s_find >>5;
            int bit_in_reg = current_s_find &31;
            bit bit_set = (reg_idx <8) ? dp_reg[reg_idx][bit_in_reg] :0;
            if (bit_set) begin
               found_S <= current_s_find;
               state <= COMPUTE_RESULT;
            end else begin
               current_s_find <= current_s_find -2;
            end
         end else begin
            found_S <=0;
            state <= COMPUTE_RESULT;
         end
      end else begin
         state <= COMPUTE_RESULT;
      end
   end else if (state == COMPUTE_RESULT) begin
      result <= total_val - found_S;
      done <=1;
      state <= DONE;
   end else if (state == DONE) begin
      done <=1;
   end
end

endmodule