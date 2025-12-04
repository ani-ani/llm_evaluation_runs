module perfect_square_checker(
  input clk, // clock
  input rst_n, // active-low reset (async)
  input start, // pulse high to begin computation
  input reg [15:0] n, // input number to check (unsigned, 0-65535)
  output reg done, // high when computation complete
  output reg is_square // 1=perfect square, 0=not
);

  // Latch input on start pulse
  logic start_d, start_rise;
  logic [15:0] n_latched;
  logic start_latch;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
      start_latch <= 1'b0;
      n_latched <= '0;
    end else begin
      start_d <= start;
      start_latch <= start_rise ? 1'b1 : (done ? 1'b0 : start_latch);
      if (start_rise) n_latched <= n;
    end
  end

  assign start_rise = start && !start_d;

  // FSM and computation
  typedef enum logic {IDLE, BUSY} state_t;
  state_t state, next_state;
  logic [7:0] i;
  logic [7:0] i_next;
  logic [31:0] prod;
  logic comp_eq, comp_gt;

  always_comb begin
    comp_eq = (prod == n_latched);
    comp_gt = (prod > n_latched);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= '0;
      done <= 1'b0;
      is_square <= 1'b0;
    end else begin
      // Defaults
      i_next <= i;
      done <= 1'b0;
      is_square <= is_square;

      case (state)
        IDLE: begin
          i_next <= 8'h01;
          if (start_latch) begin
            state <= BUSY;
          end
        end

        BUSY: begin
          i_next <= i + 1;
          prod <= (i + 1) * (i + 1);

          if (comp_eq) begin
            done <= 1'b1;
            is_square <= 1'b1;
            state <= IDLE;
          end else if (comp_gt) begin
            done <= 1'b1;
            is_square <= 1'b0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase

      i <= i_next;
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    if (state == IDLE && start_latch) next_state = BUSY;
    if (state == BUSY && (comp_eq || comp_gt)) next_state = IDLE;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

endmodule
