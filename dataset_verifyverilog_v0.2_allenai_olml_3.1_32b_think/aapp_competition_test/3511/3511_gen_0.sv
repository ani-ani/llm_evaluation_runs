module pokenom_go (
input clk,
input rst_n, // active low
input start,
input [1:0] query_type,
input [3:0] u,
input [3:0] v,
output reg [63:0] result,
output reg done
);
parameter MOD = 1000000007;

reg [7:0] state;
reg [3:0] u_val, v_val;
reg [1:0] query_type_reg;
reg [7:0] current_box;
reg [3:0] sum_index;
reg [63:0] E [8], E2 [8], sum_val;
reg [63:0] inv_len_reg;
reg [3:0] length_reg;
reg [63:0] temp;
reg is_type2;

localparam IDLE = 4'd0, CAPTURE=4'd1, UPDATE=4'd2, SUM=4'd3, DONE=4'd4;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      u_val <= 4'd0;
      v_val <= 4'd0;
      query_type_reg <= 2'd0;
      current_box <= 4'd0;
      sum_index <= 4'd0;
      E <= {8{64'd0}};
      E2 <= {8{64'd0}};
      inv_len_reg <= 64'd0;
      length_reg <= 4'd0;
      sum_val <= 64'd0;
      temp <= 64'd0;
      is_type2 <= 1'b0;
      done <= 1'b0;
      result <= 64'd0;
   end else begin
      case(state)
         IDLE: begin
            if (start) begin
               u_val <= u;
               v_val <= v;
               query_type_reg <= query_type;
               is_type2 <= (query_type_reg == 2);
               if (query_type_reg == 2) begin
                  state <= SUM;
                  sum_index <= 1;
               end else begin
                  length_reg <= v_val - u_val +1;
                  case(length_reg)
                     1: inv_len_reg <= 1;
                     2: inv_len_reg <= 500000004;
                     3: inv_len_reg <= 333333336;
                     4: inv_len_reg <= 250000002;
                     5: inv_len_reg <= 400000003;
                     6: inv_len_reg <= 166666668;
                     7: inv_len_reg <= 142857144;
                     8: inv_len_reg <= 125000001;
                     default: inv_len_reg <= 1;
                  endcase
                  state <= UPDATE;
                  current_box <= u_val;
               end
            end else begin
               state <= IDLE;
            end
         end
         UPDATE: begin
            if (current_box > v_val) begin
               state <= DONE;
            end else begin
               temp = E[current_box -1];
               E[current_box -1] = mod_it(E[current_box -1] + inv_len_reg, MOD);
               E2[current_box -1] = mod_it(E2[current_box -1] + (2*temp) + inv_len_reg, MOD);
               current_box <= current_box +1;
               state <= UPDATE;
            end
         end
         SUM: begin
            if (sum_index >8) begin
               result <= sum_val;
               state <= DONE;
            end else begin
               sum_val = mod_it(sum_val + E2[sum_index -1], MOD);
               sum_index <= sum_index +1;
               state <= SUM;
            end
         end
         DONE: begin
            done <= 1'b1;
            if (is_type2) begin
               result <= sum_val;
            end
            if (!start) begin
               state <= IDLE;
               done <=1'b0;
            end
         end
      endcase
   end
end

function automatic int mod_it;
input int a, int mod_val;
begin
   mod_it = a % mod_val;
   if (mod_it <0) mod_it += mod_val;
endfunction

endmodule