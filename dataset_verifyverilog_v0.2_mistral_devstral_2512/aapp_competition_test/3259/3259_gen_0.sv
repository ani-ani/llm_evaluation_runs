module aladin_box_sim (
  input clk,
  input rst_n,
  input start,
  input [2:0] op_type,
  input [2:0] L,
  input [2:0] R,
  input [7:0] A,
  input [7:0] B,
  output reg [7:0] result,
  output reg done
);

  // Internal registers
  reg [2:0] current_idx;
  reg [7:0] boxes [0:7];
  reg [7:0] sum;
  reg [15:0] temp_mult;
  reg [7:0] temp_mod;
  reg [7:0] counter;
  reg [1:0] state;
  reg [1:0] sub_state;

  // State definitions
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE = 2'b10;

  // Sub-state definitions
  localparam CALC_VAL = 2'b00;
  localparam STORE_SUM = 2'b01;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sub_state <= CALC_VAL;
      current_idx <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        boxes[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            current_idx <= L;
            sum <= 0;
            result <= 0;
            done <= 0;
          end
        end
        PROCESSING: begin
          case (sub_state)
            CALC_VAL: begin
              if (op_type == 0) begin
                // Update operation: calculate (i-L+1)*A % B
                temp_mult <= (current_idx - L + 1) * A;
                temp_mod <= temp_mult % B;
                sub_state <= STORE_SUM;
              end else begin
                // Query operation: accumulate box value
                sum <= sum + boxes[current_idx];
                sub_state <= STORE_SUM;
              end
            end
            STORE_SUM: begin
              if (op_type == 0) begin
                boxes[current_idx] <= temp_mod;
              end
              if (current_idx == R) begin
                state <= DONE;
                if (op_type == 1) begin
                  result <= sum;
                end
              end else begin
                current_idx <= current_idx + 1;
                sub_state <= CALC_VAL;
              end
            end
          endcase
        end
        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule