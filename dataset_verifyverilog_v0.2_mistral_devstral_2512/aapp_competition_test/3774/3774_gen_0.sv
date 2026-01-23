module max_chessmen (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] m,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SWAP,
    CALCULATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] n_reg, m_reg;
  reg [31:0] result_reg;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 32'b0;
      n_reg <= 4'b0;
      m_reg <= 4'b0;
    end else begin
      current_state <= next_state;
      if (current_state == DONE) begin
        result <= result_reg;
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SWAP;
      end
      SWAP: next_state = CALCULATE;
      CALCULATE: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Data processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg <= 4'b0;
      m_reg <= 4'b0;
      result_reg <= 32'b0;
    end else begin
      case (current_state)
        IDLE: begin
          n_reg <= n;
          m_reg <= m;
        end
        SWAP: begin
          if (n_reg > m_reg) begin
            n_reg <= m_reg;
            m_reg <= n_reg;
          end
        end
        CALCULATE: begin
          if (n_reg == 1) begin
            reg [3:0] r = m_reg % 6;
            if (r == 0) result_reg = m_reg;
            else if (r <= 3) result_reg = m_reg - r;
            else result_reg = m_reg - (6 - r);
          end else if (n_reg == 2) begin
            if (m_reg == 2) result_reg = 0;
            else if (m_reg == 3) result_reg = 4;
            else if (m_reg == 7) result_reg = 12;
            else result_reg = n_reg * m_reg;
          end else begin
            if ((n_reg * m_reg) % 2 == 1) result_reg = n_reg * m_reg - 1;
            else result_reg = n_reg * m_reg;
          end
        end
        DONE: begin
          // Hold result
        end
      endcase
    end
  end

endmodule