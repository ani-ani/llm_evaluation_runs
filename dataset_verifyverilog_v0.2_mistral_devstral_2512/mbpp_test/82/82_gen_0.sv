module sphere_volume (
  input clk,
  input rst_n,
  input start,
  input [31:0] radius,
  output reg [31:0] volume,
  output reg done
);

  // Constants
  localparam C = 32'h0006487E; // (4/3)*π in Q16.16 format

  // State machine
  typedef enum logic [2:0] {
    IDLE,
    CALC_SQ,
    CALC_CUBE,
    CALC_FINAL,
    DONE
  } state_t;

  state_t state, next_state;

  // Intermediate results
  reg [63:0] r_squared;
  reg [63:0] r_cubed;
  reg [63:0] final_product;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_SQ;
      end
      CALC_SQ: next_state = CALC_CUBE;
      CALC_CUBE: next_state = CALC_FINAL;
      CALC_FINAL: next_state = DONE;
      DONE: begin
        if (start) next_state = CALC_SQ;
        else next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_squared <= 64'h0;
      r_cubed <= 64'h0;
      final_product <= 64'h0;
      volume <= 32'h0;
      done <= 1'b0;
    end else begin
      case (state)
        CALC_SQ: r_squared <= $signed({1'b0, radius}) * $signed({1'b0, radius});
        CALC_CUBE: r_cubed <= r_squared * $signed({1'b0, radius});
        CALC_FINAL: final_product <= r_cubed * $signed({1'b0, C});
        DONE: begin
          volume <= final_product[47:16]; // Extract Q16.16 result
          done <= 1'b1;
        end
        default: ;
      endcase
    end
  end

  // Reset done signal when leaving DONE state
  always @(posedge clk) begin
    if (state == DONE && next_state != DONE) begin
      done <= 1'b0;
    end
  end

endmodule