module sign_distance_average(
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [15:0] dist_matrix [5:0],
    output reg [31:0] avg_distance,
    output reg done,
    output reg impossible
);

  // State machine
  typedef enum logic [1:0] { IDLE = 2'b00, COMPUTE = 2'b01, DONE = 2'b10 } state_t;
  state_t state;
  state_t next_state;

  // Iteration control
  reg [3:0] i, j;       // indices in [0..5]
  reg [3:0] cycle_cnt;  // total cycle counter (limit 20)
  reg [4:0] iter_cnt;   // sub-cycle within compute (limit 9)

  // Sum of selected distances
  reg [31:0] sum;       // unsigned sum (max: 6 * 65535 = 393210 < 2^19)

  // Compute pipelines
  wire [15:0] dcur = dist_matrix[i];
  wire [15:0] dji  = dist_matrix[j];
  wire [15:0] dij  = dist_matrix[i];
  wire [15:0] sum1 = sum + dcur;
  wire [15:0] sum2 = sum1 + dji;
  wire [15:0] sum3 = sum2 + dij;

  // Control flags
  reg go;        // when high, compute active
  reg en;        // enable sub-accumulate within this cycle
  wire [1:0] terms = (j > i) ? 2'd2 : (j == i ? 2'd1 : 2'd0);

  // Average calculation (Q16.16)
  // P = n * (n - 1) / 2, avg = (sum << 16) / P (unsigned, fractional)
  wire [31:0] avg_next = (sum << 16) / P;
  wire [4:0] P = n * (n - 1) / 2; // 0,1,3,6 for n=0,1,2,3,4 (we require n>=2 for non-zero avg)

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:   if (go) next_state = COMPUTE;
      COMPUTE: if (cycle_cnt == 4'd20) next_state = DONE;
      DONE:   if (!go) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Combinational enables for this cycle
  assign go = start;
  assign en = (state == COMPUTE);

  // Iterative indices and sub-cycle counter
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i       <= 4'd0;
      j       <= 4'd0;
      cycle_cnt <= 4'd0;
      iter_cnt  <= 5'd0;
      sum     <= 32'd0;
    end else begin
      case (state)
        IDLE: begin
          i        <= 4'd0;
          j        <= 4'd0;
          cycle_cnt <= 4'd0;
          iter_cnt  <= 5'd0;
          sum     <= 32'd0;
        end
        COMPUTE: begin
          cycle_cnt <= cycle_cnt + 4'd1;
          iter_cnt  <= iter_cnt + 5'd1;
          // Sub-cycle for triple accumulate (di, dj, dji)
          case (iter_cnt[1:0])
            2'b00: if (en) sum <= sum + dcur; // i
            2'b01: if (en) sum <= sum + dji;  // j
            2'b10: if (en) sum <= sum + dij;  // i
            2'b11: begin // finalize step for this i, wrap j
                      if (en) begin
                        if (j == 4'd5) begin
                          j <= 4'd0;
                          i <= (i == 4'd5) ? 4'd0 : (i + 4'd1);
                        end else begin
                          j <= j + 4'd1;
                        end
                      end
                    end
          endcase
        end
        DONE: begin
          // hold until go deasserted
        end
        default: begin
          // no change
        end
      endcase
    end
  end

  // Accumulate only when i,j within range [0:n-1]
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      sum <= 32'd0;
    end else if (state == IDLE) begin
      sum <= 32'd0;
    end else if (en) begin
      // Only add when both i and j are valid for the given n
      if (i < n && j < n) begin
        case (iter_cnt[1:0])
          2'b00: sum <= sum + dcur;   // add dist[i]
          2'b01: sum <= sum + dji;    // add dist[j]
          2'b10: sum <= sum + dij;    // add dist[i] again
          2'b11: sum <= sum;          // NOP, indices wrap handled in same case
        endcase
      end
    end
  end

  // Output registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done        <= 1'b0;
      impossible  <= 1'b0;
      avg_distance <= 32'd0;
    end else begin
      case (state)
        IDLE: begin
          done        <= 1'b0;
          impossible  <= 1'b0;
          avg_distance <= 32'd0;
        end
        COMPUTE: begin
          done        <= 1'b0;
          impossible  <= 1'b0;
          avg_distance <= 32'd0;
        end
        DONE: begin
          done        <= 1'b1;
          impossible  <= 1'b0;
          avg_distance <= avg_next; // Q16.16
        end
        default: begin
          done        <= done;
          impossible  <= impossible;
          avg_distance <= avg_distance;
        end
      endcase
    end
  end

endmodule