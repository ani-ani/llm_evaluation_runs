module perfect_square_checker (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  output reg done,
  output reg is_square
);

  typedef enum {IDLE, CHECKING} state_t;
  state_t state, next_state;
  reg [7:0] i, next_i;
  wire [15:0] square = i * i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      is_square <= 1'b0;
      i <= 8'd0;
    end else begin
      state <= next_state;
      done <= (next_state == IDLE) ? 1'b0 : 1'b0;
      is_square <= (next_state == IDLE) ? 1'b0 : 1'b0;
      if (next_state == CHECKING)  begin
        i <= next_i;
      end
      done <= (next_state == CHECKING && (square == n || square > n)) ? 1'b1 : done;
      is_square <= (next_state == CHECKING && square == n) ? 1'b1 :
                   (next_state == CHECKING && square > n) ? 1'b0 : is_square;
    end
  end

  always_comb begin
    next_state = state;
    next_i = i;

    case (state)
      IDLE: begin
        if (start) begin
          if (n == 16'd0) begin
            next_state = IDLE;
          end else begin
            next_state = CHECKING;
            next_i = 8'd1;
          end
        end
      end

      CHECKING: begin
        if (square < n) begin
          next_i = i + 1;
          next_state = CHECKING;
        end else begin
          next_state = IDLE;
        end
      end
    endcase
  end

  always @(*) begin
    if (!rst_n) begin
      done = 1'b0;
      is_square = 1'b0;
    end else if (state == IDLE && start && n == 16'd0) begin
      done = 1'b1;
      is_square = 1'b1;
    end else begin
      done = (state == CHECKING && (square == n || square > n));
      is_square = (state == CHECKING && square == n);
    end
  end

endmodule