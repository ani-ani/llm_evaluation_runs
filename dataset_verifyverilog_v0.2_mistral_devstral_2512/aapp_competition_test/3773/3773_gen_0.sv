module grundy_pile_solver (
  input clk,
  input rst_n,
  input start,
  input [31:0] A_i,
  input [31:0] K_i,
  output reg [31:0] grundy_out,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK,
    UPDATE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [31:0] A_reg, K_reg;
  reg [7:0] iter_count;
  reg [31:0] quotient, remainder, temp;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      A_reg <= 32'h0;
      K_reg <= 32'h0;
      iter_count <= 8'h0;
      grundy_out <= 32'h0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      if (state == IDLE && start) begin
        A_reg <= A_i;
        K_reg <= K_i;
        iter_count <= 8'h0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CHECK;
      end
      CHECK: begin
        if (A_reg < K_reg || (A_reg % K_reg == 0)) begin
          next_state = DONE;
        end else if (iter_count < 8'd127) begin
          next_state = UPDATE;
        end else begin
          next_state = DONE;
        end
      end
      UPDATE: begin
        next_state = CHECK;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      quotient <= 32'h0;
      remainder <= 32'h0;
      temp <= 32'h0;
    end else begin
      case (state)
        CHECK: begin
          if (A_reg < K_reg) begin
            grundy_out <= 32'h0;
            done <= 1'b1;
          end else if (A_reg % K_reg == 0) begin
            grundy_out <= A_reg / K_reg;
            done <= 1'b1;
          end
        end
        UPDATE: begin
          quotient = A_reg / K_reg;
          remainder = A_reg % K_reg;
          if (remainder != 0) begin
            temp = remainder / (quotient + 1'b1);
            A_reg = A_reg - ((quotient + 1'b1) * temp + 1'b1);
          end
          iter_count = iter_count + 1'b1;
        end
        DONE: begin
          done <= 1'b1;
        end
        default: ;
      endcase
    end
  end

endmodule