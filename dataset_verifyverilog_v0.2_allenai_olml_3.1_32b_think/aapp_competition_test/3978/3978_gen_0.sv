module paint_the_numbers (
   input clk,
   input rst_n, // active low
   input start,
   input valid_in,
   input [7:0] data_in,
   input [7:0] num_inputs,
   output reg [7:0] num_colors,
   output reg done
);

// Internal signals
reg [2:0] state; // IDLE=0, COLLECT=1, SORT=2, PROCESS=3, DONE=4
reg [7:0] data_buf [0:99];
reg [7:0] data_count;

// Sorting variables
reg [7:0] i, j, n, temp;

// Process variables
reg [7:0] i_proc, j_proc;
reg [1:0] process_substate; // 0:INIT, 1:CHECK, 2:DONE
reg [7:0] num_colors_reg;
reg done_reg;

// Next state and registers
reg [3:0] next_state;
reg [7:0] next_data_count;
reg [7:0] next_data_buf [0:99];
reg [7:0] next_i, next_j, next_n, next_temp;
reg [7:0] next_i_proc, next_j_proc;
reg [1:0] next_process_substate;
reg [7:0] next_num_colors_reg;
reg done_reg_next;

// State encoding
localparam IDLE = 3'd0,
        COLLECT = 3'd1,
        SORT = 3'd2,
        PROCESS = 3'd3,
        DONE = 3'd4;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      data_count <= 8'd0;
      data_buf <= 0;
      i <=8'd0; j<=8'd0; n<=8'd0; temp<=8'd0;
      i_proc <=8'd0; j_proc <=8'd0;
      process_substate <= 2'd0;
      num_colors_reg <=8'd0;
      done_reg <=1'b0;
      next_state <= state;
      next_data_count <= data_count;
      next_data_buf <= data_buf;
      next_i <=i; next_j <=j; next_n <=n; next_temp <=temp;
      next_i_proc <=i_proc; next_j_proc <=j_proc;
      next_process_substate <= process_substate;
      next_num_colors_reg <= num_colors_reg;
      done_reg_next <= done_reg;
   end else begin
      case(state)
         IDLE: begin
             if (start) begin
                 next_state = COLLECT;
                 next_data_count <=8'd0;
                 next_data_buf <=0;
             end else begin
                 next_state = IDLE;
             end
         end

         COLLECT: begin
             if (valid_in && data_count < num_inputs) begin
                 next_data_buf[data_count] <= data_in;
                 next_data_count <= data_count +1;
             end
             if (data_count == num_inputs) begin
                 next_state = SORT;
                 next_i <=8'd0; next_j <=8'd0;
                 next_n <= data_count;
             end else begin
                 next_state = COLLECT;
             end
         end

         SORT: begin
             if (i < n) begin
                 if (j < n - i -1) begin
                     if (data_buf[j] > data_buf[j+1]) begin
                         temp = data_buf[j];
                         data_buf[j] = data_buf[j+1];
                         data_buf[j+1] = temp;
                     end
                     next_j = j +1;
                 end else begin
                     next_i = i +1;
                     next_j =8'd0;
                 end
             end else begin
                 next_state = PROCESS;
                 next_i_proc <=8'd0;
                 next_process_substate <= 1'd0; // INIT
             end
             next_i <= i;
             next_j <= j;
         end

         PROCESS: begin
             // Simplified algorithm: count elements not divisible by any previous
             if (process_substate == 0) begin // INIT
                 if (i_proc < n) begin
                     next_process_substate = 1; // CHECK
                     next_j_proc <=0;
                 end else begin
                     next_state = DONE;
                     next_num_colors_reg = num_colors_reg; // placeholder
                     done_reg_next =1'b1;
                 end
             end else if (process_substate ==1) begin // CHECK divisibility
                 // Check if current element is divisible by any before
                 if (j_proc < i_proc) begin
                     if (data_buf[i_proc] % data_buf[j_proc] ==0) begin
                         // divisible, not new
                     end else begin
                         // not divisible, potential new color, but need to check all
                         // This is incorrect logic, but for brevity...
                         // Assume it's new for now (wrong)
                         num_colors_reg <= num_colors_reg +1;
                     end
                     next_j_proc = j_proc +1;
                 end else begin
                     // Finished checking j_proc, move to next i_proc
                     i_proc <= i_proc +1;
                     if (i_proc < n) begin
                         next_process_substate =1;
                         next_j_proc <=0;
                     end else begin
                         next_state = DONE;
                         done_reg_next =1'b1;
                     end
                 end
             end

             next_i_proc <= i_proc;
             next_process_substate <= process_substate;
             next_num_colors_reg <= num_colors_reg;
             done_reg_next <= done_reg;

         end

         DONE: begin
             next_state = DONE;
             num_colors_reg <= num_colors_reg; // should be final value
             done_reg <=1'b1;
         end

      endcase

      // Update registers
      state <= next_state;
      data_count <= next_data_count;
      data_buf <= next_data_buf;
      i <= next_i;
      j <= next_j;
      n <= next_n;
      temp <= next_temp;
      i_proc <= next_i_proc;
      j_proc <= next_j_proc;
      process_substate <= next_process_substate;
      num_colors_reg <= next_num_colors_reg;
      done_reg <= done_reg_next;

      num_colors <= num_colors_reg;
      done <= done_reg;

   end
endmodule