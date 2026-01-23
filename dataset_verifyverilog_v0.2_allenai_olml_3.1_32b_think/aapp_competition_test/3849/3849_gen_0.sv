module duel_game(input [7:0] card_state, input [3:0] k, output reg [79:0] result);
parameter STR_TOKITSUKAZ = {8'h74, 8'h6F, 8'h6B, 8'h69, 8'h74, 8'h73, 8'h75, 8'h6B, 8'h61, 8'h7A};
parameter STR_QUIPTY = {8'h71,8'h75,8'h61,8'h69,8'h6C,8'h74,8'h79, 8'h20,8'h20,8'h20};
parameter STR_ONCE_AGAIN = {8'h6F,8'h6E,8'h63,8'h65,8'h20,8'h61,8'h67,8'h61,8'h69,8'h6E};
function automatic int check_win(input [7:0] state, input [3:0] k);
   int i;
   int mask;
   int new_state;
   for (i=0; i < 8; i++) begin
      if (i > (8 - k)) begin
          continue;
      end
      mask = (1 << k) - 1;
      mask = mask << i;
      new_state = state ^ mask;
      if (new_state == 0 || new_state == 8'hFF) begin
          return 1;
      end
   end
   return 0;
endfunction
always @(*) begin
   wire immediate_win = check_win(card_state, k);
   if (immediate_win) begin
      result = STR_TOKITSUKAZ;
   end else begin
      int all_second_win = 1;
      int i;
      for (i=0; i <8; i++) begin
          if (i > (8 - k)) begin
              continue;
          end
          int mask = (1 << k) -1;
          mask = mask << i;
          int new_state = card_state ^ mask;
          int second_win = check_win(new_state, k);
          all_second_win = all_second_win & second_win;
      end
      if (all_second_win) begin
          result = STR_QUIPTY;
      end else begin
          result = STR_ONCE_AGAIN;
      end
   end
end
endmodule