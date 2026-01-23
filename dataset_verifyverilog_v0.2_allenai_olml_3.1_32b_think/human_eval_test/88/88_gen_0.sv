module sort_array (
input clk,
input rst_n,
input start,
input [2:0] array_length,
input [7:0] array_in [0:7],
output reg [7:0] array_out [0:7],
output reg done
);

localparam IDLE = 3'd0,
CHECK_SUM = 3'd1,
SORT_PASS = 3'd2,
VERIFY_DONE = 3'd3,
DONE = 3'd4;

reg [2:0] captured_array_length;
reg [7:0] captured_array_in [0:7];
reg [7:0] array_reg [0:7];
reg [2:0] state;
reg [2:0] max_passes;
reg [2:0] current_pass;
reg [2:0] current_index;
reg [1:0] target_order;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      captured_array_length <= 3'b0;
captured_array_in <= 8'b0;
array_reg <= 8'b0;
state <= 3'b0;
max_passes <= 3'b0;
current_pass <= 3'b0;
current_index <= 3'b0;
target_order <= 2'b00;
done <= 1'b0;
   end else begin
      case (state)
         3'b000: // IDLE
            if (start) begin
               state <= 3'b001;
captured_array_length <= array_length;
captured_array_in <= array_in;
            end
done <= 1'b0;
         endcase
         3'b001: // CHECK_SUM
            if (captured_array_length == 0 || captured_array_length == 1) begin
               array_reg <= captured_array_in;
state <= VERIFY_DONE;
            end else begin
               target_order <= (captured_array_in[0] ^ captured_array_in[captured_array_length - 1]) ? 2'b00 : 2'b01;
               max_passes <= captured_array_length - 1;
current_pass <= 3'b001;
current_index <= 3'b000;
array_reg <= captured_array_in;
state <= SORT_PASS;
            end
         endcase
         3'b010: // SORT_PASS
            if (current_pass > max_passes) begin
               state <= VERIFY_DONE;
            end else begin
               if (current_index <= (captured_array_length - current_pass - 1)) begin
                  if ((target_order == 2'b00 && array_reg[current_index] > array_reg[current_index + 1]) ||
                      (target_order == 2'b01 && array_reg[current_index] < array_reg[current_index + 1])) begin
                     array_reg[current_index] <= array_reg[current_index + 1];
                     array_reg[current_index + 1] <= array_reg[current_index]; // Swap
                  end
                  current_index <= current_index + 1;
               end else begin
                  current_pass <= current_pass + 1;
current_index <= 3'b000;
               end
            end
         endcase
         3'b011: // VERIFY_DONE
            state <= DONE;
done <= 1'b1;
         endcase
         3'b100: // DONE
done <= 1'b1;
         endcase
      endcase
      array_out <= array_reg;
   end
endmodule