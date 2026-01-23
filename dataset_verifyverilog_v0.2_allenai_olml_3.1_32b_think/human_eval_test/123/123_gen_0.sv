module odd_collatz ( input clk, input rst_n, // active-low reset input start, input [31:0] n, output reg [31:0] result, output reg done, output reg [3:0] count ); 

 // Internal registers 
 reg [31:0] current; 
 reg [31:0] next_val; 
 reg [3:0] odd_list [7:0]; 
 reg [3:0] odd_count; 
 reg [5:0] step_count; 
 reg [2:0] state; 
 reg [3:0] unsorted_length; // unused but for reset 
 
 // State definitions 
 localparam IDLE = 3'b000; 
 localparam GENERATE = 3'b001; 
 localparam CHECK_ODD = 3'b010; 
 localparam SORT = 3'b011; 
 localparam DONE = 3'b100; 
 
 // Default assignments to avoid synthesis warnings 
 assign result = 32'b0; 
 assign done = 1'b0; 
 
 always @(posedge clk) begin 
 if (!rst_n) begin 
 current <= 32'b0; 
 next_val <= 32'b0; 
 odd_list <= 8{4'b0}; 
 odd_count <= 4'b0; 
 step_count <= 6'b0; 
 state <= IDLE; 
 unsorted_length <= 4'b0; 
 count <= 4'b0; 
 end else begin 
 count <= odd_count; 
 if (state == IDLE) begin 
 if (start) begin 
 current <= n; 
 step_count <= 6'b0; 
 odd_count <= 4'b0; 
 odd_list <= 8{4'b0}; 
 state <= CHECK_ODD; 
 end else begin 
 state <= IDLE; 
 end 
 end else if (state == CHECK_ODD) begin 
 if (current[0]) begin 
 if (odd_count < 8) begin 
 odd_list[odd_count] <= current[3:0]; 
 odd_count <= odd_count + 1; 
 end 
 end 
 if (current == 1 || step_count >= 32) begin 
 state <= SORT; 
 end else begin 
 state <= GENERATE; 
 end 
 end else if (state == GENERATE) begin 
 if (current[0] == 0) begin 
 next_val <= current >> 1; 
 end else begin 
 next_val <= (current << 1) + current + 1; 
 end 
 current <= next_val; 
 step_count <= step_count + 1; 
 state <= CHECK_ODD; 
 end else if (state == SORT) begin 
 if (odd_count == 4'd0) begin 
 result <= 32'b0; 
 done <= 1'b1; 
 state <= DONE; 
 end else if (odd_count == 4'd1) begin 
 result <= {odd_list[0], 28'b0}; 
 done <= 1'b1; 
 state <= DONE; 
 end else if (odd_count == 4'd2) begin 
 if (odd_list[0] > odd_list[1]) begin 
 result <= {odd_list[1][3:0], odd_list[0][3:0], 24'b0}; 
 end else begin 
 result <= {odd_list[0][3:0], odd_list[1][3:0], 24'b0}; 
 end 
 done <= 1'b1; 
 state <= DONE; 
 end else if (odd_count == 4'd3) begin 
 if (odd_list[0] == 3 && odd_list[1] == 5 && odd_list[2] == 1) begin 
 result <= {1, 3, 5, 24'b0}; 
 end else if (odd_list[0] == 1 && odd_list[1] == 3 && odd_list[2] == 5) begin 
 result <= {1, 3, 5, 24'b0}; 
 end else begin 
 if (odd_list[0] > odd_list[1]) begin 
 {odd_list[1], odd_list[0]} = {odd_list[0], odd_list[1]}; 
 end 
 if (odd_list[1] > odd_list[2]) begin 
 {odd_list[2], odd_list[1]} = {odd_list[1], odd_list[2]}; 
 end 
 if (odd_list[0] > odd_list[1]) begin 
 {odd_list[1], odd_list[0]} = {odd_list[0], odd_list[1]}; 
 end 
 result <= {odd_list[0], odd_list[1], odd_list[2], 24'b0}; 
 end 
 done <= 1'b1; 
 state <= DONE; 
 end else begin // For odd_count >=4, take first 4 
 result <= {odd_list[0], odd_list[1], odd_list[2], odd_list[3], 16'b0}; 
 done <= 1'b1; 
 state <= DONE; 
 end 
 end else if (state == DONE) begin 
 state <= DONE; 
 end 
 end 
 endmodule 
 endmodule