module factorial_trailing(
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output reg [11:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    COMPUTE_FACT,
    REMOVE_ZEROES,
    EXTRACT_DIGITS,
    DONE
  } state_t;

  state_t state;
  reg [63:0] factorial;
  reg [5:0] counter;
  reg [63:0] temp;
  reg [11:0] bcd_result;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      factorial <= 64'd1;
      counter <= 6'd0;
      temp <= 64'd0;
      bcd_result <= 12'd0;
      result <= 12'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE_FACT;
            factorial <= 64'd1;
            counter <= n;
          end
        end

        COMPUTE_FACT: begin
          if (counter > 0) begin
            factorial <= factorial * counter;
            counter <= counter - 1;
          end else begin
            state <= REMOVE_ZEROES;
            temp <= factorial;
          end
        end

        REMOVE_ZEROES: begin
          if (temp % 10 == 0) begin
            temp <= temp / 10;
          end else begin
            state <= EXTRACT_DIGITS;
          end
        end

        EXTRACT_DIGITS: begin
          bcd_result <= 0;
          for (int i = 0; i < 3; i++) begin
            bcd_result[4*i +:4] <= temp % 10;
            temp <= temp / 10;
          end
          state <= DONE;
        end

        DONE: begin
          result <= bcd_result;
          done <= 1'b1;
          if (start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule