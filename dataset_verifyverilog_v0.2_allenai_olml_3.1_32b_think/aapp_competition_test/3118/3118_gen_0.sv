module shuffling_game (
   input clk,
   input rst_n,
   input start,
   input [2:0] n,
   input [7:0][7:0] alice_perm,
   input [7:0][7:0] bob_perm,
   output reg [15:0] result,
   output reg done
);

reg [7:0] current_deck [8];
reg [7:0] new_deck [8];
reg [7:0] step_count;
reg [15:0] result;
reg done;
reg [2:0] state;

localparam IDLE = 3'd0;
localparam INITIAL_CHECK = 3'd1;
localparam SHUFFLE = 3'd2;
localparam CHECK_IDENTITY = 3'd3;
localparam DONE = 3'd4;
localparam HUGE = 3'd5;

always @(negedge rst_n) begin
   if (!rst_n) begin
      current_deck[0] <= 1;
      current_deck[1] <= 2;
      current_deck[2] <=3;
      current_deck[3] <=4;
      current_deck[4] <=5;
      current_deck[5] <=6;
      current_deck[6] <=7;
      current_deck[7] <=8;
      step_count <=0;
      result <=0;
      done <=0;
      state <= IDLE;
   end
end

always @(posedge clk) begin
   if (!rst_n) begin
      current_deck[0] <= 1;
      current_deck[1] <= 2;
      current_deck[2] <=3;
      current_deck[3] <=4;
      current_deck[4] <=5;
      current_deck[5] <=6;
      current_deck[6] <=7;
      current_deck[7] <=8;
      step_count <=0;
      result <=0;
      done <=0;
      state <= IDLE;
   end else begin
      case(state)
         IDLE: begin
            if (start) begin
               state <= INITIAL_CHECK;
            end else begin
               state <= IDLE;
            end
         end
         INITIAL_CHECK: begin
            step_count <=1;
            state <= SHUFFLE;
         end
         SHUFFLE: begin
            int selected_perm [7:0][7:0];
            if (step_count %2 ==1) begin
               selected_perm = alice_perm;
            end else begin
               selected_perm = bob_perm;
            end
            if (n ==1) begin
               new_deck[0] = current_deck[ selected_perm[0][0] -1 ];
            end else if (n==2) begin
               new_deck[0] = current_deck[ selected_perm[0][0] -1 ];
               new_deck[1] = current_deck[ selected_perm[1][0] -1 ];
            end else if (n==3) begin
               new_deck[0] = current_deck[ selected_perm[0][0] -1 ];
               new_deck[1] = current_deck[ selected_perm[1][0] -1 ];
               new_deck[2] = current_deck[ selected_perm[2][0] -1 ];
            end else if (n==4) begin
               new_deck[0] = current_deck[ selected_perm[0][0] -1 ];
               new_deck[1] = current_deck[ selected_perm[1][0] -1 ];
               new_deck[2] = current_deck[ selected_perm[2][0] -1 ];
               new_deck[3] = current_deck[ selected_perm[3][0] -1 ];
            end else if (n==5) begin
               new_deck[0] = current_deck[ selected_perm[0][0] -1 ];
               new_deck[1] = current_deck[ selected_perm[1][0] -1 ];
               new_deck[2] = current_deck[ selected_perm[2][0] -1 ];
               new_deck[3] = current_deck[ selected_perm[3][0] -1 ];
               new_deck[4] = current_deck[ selected_perm[4][0] -1 ];
            end else if (n==6) begin
               new_deck[0] = current_deck[ selected_perm[0][0] -1 ];
               new_deck[1] = current_deck[ selected_perm[1][0] -1 ];
               new_deck[2] = current_deck[ selected_perm[2][0] -1 ];
               new_deck[3] = current_deck[ selected_perm[3][0] -1 ];
               new_deck[4] = current_deck[ selected_perm[4][0] -1 ];
               new_deck[5] = current_deck[ selected_perm[5][0] -1 ];
            end else if (n==7) begin
               new_deck[0] = current_deck[ selected_perm[0][0] -1 ];
               new_deck[1] = current_deck[ selected_perm[1][0] -1 ];
               new_deck[2] = current_deck[ selected_perm[2][0] -1 ];
               new_deck[3] = current_deck[ selected_perm[3][0] -1 ];
               new_deck[4] = current_deck[ selected_perm[4][0] -1 ];
               new_deck[5] = current_deck[ selected_perm[5][0] -1 ];
               new_deck[6] = current_deck[ selected_perm[6][0] -1 ];
            end else if (n==8) begin
               new_deck[0] = current_deck[ selected_perm[0][0] -1 ];
               new_deck[1] = current_deck[ selected_perm[1][0] -1 ];
               new_deck[2] = current_deck[ selected_perm[2][0] -1 ];
               new_deck[3] = current_deck[ selected_perm[3][0] -1 ];
               new_deck[4] = current_deck[ selected_perm[4][0] -1 ];
               new_deck[5] = current_deck[ selected_perm[5][0] -1 ];
               new_deck[6] = current_deck[ selected_perm[6][0] -1 ];
               new_deck[7] = current_deck[ selected_perm[7][0] -1 ];
            end else begin
               new_deck[0] = current_deck[0];
            end
            state <= CHECK_IDENTITY;
         end
         CHECK_IDENTITY: begin
            reg match =1'b1;
            if (n ==1) match = (new_deck[0] == 1);
            else if (n==2) match = (new_deck[0]==1 && new_deck[1]==2);
            else if (n==3) match = (new_deck[0]==1 && new_deck[1]==2 && new_deck[2]==3);
            else if (n==4) match = (new_deck[0]==1 && new_deck[1]==2 && new_deck[2]==3 && new_deck[3]==4);
            else if (n==5) match = (new_deck[0]==1 && new_deck[1]==2 && new_deck[2]==3 && new_deck[3]==4 && new_deck[4]==5);
            else if (n==6) match = (new_deck[0]==1 && new_deck[1]==2 && new_deck[2]==3 && new_deck[3]==4 && new_deck[4]==5 && new_deck[5]==6);
            else if (n==7) match = (new_deck[0]==1 && new_deck[1]==2 && new_deck[2]==3 && new_deck[3]==4 && new_deck[4]==5 && new_deck[5]==6 && new_deck[6]==7);
            else if (n==8) match = (new_deck[0]==1 && new_deck[1]==2 && new_deck[2]==3 && new_deck[3]==4 && new_deck[4]==5 && new_deck[5]==6 && new_deck[6]==7 && new_deck[7]==8);
            else match =1'b1;
            if (match) begin
               result <= step_count;
               done <=1;
               state <= DONE;
            end else begin
               if (step_count > 128) begin
                  result <= 16'bFFFF;
                  done <=1;
                  state <= HUGE;
               end else begin
                  current_deck <= new_deck;
                  step_count <= step_count +1;
                  state <= SHUFFLE;
               end
            end
         end
         DONE: begin
            state <= DONE;
         end
         HUGE: begin
            state <= HUGE;
         end
      endcase
   end
endmodule