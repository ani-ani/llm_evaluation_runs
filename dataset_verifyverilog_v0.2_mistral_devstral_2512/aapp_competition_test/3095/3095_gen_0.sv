module extremely_cool_checker (
  input clk,
  input rst_n,
  input start,
  input [3:0] rows,
  input [3:0] cols,
  input [7:0] matrix_data [0:63],
  output reg is_cool,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECKING,
    DONE
  } state_t;

  state_t state;
  reg [3:0] r;
  reg [3:0] c;
  reg [7:0] a, b, c_val, d;
  reg check_passed;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      r <= 0;
      c <= 0;
      is_cool <= 1'b0;
      done <= 1'b0;
      check_passed <= 1'b1;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            if (rows < 2 || cols < 2) begin
              is_cool <= 1'b1;
              done <= 1'b1;
              state <= DONE;
            end else begin
              r <= 0;
              c <= 0;
              check_passed <= 1'b1;
              state <= CHECKING;
            end
          end
        end
        CHECKING: begin
          a <= matrix_data[r*8 + c];
          b <= matrix_data[r*8 + (c+1)];
          c_val <= matrix_data[(r+1)*8 + c];
          d <= matrix_data[(r+1)*8 + (c+1)];

          if (a + d > b + c_val) begin
            check_passed <= 1'b0;
          end

          if (c == cols - 2) begin
            if (r == rows - 2) begin
              is_cool <= check_passed;
              done <= 1'b1;
              state <= DONE;
            end else begin
              r <= r + 1;
              c <= 0;
            end
          end else begin
            c <= c + 1;
          end
        end
        DONE: begin
          // Hold state until reset
        end
      endcase
    end
  end

endmodule