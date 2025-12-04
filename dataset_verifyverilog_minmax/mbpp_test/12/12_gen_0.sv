module matrix_row_sort (
  input clk,
  input rst_n,
  input start,
  input [8:0][7:0] matrix_flat,
  output reg [8:0][7:0] sorted_matrix,
  output reg done
);

  // State machine
  typedef enum logic [1:0] { IDLE = 2'b00, SAMPLE = 2'b01, COMP_SUM = 2'b10, DONE = 2'b11 } state_t;
  state_t cur_state, nxt_state;

  // Stored matrix and row sums
  reg [8:0][7:0] mat_r;
  reg [5:0] sum_r [0:2];
  logic [5:0] sum_comb [0:2];

  // Compute row sums (signed 6-bit for -384..+384 range)
  assign sum_comb[0] = $signed({1'b0, mat_r[0]}) + $signed({1'b0, mat_r[1]}) + $signed({1'b0, mat_r[2]});
  assign sum_comb[1] = $signed({1'b0, mat_r[3]}) + $signed({1'b0, mat_r[4]}) + $signed({1'b0, mat_r[5]});
  assign sum_comb[2] = $signed({1'b0, mat_r[6]}) + $signed({1'b0, mat_r[7]}) + $signed({1'b0, mat_r[8]});

  // Sequential state and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_state <= IDLE;
      mat_r <= '0;
      sum_r[0] <= '0;
      sum_r[1] <= '0;
      sum_r[2] <= '0;
    end else begin
      cur_state <= nxt_state;
      case (nxt_state)
        SAMPLE: begin
          mat_r <= matrix_flat;         // latch input matrix
          sum_r[0] <= sum_comb[0];      // capture computed sums
          sum_r[1] <= sum_comb[1];
          sum_r[2] <= sum_comb[2];
        end
        default: begin
          // Keep sums/rows stable during other states
          mat_r <= mat_r;
          sum_r[0] <= sum_r[0];
          sum_r[1] <= sum_r[1];
          sum_r[2] <= sum_r[2];
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    nxt_state = cur_state;
    case (cur_state)
      IDLE:    nxt_state = start ? SAMPLE : IDLE;
      SAMPLE:  nxt_state = COMP_SUM;        // 2 cycles after start
      COMP_SUM nxt_state = DONE;            // 4 cycles after start
      DONE:    nxt_state = IDLE;            // 5 cycles after start
      default: nxt_state = IDLE;
    endcase
  end

  // Sorting via three compare-and-swaps (odd-even transposition for 3 rows)
  always_ff @(posedge clk) begin
    case (cur_state)
      IDLE: begin
        sorted_matrix <= '0;
        done <= 1'b0;
      end
      SAMPLE: begin
        // Initialize with latched matrix
        sorted_matrix <= mat_r;
        done <= 1'b0;
      end
      COMP_SUM: begin
        // Pass 1: compare/swap rows 0 and 1
        if (sum_r[0] > sum_r[1]) begin
          sorted_matrix[0] <= mat_r[3];
          sorted_matrix[1] <= mat_r[4];
          sorted_matrix[2] <= mat_r[5];
          sorted_matrix[3] <= mat_r[0];
          sorted_matrix[4] <= mat_r[1];
          sorted_matrix[5] <= mat_r[2];
        end else begin
          sorted_matrix[0] <= mat_r[0];
          sorted_matrix[1] <= mat_r[1];
          sorted_matrix[2] <= mat_r[2];
          sorted_matrix[3] <= mat_r[3];
          sorted_matrix[4] <= mat_r[4];
          sorted_matrix[5] <= mat_r[5];
        end
        // Pass 2: compare/swap rows 1 and 2
        if (sum_r[1] > sum_r[2]) begin
          sorted_matrix[6] <= mat_r[6];
          sorted_matrix[7] <= mat_r[7];
          sorted_matrix[8] <= mat_r[8];
        end else begin
          sorted_matrix[6] <= mat_r[3];
          sorted_matrix[7] <= mat_r[4];
          sorted_matrix[8] <= mat_r[5];
        end
        done <= 1'b0;
      end
      DONE: begin
        // Final pass: re-check rows 0 and 1 with the current rows
        if (sum_r[0] > sum_r[1]) begin
          sorted_matrix[0] <= mat_r[3];
          sorted_matrix[1] <= mat_r[4];
          sorted_matrix[2] <= mat_r[5];
          sorted_matrix[3] <= mat_r[0];
          sorted_matrix[4] <= mat_r[1];
          sorted_matrix[5] <= mat_r[2];
        end else begin
          sorted_matrix[0] <= mat_r[0];
          sorted_matrix[1] <= mat_r[1];
          sorted_matrix[2] <= mat_r[2];
          sorted_matrix[3] <= mat_r[3];
          sorted_matrix[4] <= mat_r[4];
          sorted_matrix[5] <= mat_r[5];
        end
        // Rows 2 already set in COMP_SUM
        done <= 1'b1;  // Result valid 5 cycles after start
      end
      default: begin
        sorted_matrix <= '0;
        done <= 1'b0;
      end
    endcase
  end

endmodule