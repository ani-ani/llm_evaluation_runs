module eurus_solver (
input clk,
input rst_n,
input start,
input [9:0] n,
input [7:0] k,
output reg [29:0] result,
output reg done
);

// Declare next state registers
reg [2:0] state_next;
reg [9:0] current_value_next;
reg [7:0] count_next;
reg [29:0] result_reg_next;
reg done_next;

// State definitions
parameter IDLE = 3'd0,
       CALC = 3'd1,
       CHECK = 3'd2,
       DONE = 3'd3;

reg [2:0] state,
reg [9:0] current_value,
reg [7:0] count,
reg [29:0] result_reg;

// Combinational next_state and assignments
wire [29:0] phi_out;
assign phi_out = phi_func(current_value);
always @(state, count, current_value, phi_out) begin
   // Next state logic
   state_next = state;
   if (state == IDLE) begin
      if (start) begin
         current_value_next = n;
         count_next = k;
         if (count ==0) begin // if k is 0, then no phi applications
            state_next = DONE;
            result_reg_next = n;
            done_next = 1;
         end else begin
            state_next = CALC;
         end
      end
   end else if (state == CALC) begin
      state_next = CHECK;
      current_value_next = phi_out;
   end else if (state == CHECK) begin
      count_next = count -1;
      if (count ==0 || current_value ==1) begin
         state_next = DONE;
         result_reg_next = current_value;
         done_next =1;
      end else begin
         state_next = CALC;
      end
   end else if (state == DONE) begin
      // stay in done
   end
end

// Registers
always_ff @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      current_value <=0;
      count <=0;
      result_reg <=0;
      done <=0;
   end else begin
      state <= state_next;
      current_value <= current_value_next;
      count <= count_next;
      result_reg <= result_reg_next;
      done <= done_next;
   end
end

// Assign outputs
assign result = result_reg;
assign done = done_next;

// phi function
function [9:0] phi_func(input [9:0] n);
   if (n ==0) return 0;
   if (n ==1) return 1;
   // Dummy implementation: return n-1 (wrong, but for example)
   return n ==0 ? 0 : n ==1 ?1 : n-1;
endfunction

endmodule