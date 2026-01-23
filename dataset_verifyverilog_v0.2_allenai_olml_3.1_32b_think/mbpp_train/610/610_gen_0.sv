module remove_kth_element (
   input clk,
   input rst_n,
   input start,
   input [3:0] k,
   input [4:0] data_in_index,
   input [7:0] data_in,
   input data_in_valid,
   output reg [7:0] result [0:15],
   output reg [4:0] result_count,
   output reg done
);

localparam IDLE = 3'd0,
INPUT_FILL = 3'd1,
PROCESSING = 3'd2,
OUTPUT = 3'd3,
DONE_STATE = 3'd4;

reg [7:0] array_reg [0:15];
reg [4:0] input_count;
reg [2:0] state;
reg [3:0] k_reg;
reg [7:0] temp_result [0:14];
reg [3:0] process_count;
reg done;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      array_reg <= 16'b0;
      input_count <= 5'b0;
      state <= IDLE;
      k_reg <= 4'b0;
      temp_result <= {15{16'b0}};
      process_count <= 4'b0;
      done <= 1'b0;
      result <= 16{16'b0};
      result_count <= 5'b0;
   end else begin
      reg [2:0] next_state;
      next_state = state;
      case (state)
         IDLE: begin
            if (data_in_valid && input_count < 16) begin
               next_state = INPUT_FILL;
            end else if (start && input_count == 16) begin
               k_reg <= k;
               next_state = PROCESSING;
            end
         end
         INPUT_FILL: begin
            array_reg[input_count] <= data_in;
            input_count <= input_count + 1;
            if (input_count < 16) begin
               next_state = INPUT_FILL;
            end else begin
               next_state = IDLE;
            end
         end
         PROCESSING: begin
            if (process_count < 15) begin
               if (process_count < (k_reg - 1)) begin
                  temp_result[process_count] <= array_reg[process_count];
               end else begin
                  temp_result[process_count] <= array_reg[process_count + 1];
               end
               process_count <= process_count + 1;
               next_state = PROCESSING;
            end else begin
               next_state = OUTPUT;
            end
         end
         OUTPUT: begin
            result[0:14] <= temp_result;
            result[15] <= 16'b0;
            result_count <= 15;
            done <= 1'b1;
            next_state = DONE_STATE;
         end
         DONE_STATE: begin
            next_state = DONE_STATE;
         end
      endcase
      state <= next_state;
   end
endmodule