module balanced_concatenation (
  input clk,
  input rst_n,
  input start,
  input [7:0] str1_bits,
  input [7:0] str2_bits,
  output reg result,
  output reg done
);
  localparam [1:0] IDLE = 2'b00,
                   CHECK_ORDER1 = 2'b01,
                   CHECK_ORDER2 = 2'b10,
                   DONE = 2'b11;

  reg [1:0] state, next_state;
  reg [3:0] cycle_count;
  reg signed [4:0] balance;
  reg valid_flag;
  reg order1_valid, order2_valid;
  reg current_bit;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      cycle_count <= 0;
      balance <= 0;
      valid_flag <= 1;
      order1_valid <= 0;
      order2_valid <= 0;
    end else begin
      case(state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= CHECK_ORDER1;
            cycle_count <= 0;
            balance <= 0;
            valid_flag <= 1;
          end
        end

        CHECK_ORDER1: begin
          current_bit = (cycle_count < 8) ? str1_bits[cycle_count] : str2_bits[cycle_count - 8];
          balance <= (current_bit == 0) ? balance + 1 : balance - 1;
          if (balance < 0) valid_flag <= 0;

          if (cycle_count < 15) begin
            cycle_count <= cycle_count + 1;
          end else begin
            order1_valid <= valid_flag && (balance == 0);
            state <= order1_valid ? DONE : CHECK_ORDER2;
            cycle_count <= 0;
            balance <= 0;
            valid_flag <= 1;
          end
        end

        CHECK_ORDER2: begin
          current_bit = (cycle_count < 8) ? str2_bits[cycle_count] : str1_bits[cycle_count - 8];
          balance <= (current_bit == 0) ? balance + 1 : balance - 1;
          if (balance < 0) valid_flag <= 0;

          if (cycle_count < 15) begin
            cycle_count <= cycle_count + 1;
          end else begin
            order2_valid <= valid_flag && (balance == 0);
            state <= DONE;
            cycle_count <= 0;
            balance <= 0;
            valid_flag <= 1;
          end
        end

        DONE: begin
          result <= order1_valid | order2_valid;
          done <= 1;
          if (!start) state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule