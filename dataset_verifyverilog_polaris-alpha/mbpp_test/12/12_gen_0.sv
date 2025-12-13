module matrix_row_sort (
  input  wire              clk,
  input  wire              rst_n,
  input  wire              start,
  input  wire [8:0][7:0]   matrix_flat,
  output reg  [8:0][7:0]   sorted_matrix,
  output reg               done
);

  // FSM state encoding
  typedef enum logic [2:0] {
    S_IDLE  = 3'd0,
    S_L1    = 3'd1,
    S_L2    = 3'd2,
    S_L3    = 3'd3,
    S_SORT  = 3'd4,
    S_OUT   = 3'd5
  } state_t;

  state_t state, next_state;

  // Latched input matrix
  reg signed [7:0] m_reg [0:8];

  // Row sums (signed, enough width for sum of three 8-bit values)
  reg signed [9:0] sum0, sum1, sum2;

  // Row index order (permutation of 0,1,2)
  reg [1:0] idx0, idx1, idx2;

  integer i;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_L1;
      end
      S_L1:   next_state = S_L2;
      S_L2:   next_state = S_L3;
      S_L3:   next_state = S_SORT;
      S_SORT: next_state = S_OUT;
      S_OUT:  next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Clear outputs and internal registers
      sorted_matrix <= '{default:8'sd0};
      done          <= 1'b0;
      sum0          <= '0;
      sum1          <= '0;
      sum2          <= '0;
      idx0          <= 2'd0;
      idx1          <= 2'd1;
      idx2          <= 2'd2;
      for (i = 0; i < 9; i = i + 1) begin
        m_reg[i] <= 8'sd0;
      end
    end else begin
      done <= 1'b0; // default each cycle, asserted only in S_OUT

      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch input matrix (row-major: 0..2 row0, 3..5 row1, 6..8 row2)
            for (i = 0; i < 9; i = i + 1) begin
              m_reg[i] <= matrix_flat[i];
            end
          end
        end

        S_L1: begin
          // Compute row 0 sum
          sum0 <= $signed(m_reg[0]) + $signed(m_reg[1]) + $signed(m_reg[2]);
        end

        S_L2: begin
          // Compute row 1 sum
          sum1 <= $signed(m_reg[3]) + $signed(m_reg[4]) + $signed(m_reg[5]);
        end

        S_L3: begin
          // Compute row 2 sum
          sum2 <= $signed(m_reg[6]) + $signed(m_reg[7]) + $signed(m_reg[8]);
        end

        S_SORT: begin
          // Initialize indices
          idx0 <= 2'd0;
          idx1 <= 2'd1;
          idx2 <= 2'd2;

          // Compare and swap to sort sums ascending, track indices
          // First compare sum0 and sum1
          if (sum0 > sum1) begin
            {sum0, sum1} <= {sum1, sum0};
            {idx0, idx1} <= {idx1, idx0};
          end
          // Compare sum1 and sum2
          if (sum1 > sum2) begin
            {sum1, sum2} <= {sum2, sum1};
            {idx1, idx2} <= {idx2, idx1};
          end
          // Compare sum0 and sum1 again to finalize order
          if (sum0 > sum1) begin
            {sum0, sum1} <= {sum1, sum0};
            {idx0, idx1} <= {idx1, idx0};
          end
        end

        S_OUT: begin
          // Build sorted_matrix based on sorted row indices
          // Row 0 selection
          case (idx0)
            2'd0: begin
              sorted_matrix[0] <= m_reg[0];
              sorted_matrix[1] <= m_reg[1];
              sorted_matrix[2] <= m_reg[2];
            end
            2'd1: begin
              sorted_matrix[0] <= m_reg[3];
              sorted_matrix[1] <= m_reg[4];
              sorted_matrix[2] <= m_reg[5];
            end
            default: begin
              sorted_matrix[0] <= m_reg[6];
              sorted_matrix[1] <= m_reg[7];
              sorted_matrix[2] <= m_reg[8];
            end
          endcase

          // Row 1 selection
          case (idx1)
            2'd0: begin
              sorted_matrix[3] <= m_reg[0];
              sorted_matrix[4] <= m_reg[1];
              sorted_matrix[5] <= m_reg[2];
            end
            2'd1: begin
              sorted_matrix[3] <= m_reg[3];
              sorted_matrix[4] <= m_reg[4];
              sorted_matrix[5] <= m_reg[5];
            end
            default: begin
              sorted_matrix[3] <= m_reg[6];
              sorted_matrix[4] <= m_reg[7];
              sorted_matrix[5] <= m_reg[8];
            end
          endcase

          // Row 2 selection
          case (idx2)
            2'd0: begin
              sorted_matrix[6] <= m_reg[0];
              sorted_matrix[7] <= m_reg[1];
              sorted_matrix[8] <= m_reg[2];
            end
            2'd1: begin
              sorted_matrix[6] <= m_reg[3];
              sorted_matrix[7] <= m_reg[4];
              sorted_matrix[8] <= m_reg[5];
            end
            default: begin
              sorted_matrix[6] <= m_reg[6];
              sorted_matrix[7] <= m_reg[7];
              sorted_matrix[8] <= m_reg[8];
            end
          endcase

          done <= 1'b1; // Assert done when output is valid (5th cycle after start)
        end

        default: ;
      endcase
    end
  end

endmodule