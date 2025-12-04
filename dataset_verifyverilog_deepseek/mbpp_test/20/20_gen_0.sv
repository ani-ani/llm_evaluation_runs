module woodall_checker(input clk, input rst_n, input [15:0] x_in, input start,
                              output reg is_woodall, output reg done);
  typedef enum logic [2:0] {IDLE, CHECK_EVEN, ADD_ONE, DIVIDE, CHECK_EQUAL, DONE} state_t;
  state_t state_reg, state_next;
  reg [15:0] x_reg, x_next;
  reg [15:0] p_reg, p_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      x_reg <= 16'b0;
      p_reg <= 16'b0;
      is_woodall <= 1'b0;
      done <= 1'b0;
    end else begin
      state_reg <= state_next;
      x_reg <= x_next;
      p_reg <= p_next;
      case (state_next)
        DONE: begin
          done <= 1'b1;
          is_woodall <= (state_reg == CHECK_EQUAL) ? (p_reg == x_reg) : is_woodall;
        end
        default: done <= 1'b0;
      endcase
    end
  end

  always_comb begin
    state_next = state_reg;
    x_next = x_reg;
    p_next = p_reg;

    case (state_reg)
      IDLE: begin
        if (start) begin
          x_next = x_in;
          state_next = CHECK_EVEN;
        end
      end

      CHECK_EVEN: begin
        if (x_reg[0] == 1'b0 || x_reg == 16'b0) begin
          is_woodall = 1'b0;
          state_next = DONE;
        end else begin
          state_next = ADD_ONE;
        end
      end

      ADD_ONE: begin
        x_next = x_reg + 16'b1;
        p_next = 0;
        state_next = DIVIDE;
      end

      DIVIDE: begin
        if (x_reg[0]) begin
          state_next = CHECK_EQUAL;
        end else begin
          x_next = x_reg >> 1;
          p_next = p_reg + 1;
          if (p_next > x_next) begin
            is_woodall = 1'b0;
            state_next = DONE;
          end else begin
            state_next = DIVIDE;
          end
        end
      end

      CHECK_EQUAL: begin
        is_woodall = (p_reg == x_reg);
        state_next = DONE;
      end

      DONE: begin
        if (!start) state_next = IDLE;
      end
    endcase
  end
endmodule