module hill_houses (
  input clk,
  input rst_n,
  input start,
  input [6:0] hill_height,
  input valid,
  output reg [5:0] current_k,
  output reg [31:0] min_cost,
  output reg result_valid,
  output reg done
);

  // Parameters
  localparam N_MAX = 10;
  localparam K_MAX = 5;
  localparam Q_FORMAT = 16;
  localparam MULTIPLIER = 65536;

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    RECV_HILLS,
    COMPUTE,
    OUTPUT,
    DONE
  } state_t;

  // State machine
  state_t state, next_state;

  // Hill buffer
  reg [6:0] hill_buffer [0:N_MAX-1];
  reg [4:0] hill_count;

  // DP registers
  reg [31:0] dp0 [0:K_MAX];
  reg [31:0] dp1 [0:K_MAX];
  reg [31:0] dp2 [0:K_MAX];
  reg [31:0] dp0_next [0:K_MAX];
  reg [31:0] dp1_next [0:K_MAX];
  reg [31:0] dp2_next [0:K_MAX];

  // Current hill index
  reg [3:0] current_hill;

  // Output control
  reg [2:0] output_k;

  // Initialize
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      hill_count <= 0;
      current_hill <= 0;
      output_k <= 0;
      current_k <= 0;
      min_cost <= 0;
      result_valid <= 0;
      done <= 0;

      // Initialize DP arrays
      for (int i = 0; i <= K_MAX; i = i + 1) begin
        dp0[i] <= 0;
        dp1[i] <= 0;
        dp2[i] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = RECV_HILLS;
      end
      RECV_HILLS: begin
        if (hill_count == N_MAX - 1 && valid) next_state = COMPUTE;
      end
      COMPUTE: begin
        if (current_hill == N_MAX - 1) next_state = OUTPUT;
      end
      OUTPUT: begin
        if (output_k == K_MAX - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Hill reception
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hill_count <= 0;
    end else if (state == RECV_HILLS && valid) begin
      hill_buffer[hill_count] <= hill_height;
      hill_count <= hill_count + 1;
    end
  end

  // DP computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_hill <= 0;
    end else if (state == COMPUTE) begin
      // Initialize next DP values
      for (int k = 0; k <= K_MAX; k = k + 1) begin
        dp0_next[k] = dp0[k];
        dp1_next[k] = dp1[k];
        dp2_next[k] = dp2[k];
      end

      // Current hill height
      reg [6:0] h_i = hill_buffer[current_hill];
      reg [6:0] h_prev = (current_hill == 0) ? 0 : hill_buffer[current_hill - 1];
      reg [6:0] h_next = (current_hill == N_MAX - 1) ? 0 : hill_buffer[current_hill + 1];

      // Compute costs
      for (int k = 1; k <= K_MAX; k = k + 1) begin
        // Cost if we place a house at current hill
        reg [31:0] cost_house = 0;
        if (h_prev > h_i - 1) cost_house = cost_house + (h_prev - (h_i - 1)) * MULTIPLIER;
        if (h_next > h_i - 1) cost_house = cost_house + (h_next - (h_i - 1)) * MULTIPLIER;

        // Update DP states
        if (k == 1) begin
          dp1_next[k] = dp0[k-1] + cost_house;
        end else begin
          dp1_next[k] = (dp0[k-1] + cost_house) < (dp1[k-1] + cost_house) ? (dp0[k-1] + cost_house) : (dp1[k-1] + cost_house);
        end

        dp0_next[k] = dp0[k];
        dp2_next[k] = dp1[k-1];
      end

      // Update DP registers
      for (int k = 0; k <= K_MAX; k = k + 1) begin
        dp0[k] <= dp0_next[k];
        dp1[k] <= dp1_next[k];
        dp2[k] <= dp2_next[k];
      end

      current_hill <= current_hill + 1;
    end
  end

  // Output results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      output_k <= 0;
      current_k <= 0;
      min_cost <= 0;
      result_valid <= 0;
      done <= 0;
    end else if (state == OUTPUT) begin
      current_k <= output_k + 1;
      min_cost <= dp1[output_k + 1];
      result_valid <= 1;
      output_k <= output_k + 1;
    end else if (state == DONE) begin
      done <= 1;
      result_valid <= 0;
    end else begin
      result_valid <= 0;
      done <= 0;
    end
  end

endmodule