module matrix_optimizer(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start optimization
  input signed [15:0] matrix_in [0:3][0:3], // 4x4 matrix input
  output reg signed [31:0] best_sum, // Maximum sum achievable
  output reg [2:0] operation_count, // Number of operations (0-5)
  output reg [127:0] operation_sequence // Encoded operations (3-bit per op + 16-bit args)
);

  // FSM states for 3-cycle latency pipeline
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CYCLE1 = 2'b01,
    CYCLE2 = 2'b10,
    CYCLE3 = 2'b11
  } state_t;

  state_t state, next_state;

  // Registers to latch matrix and intermediate values
  reg signed [15:0] mat_reg [0:3][0:3];
  reg signed [31:0] base_sum;
  reg signed [31:0] best_improvement;
  reg [31:0] best_op_enc; // single op encoding (upper bits used when mapping into sequence)

  // Combinational wires for improvements (single-operation search)
  integer i, j, s;

  // Operation encoding:
  // {2'b00 rotR, 2'b01 rotS, 2'b10 negR, 2'b11 negS}, row/col index (2 bits), shift amount (4 bits)
  // Stored into 32-bit slot per op for simplicity within 128-bit sequence

  // Sequential state and registers update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      best_sum <= '0;
      operation_count <= '0;
      operation_sequence <= '0;
      base_sum <= '0;
      best_improvement <= '0;
      best_op_enc <= '0;
      for (i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          mat_reg[i][j] <= '0;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            // Latch matrix and compute base sum in this cycle
            base_sum <= '0;
            for (i = 0; i < 4; i = i + 1) begin
              for (j = 0; j < 4; j = j + 1) begin
                mat_reg[i][j] <= matrix_in[i][j];
                base_sum <= base_sum + matrix_in[i][j];
              end
            end
            best_improvement <= 32'sd0;
            best_op_enc <= 32'd0;
          end
        end

        CYCLE1: begin
          // Evaluate all single operations combinationally and capture best
          // Note: Implementation below in separate always_comb block; here we just latch results
          // best_improvement_next and best_op_enc_next are driven combinationally
          best_improvement <= best_improvement_next;
          best_op_enc <= best_op_enc_next;
        end

        CYCLE2: begin
          // Build outputs based on best improvement and op
          if (best_improvement > 0) begin
            best_sum <= base_sum + best_improvement;
            operation_count <= 3'd1;
            // Place best operation in lowest 32 bits of operation_sequence
            operation_sequence <= {96'd0, best_op_enc};
          end else begin
            best_sum <= base_sum;
            operation_count <= 3'd0;
            operation_sequence <= 128'd0;
          end
        end

        CYCLE3: begin
          // Hold results stable; no changes
          best_sum <= best_sum;
          operation_count <= operation_count;
          operation_sequence <= operation_sequence;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CYCLE1;
        else
          next_state = IDLE;
      end
      CYCLE1: begin
        next_state = CYCLE2;
      end
      CYCLE2: begin
        next_state = CYCLE3;
      end
      CYCLE3: begin
        // After 3-cycle latency, go back to IDLE, awaiting next start
        if (start)
          next_state = CYCLE1; // allow back-to-back starts
        else
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Combinational search for best single operation improvement
  // We evaluate candidate operations on latched mat_reg and base_sum

  reg signed [31:0] best_improvement_next;
  reg [31:0] best_op_enc_next;

  // Helper function: safe shift amount limit (0..15)
  function automatic [3:0] clip_shift(input integer val);
    begin
      if (val < 0)
        clip_shift = 4'd0;
      else if (val > 15)
        clip_shift = 4'd15;
      else
        clip_shift = val[3:0];
    end
  endfunction

  // For simplicity and determinism, we define the operation space as:
  // - rotR: for each row (0..3), shift amounts 0..3
  // - rotS: for each column (0..3), shift amounts 0..3
  // - negR: for each row (0..3), no shift (shift=0)
  // - negS: for each column (0..3), no shift (shift=0)
  // This keeps search finite and consistent with encoding.

  always @(*) begin
    best_improvement_next = 32'sd0;
    best_op_enc_next = 32'd0;

    // Local variables
    integer r, c, k;
    reg signed [31:0] sum_new;
    reg signed [15:0] temp_row [0:3];
    reg signed [15:0] temp_col [0:3];

    // 1) rotR: rotate row right by s (1..3) [s=0 is no-op]
    for (r = 0; r < 4; r = r + 1) begin
      for (k = 1; k <= 3; k = k + 1) begin
        // compute rotated row r by k
        // copy row
        temp_row[0] = mat_reg[r][0];
        temp_row[1] = mat_reg[r][1];
        temp_row[2] = mat_reg[r][2];
        temp_row[3] = mat_reg[r][3];
        // perform rotation right by k
        // index mapping: new[j] = old[(j - k) mod 4]
        sum_new = base_sum
                  - mat_reg[r][0] - mat_reg[r][1] - mat_reg[r][2] - mat_reg[r][3]
                  + temp_row[(0 - k) & 3]
                  + temp_row[(1 - k) & 3]
                  + temp_row[(2 - k) & 3]
                  + temp_row[(3 - k) & 3];
        if (sum_new - base_sum > best_improvement_next) begin
          best_improvement_next = sum_new - base_sum;
          best_op_enc_next = {2'b00, r[1:0], clip_shift(k), 24'd0};
        end
      end
    end

    // 2) rotS: rotate column down by s (1..3)
    for (c = 0; c < 4; c = c + 1) begin
      for (k = 1; k <= 3; k = k + 1) begin
        // copy column
        temp_col[0] = mat_reg[0][c];
        temp_col[1] = mat_reg[1][c];
        temp_col[2] = mat_reg[2][c];
        temp_col[3] = mat_reg[3][c];
        // compute sum with rotated column
        sum_new = base_sum
                  - mat_reg[0][c] - mat_reg[1][c] - mat_reg[2][c] - mat_reg[3][c]
                  + temp_col[(0 - k) & 3]
                  + temp_col[(1 - k) & 3]
                  + temp_col[(2 - k) & 3]
                  + temp_col[(3 - k) & 3];
        if (sum_new - base_sum > best_improvement_next) begin
          best_improvement_next = sum_new - base_sum;
          best_op_enc_next = {2'b01, c[1:0], clip_shift(k), 24'd0};
        end
      end
    end

    // 3) negR: negate all elements in a row
    for (r = 0; r < 4; r = r + 1) begin
      sum_new = base_sum
                - mat_reg[r][0] - mat_reg[r][1] - mat_reg[r][2] - mat_reg[r][3]
                + (-mat_reg[r][0]) + (-mat_reg[r][1]) + (-mat_reg[r][2]) + (-mat_reg[r][3]);
      if (sum_new - base_sum > best_improvement_next) begin
        best_improvement_next = sum_new - base_sum;
        best_op_enc_next = {2'b10, r[1:0], 4'd0, 24'd0};
      end
    end

    // 4) negS: negate all elements in a column
    for (c = 0; c < 4; c = c + 1) begin
      sum_new = base_sum
                - mat_reg[0][c] - mat_reg[1][c] - mat_reg[2][c] - mat_reg[3][c]
                + (-mat_reg[0][c]) + (-mat_reg[1][c]) + (-mat_reg[2][c]) + (-mat_reg[3][c]);
      if (sum_new - base_sum > best_improvement_next) begin
        best_improvement_next = sum_new - base_sum;
        best_op_enc_next = {2'b11, c[1:0], 4'd0, 24'd0};
      end
    end
  end

endmodule