module thore_checker (input clk, input rst_n, input start, input [15:0] scoreboard_size, input [127:0] current_name, input [127:0] names_above [0:7], input [127:0] names_below [0:7], output reg [15:0] result_prefix, output reg [127:0] result_string, output reg done, output reg is_awesome, output reg sucks);
localparam IDLE = 3'd0;
localparam CHECK_FIRST = 3'd1;
localparam CHECK_SUCKS = 3'd2;
localparam FIND_PREFIX = 3'd3;
localparam DONE = 3'd4;

reg [2:0] state;
reg [7:0] L_count;
reg [15:0] result_prefix_reg;
reg [127:0] result_string_reg;
reg done_reg;
reg is_awesome_reg;
reg sucks_reg;

assign result_prefix = result_prefix_reg;
assign result_string = result_string_reg;
assign done = done_reg;
assign is_awesome = is_awesome_reg;
assign sucks = sucks_reg;

always @ (posedge clk or !rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      L_count <= 0;
      result_prefix_reg <= 0;
      result_string_reg <= 0;
      done_reg <= 0;
      is_awesome_reg <= 0;
      sucks_reg <= 0;
   end else begin
      state <= state;
      L_count <= L_count;
      result_prefix_reg <= result_prefix_reg;
      result_string_reg <= result_string_reg;
      done_reg <= done_reg;
      is_awesome_reg <= is_awesome_reg;
      sucks_reg <= sucks_reg;

      case (state)
         IDLE: begin
            if (start) begin
               state <= CHECK_FIRST;
            end
         end
         CHECK_FIRST: begin
            if (scoreboard_size == 0) begin
               is_awesome_reg <= 1;
               done_reg <= 1;
               state <= DONE;
            end else begin
               state <= CHECK_SUCKS;
            end
         end
         CHECK_SUCKS: begin
            sucks_reg = 0;
            sucks_reg = (names_above[0][95:0] == current_name[95:0]) || (names_above[1][95:0] == current_name[95:0]) || (names_above[2][95:0] == current_name[95:0]) || (names_above[3][95:0] == current_name[95:0]) || (names_above[4][95:0] == current_name[95:0]) || (names_above[5][95:0] == current_name[95:0]) || (names_above[6][95:0] == current_name[95:0]) || (names_above[7][95:0] == current_name[95:0]);
            if (sucks_reg) begin
               state <= DONE;
            end else begin
               state <= FIND_PREFIX;
            end
         end
         FIND_PREFIX: begin
            if (L_count < 13) begin
               wire any_match;
               assign any_match = 0;
               case (L_count)
                  1: any_match = (names_above[0][7:0] == current_name[7:0]) || (names_above[1][7:0] == current_name[7:0]) || (names_above[2][7:0] == current_name[7:0]) || (names_above[3][7:0] == current_name[7:0]) || (names_above[4][7:0] == current_name[7:0]) || (names_above[5][7:0] == current_name[7:0]) || (names_above[6][7:0] == current_name[7:0]) || (names_above[7][7:0] == current_name[7:0]);
                  2: any_match = (names_above[0][15:0] == current_name[15:0]) || (names_above[1][15:0] == current_name[15:0]) || (names_above[2][15:0] == current_name[15:0]) || (names_above[3][15:0] == current_name[15:0]) || (names_above[4][15:0] == current_name[15:0]) || (names_above[5][15:0] == current_name[15:0]) || (names_above[6][15:0] == current_name[15:0]) || (names_above[7][15:0] == current_name[15:0]);
                  3: any_match = (names_above[0][23:0] == current_name[23:0]) || (names_above[1][23:0] == current_name[23:0]) || (names_above[2][23:0] == current_name[23:0]) || (names_above[3][23:0] == current_name[23:0]) || (names_above[4][23:0] == current_name[23:0]) || (names_above[5][23:0] == current_name[23:0]) || (names_above[6][23:0] == current_name[23:0]) || (names_above[7][23:0] == current_name[23:0]);
                  4: any_match = (names_above[0][31:0] == current_name[31:0]) || (names_above[1][31:0] == current_name[31:0]) || (names_above[2][31:0] == current_name[31:0]) || (names_above[3][31:0] == current_name[31:0]) || (names_above[4][31:0] == current_name[31:0]) || (names_above[5][31:0] == current_name[31:0]) || (names_above[6][31:0] == current_name[31:0]) || (names_above[7][31:0] == current_name[31:0]);
                  5: any_match = (names_above[0][39:0] == current_name[39:0]) || (names_above[1][39:0] == current_name[39:0]) || (names_above[2][39:0] == current_name[39:0]) || (names_above[3][39:0] == current_name[39:0]) || (names_above[4][39:0] == current_name[39:0]) || (names_above[5][39:0] == current_name[39:0]) || (names_above[6][39:0] == current_name[39:0]) || (names_above[7][39:0] == current_name[39:0]);
                  6: any_match = (names_above[0][47:0] == current_name[47:0]) || (names_above[1][47:0] == current_name[47:0]) || (names_above[2][47:0] == current_name[47:0]) || (names_above[3][47:0] == current_name[47:0]) || (names_above[4][47:0] == current_name[47:0]) || (names_above[5][47:0] == current_name[47:0]) || (names_above[6][47:0] == current_name[47:0]) || (names_above[7][47:0] == current_name[47:0]);
                  7: any_match = (names_above[0][55:0] == current_name[55:0]) || (names_above[1][55:0] == current_name[55:0]) || (names_above[2][55:0] == current_name[55:0]) || (names_above[3][55:0] == current_name[55:0]) || (names_above[4][55:0] == current_name[55:0]) || (names_above[5][55:0] == current_name[55:0]) || (names_above[6][55:0] == current_name[55:0]) || (names_above[7][55:0] == current_name[55:0]);
                  8: any_match = (names_above[0][63:0] == current_name[63:0]) || (names_above[1][63:0] == current_name[63:0]) || (names_above[2][63:0] == current_name[63:0]) || (names_above[3][63:0] == current_name[63:0]) || (names_above[4][63:0] == current_name[63:0]) || (names_above[5][63:0] == current_name[63:0]) || (names_above[6][63:0] == current_name[63:0]) || (names_above[7][63:0] == current_name[63:0]);
                  9: any_match = (names_above[0][71:0] == current_name[71:0]) || (names_above[1][71:0] == current_name[71:0]) || (names_above[2][71:0] == current_name[71:0]) || (names_above[3][71:0] == current_name[71:0]) || (names_above[4][71:0] == current_name[71:0]) || (names_above[5][71:0] == current_name[71:0]) || (names_above[6][71:0] == current_name[71:0]) || (names_above[7][71:0] == current_name[71:0]);
                  10: any_match = (names_above[0][79:0] == current_name[79:0]) || (names_above[1][79:0] == current_name[79:0]) || (names_above[2][79:0] == current_name[79:0]) || (names_above[3][79:0] == current_name[79:0]) || (names_above[4][79:0] == current_name[79:0]) || (names_above[5][79:0] == current_name[79:0]) || (names_above[6][79:0] == current_name[79:0]) || (names_above[7][79:0] == current_name[79:0]);
                  11: any_match = (names_above[0][87:0] == current_name[87:0]) || (names_above[1][87:0] == current_name[87:0]) || (names_above[2][87:0] == current_name[87:0]) || (names_above[3][87:0] == current_name[87:0]) || (names_above[4][87:0] == current_name[87:0]) || (names_above[5][87:0] == current_name[87:0]) || (names_above[6][87:0] == current_name[87:0]) || (names_above[7][87:0] == current_name[87:0]);
                  12: any_match = (names_above[0][95:0] == current_name[95:0]) || (names_above[1][95:0] == current_name[95:0]) || (names_above[2][95:0] == current_name[95:0]) || (names_above[3][95:0] == current_name[95:0]) || (names_above[4][95:0] == current_name[95:0]) || (names_above[5][95:0] == current_name[95:0]) || (names_above[6][95:0] == current_name[95:0]) || (names_above[7][95:0] == current_name[95:0]);
                  13: any_match = (names_above[0][103:0] == current_name[103:0]) || (names_above[1][103:0] == current_name[103:0]) || (names_above[2][103:0] == current_name[103:0]) || (names_above[3][103:0] == current_name[103:0]) || (names_above[4][103:0] == current_name[103:0]) || (names_above[5][103:0] == current_name[103:0]) || (names_above[6][103:0] == current_name[103:0]) || (names_above[7][103:0] == current_name[103:0]);
               endcase

               if (any_match) begin
                  L_count <= L_count + 1;
                  state <= FIND_PREFIX;
               end else begin
                  result_prefix_reg <= L_count;
                  case (L_count)
                     1: result_string_reg <= {120{1'b0}, current_name[7:0]};
                     2: result_string_reg <= {112{1'b0}, current_name[15:0]};
                     3: result_string_reg <= {104{1'b0}, current_name[23:0]};
                     4: result_string_reg <= {96{1'b0}, current_name[31:0]};
                     5: result_string_reg <= {88{1'b0}, current_name[39:0]};
                     6: result_string_reg <= {80{1'b0}, current_name[47:0]};
                     7: result_string_reg <= {72{1'b0}, current_name[55:0]};
                     8: result_string_reg <= {64{1'b0}, current_name[63:0]};
                     9: result_string_reg <= {56{1'b0}, current_name[71:0]};
                    10: result_string_reg <= {48{1'b0}, current_name[79:0]};
                    11: result_string_reg <= {40{1'b0}, current_name[87:0]};
                    12: result_string_reg <= {32{1'b0}, current_name[95:0]};
                    13: result_string_reg <= {12{1'b0}, current_name[103:0]};
                  endcase
                  done_reg <= 1;
                  state <= DONE;
               end
            end
            else begin
               result_prefix_reg <=13;
               result_string_reg <= {12{1'b0}, current_name[103:0]};
               done_reg <=1;
               state <= DONE;
            end
         end
         DONE: state <= DONE;
      endcase
   end
endmodule