module hill_houses (
  input clk,
  input rst_n,
  input start,
  input [15:0] hills [0:7],
  output reg [31:0] results [0:3],
  output reg done
);

  //--- State machine ---
  typedef enum logic [1:0] {IDLE = 2'b00, COMPUTE = 2'b01, DONE = 2'b10} state_t;
  state_t state, next_state;

  //--- DP storage ---
  reg [31:0] dpPrev [0:4]; // dpPrev[0..4] for k = 0..4
  reg [31:0] dpCurr [0:4]; // temporary column
  reg [3:0] i; // index of the next hill to process (0..8)

  //--- Compute number of non‑zero hills (nNZ) and maxK = ceil(nNZ/2) ---
  wire [15:0] hills_nz [0:7];
  wire [3:0] nz_count;
  wire [3:0] maxK = (nz_count + 1) >> 1;

  // always_comb block to filter out zero hills
  always_comb begin
    // initialise to zero
    for (int j = 0; j < 8; j++) hills_nz[j] = 16'h0;
    nz_count = 4'h0;
    for (int j = 0; j < 8; j++) begin
      if (hills[j] != 0) begin
        hills_nz[nz_count] = hills[j];
        nz_count = nz_count + 1;
      end
    end
  end

  //--- Sequential state and datapath update ---
  localparam INF = 32'h7fffffff; // Large enough to act as "infinity"
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 1'b0;
      results <= '{default:32'h0};
      i       <= 4'b0;
      dpPrev[0] <= 32'h0;
      dpPrev[1] <= INF;
      dpPrev[2] <= INF;
      dpPrev[3] <= INF;
      dpPrev[4] <= INF;
    end else begin
      // State transition
      state <= next_state;

      case (state)
        IDLE: begin
          // Prepare for a new run
          done    <= 1'b0;
          results <= '{default:32'h0};
          i       <= 4'b0;
          dpPrev[0] <= 32'h0;
          dpPrev[1] <= INF;
          dpPrev[2] <= INF;
          dpPrev[3] <= INF;
          dpPrev[4] <= INF;
        end

        COMPUTE: begin
          // Update the DP for the current hill (index i)
          dpCurr[0] <= 32'h0; // dp[0][*] = 0
          for (int k = 1; k <= 4; k++) begin
            if (i < nz_count) begin
              // dpCurr[k] = min(dpPrev[k], dpPrev[k-1] + hills_nz[i])
              dpCurr[k] <= (dpPrev[k] < (dpPrev[k-1] + hills_nz[i]))
                            ? dpPrev[k] : (dpPrev[k-1] + hills_nz[i]);
            end else begin
              // No more hills, keep the previous value
              dpCurr[k] <= dpPrev[k];
            end
          end

          // Move to the next hill
          i        <= i + 1'b1;
          // Store the new column for the next iteration
          dpPrev   <= dpCurr;
        end

        DONE: begin
          // One‑cycle pulse and capture results
          done <= 1'b1;
          for (int k = 1; k <= 3; k++) begin
            if (k <= maxK) results[k-1] <= dpPrev[k];
            else            results[k-1] <= 32'h0;
          end
        end

        default: begin
          // Stay in IDLE on illegal state
        end
      endcase
    end
  end

  //--- Next‑state logic (combinational) ---
  always_comb begin
    next_state = state;
    case (state)
      IDLE:    if (start) next_state = COMPUTE;
      COMPUTE: if (nz_count == 0 || i == nz_count) next_state = DONE;
      DONE:    next_state = IDLE; // only one cycle in DONE
      default: next_state = IDLE;
    endcase
  end

endmodule