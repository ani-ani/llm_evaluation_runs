module roman_digits_solver (
  input clk,
  input rst_n,
  input start,
  input [29:0] n,
  output reg [59:0] result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] CHECK_RANGE = 3'b001;
  localparam [2:0] COMPUTE_SMALL = 3'b010;
  localparam [2:0] COMPUTE_LARGE = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;
  reg [5:0] counter = 0;

  // Precomputed values for n=1 to 20
  wire [59:0] small_result;
  assign small_result = (n == 1) ? 1 :
                       (n == 2) ? 2 :
                       (n == 3) ? 4 :
                       (n == 4) ? 6 :
                       (n == 5) ? 9 :
                       (n == 6) ? 12 :
                       (n == 7) ? 16 :
                       (n == 8) ? 20 :
                       (n == 9) ? 25 :
                       (n == 10) ? 30 :
                       (n == 11) ? 36 :
                       (n == 12) ? 341 :
                       (n == 13) ? 390 :
                       (n == 14) ? 439 :
                       (n == 15) ? 488 :
                       (n == 16) ? 537 :
                       (n == 17) ? 586 :
                       (n == 18) ? 635 :
                       (n == 19) ? 684 :
                       (n == 20) ? 733 : 0;

  // Compute large result: 49 * n - 247
  wire [59:0] large_result = (n << 5) + (n << 4) + n - 247;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      if (state == COMPUTE_SMALL || state == COMPUTE_LARGE) begin
        counter <= counter + 1;
      end
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_RANGE;
        end
      end
      CHECK_RANGE: begin
        if (n <= 20) begin
          next_state = COMPUTE_SMALL;
        end else begin
          next_state = COMPUTE_LARGE;
        end
      end
      COMPUTE_SMALL: begin
        if (counter >= 19) begin
          next_state = DONE;
        end
      end
      COMPUTE_LARGE: begin
        if (counter >= 19) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        COMPUTE_SMALL: begin
          if (counter == 19) begin
            result <= small_result;
          end
        end
        COMPUTE_LARGE: begin
          if (counter == 19) begin
            result <= large_result;
          end
        end
        DONE: begin
          done <= 1;
        end
        default: begin
          result <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule