module min_pair_distance (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input signed [15:0] a [0:7],
  output reg [31:0] min_dist,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALC_PREFIX,
    CALC_DIST,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal registers
  reg signed [31:0] prefix_reg [0:8];
  reg [2:0] i_reg, j_reg;
  reg [31:0] current_dist;
  reg [31:0] diff_i, diff_j;

  // Clamp n to max 8
  wire [3:0] n_clamped = (n > 8) ? 8 : n;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_dist <= 0;
      i_reg <= 0;
      j_reg <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_PREFIX;
      end
      CALC_PREFIX: begin
        if (i_reg == 8) next_state = CALC_DIST;
      end
      CALC_DIST: begin
        if (i_reg == n_clamped - 1 && j_reg == n_clamped) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Prefix sum calculation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int k = 0; k < 9; k++) prefix_reg[k] <= 0;
      i_reg <= 0;
    end else if (state == CALC_PREFIX) begin
      if (i_reg == 0) begin
        prefix_reg[0] <= 0;
        i_reg <= i_reg + 1;
      end else begin
        prefix_reg[i_reg] <= prefix_reg[i_reg - 1] + a[i_reg - 1];
        i_reg <= i_reg + 1;
      end
    end
  end

  // Distance calculation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      j_reg <= 0;
      min_dist <= 0;
    end else if (state == CALC_DIST) begin
      if (j_reg == 0) begin
        i_reg <= i_reg + 1;
        j_reg <= i_reg + 1;
      end else begin
        diff_i = i_reg - j_reg;
        diff_j = prefix_reg[i_reg + 1] - prefix_reg[j_reg + 1];
        current_dist = (diff_i * diff_i) + (diff_j * diff_j);
        if (min_dist == 0 || current_dist < min_dist) min_dist <= current_dist;
        if (j_reg == n_clamped - 1) begin
          j_reg <= 0;
        end else begin
          j_reg <= j_reg + 1;
        end
      end
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule