module min_energy_calculator(
  input clk,               // clock
  input rst_n,             // active-low reset
  input start,             // start computation
  input [2:0] n,           // neutron threshold (1-8) (not used explicitly in this implementation)
  input [15:0] a0, a1, a2, a3, a4, a5, a6, a7, // energy values for k=1-8
  input [3:0] k_query,     // query neutron count (1-16)
  output reg [31:0] min_energy, // result
  output reg ready,        // precomputation complete
  output reg valid         // output valid
);

  // Internal storage for dp[1..16]; index 0 unused
  reg [31:0] dp [0:16];

  // FSM state encoding
  typedef enum logic [1:0] {
    S_IDLE   = 2'b00,
    S_PRE    = 2'b01,
    S_READY  = 2'b10
  } state_t;

  state_t state, next_state;

  // Precomputation control
  reg [3:0] cur_i;  // current i for which we are computing dp[i]
  reg [3:0] j;      // split index
  reg [31:0] cur_min;

  // Query pipeline
  reg [3:0] q_reg1;
  reg [3:0] q_reg2;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      ready      <= 1'b0;
      valid      <= 1'b0;
      min_energy <= 32'd0;
      cur_i      <= 4'd0;
      j          <= 4'd0;
      cur_min    <= 32'hFFFFFFFF;
      q_reg1     <= 4'd0;
      q_reg2     <= 4'd0;

      // Clear dp
      dp[0]  <= 32'd0;
      dp[1]  <= 32'd0;
      dp[2]  <= 32'd0;
      dp[3]  <= 32'd0;
      dp[4]  <= 32'd0;
      dp[5]  <= 32'd0;
      dp[6]  <= 32'd0;
      dp[7]  <= 32'd0;
      dp[8]  <= 32'd0;
      dp[9]  <= 32'd0;
      dp[10] <= 32'd0;
      dp[11] <= 32'd0;
      dp[12] <= 32'd0;
      dp[13] <= 32'd0;
      dp[14] <= 32'd0;
      dp[15] <= 32'd0;
      dp[16] <= 32'd0;
    end else begin
      state <= next_state;

      // Default hold
      valid <= 1'b0;

      case (state)
        S_IDLE: begin
          ready <= 1'b0;
          if (start) begin
            // Load base energies (k=1..8)
            dp[1]  <= {16'd0, a0};
            dp[2]  <= {16'd0, a1};
            dp[3]  <= {16'd0, a2};
            dp[4]  <= {16'd0, a3};
            dp[5]  <= {16'd0, a4};
            dp[6]  <= {16'd0, a5};
            dp[7]  <= {16'd0, a6};
            dp[8]  <= {16'd0, a7};

            // Initialize precomputation for dp[9]
            cur_i   <= 4'd9;
            j       <= 4'd1;
            cur_min <= 32'hFFFFFFFF;
          end
        end

        S_PRE: begin
          // Perform one split evaluation per cycle for current i
          if (j < cur_i) begin
            // Compute candidate = dp[j] + dp[cur_i - j]
            // Use blocking-style temporaries via intermediate regs
            // (done combinationally inside sequential block)
            reg [31:0] sum_val;
            sum_val = dp[j] + dp[cur_i - j];
            if (sum_val < cur_min)
              cur_min <= sum_val;
            j <= j + 4'd1;
          end else begin
            // All splits checked for cur_i; store result
            dp[cur_i] <= cur_min;

            if (cur_i == 4'd16) begin
              // Finished dp[9..16]
              ready <= 1'b1;
            end

            // Prepare for next i (or hold if done)
            if (cur_i < 4'd16) begin
              cur_i   <= cur_i + 4'd1;
              j       <= 4'd1;
              cur_min <= 32'hFFFFFFFF;
            end
          end
        end

        S_READY: begin
          // Ready for queries
          ready <= 1'b1;

          // Query pipeline: 2-cycle latency from k_query to valid output
          q_reg1 <= k_query;
          q_reg2 <= q_reg1;

          // On second stage, output selected dp and assert valid
          if (q_reg2 >= 4'd1 && q_reg2 <= 4'd16) begin
            min_energy <= dp[q_reg2];
            valid      <= 1'b1;
          end else begin
            min_energy <= 32'd0;
            valid      <= 1'b0;
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_PRE;
      end
      S_PRE: begin
        if (cur_i == 4'd16 && j == cur_i)
          next_state = S_READY;
      end
      S_READY: begin
        // Stay READY; new start would require external reset per spec
        next_state = S_READY;
      end
      default: next_state = S_IDLE;
    endcase
  end

endmodule
