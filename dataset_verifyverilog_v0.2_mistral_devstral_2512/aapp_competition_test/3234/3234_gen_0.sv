module widget_packing (
  input clk,
  input rst_n,
  input start,
  input [15:0] N,
  output reg [15:0] min_empty,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCH,
    COMPARE,
    DONE
  } state_t;

  // State registers
  state_t state, next_state;
  reg [7:0] H, W;
  reg [15:0] area, empty;
  reg [15:0] best_W, best_H;
  reg [15:0] min_empty_reg;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      H <= 0;
      W <= 0;
      min_empty_reg <= 16'hFFFF;
      best_W <= 0;
      best_H <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      if (state == SEARCH) begin
        if (W == 2*H || W == 256) begin
          H <= H + 1;
          W <= (H + 1) / 2;
        end else begin
          W <= W + 1;
        end
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SEARCH;
      end
      SEARCH: begin
        if (H == 256 && W == 256) next_state = COMPARE;
      end
      COMPARE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(*) begin
    area = W * H;
    empty = (area >= N) ? (area - N) : 16'hFFFF;
  end

  // Update best solution
  always @(posedge clk) begin
    if (state == SEARCH && empty < min_empty_reg) begin
      min_empty_reg <= empty;
      best_W <= W;
      best_H <= H;
    end
  end

  // Output logic
  always @(*) begin
    case (state)
      IDLE: begin
        min_empty = 16'hFFFF;
        done = 0;
      end
      SEARCH: begin
        min_empty = 16'hFFFF;
        done = 0;
      end
      COMPARE: begin
        min_empty = min_empty_reg;
        done = 0;
      end
      DONE: begin
        min_empty = min_empty_reg;
        done = 1;
      end
    endcase
  end

endmodule