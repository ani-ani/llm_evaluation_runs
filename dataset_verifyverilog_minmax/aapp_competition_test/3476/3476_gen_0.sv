module matrix_optimizer(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start optimization
  input signed [15:0] matrix_in [0:3][0:3], // 4x4 matrix input
  output reg signed [31:0] best_sum, // Maximum sum achievable
  output reg [2:0] operation_count, // Number of operations (0-4)
  output reg [127:0] operation_sequence // Encoded operations (3-bit per op + 16-bit args)
);

  // Each operation entry: {2'b00 for rotR, 2'b01 for rotS, 2'b10 for negR, 2'b11 for negS},
  // row/col index, shift amount (2 bits)
  typedef struct packed {
    logic [1:0] op_code; // 2 bits
    logic [1:0] index;   // row/col index (0-3)
    logic [1:0] shift;   // shift amount (0-3)
  } op_t;

  // Internal state matrices (registered to support sequential evaluation over cycles)
  reg signed [15:0] cur_matrix [0:3][0:3];
  reg signed [15:0] next_matrix [0:3][0:3];

  // Stage 1: Apply one operation to cur_matrix and produce next_matrix
  // Evaluate all 4x4 matrices achievable by exactly 1 operation.
  // 24 possible operations:
  // - rotR: 4 rows x 4 shifts = 16
  // - rotS: 4 cols x 4 shifts = 16 (but rotS shift 0 duplicates identity, skip to avoid redundant)
  // - negR: 4 rows x 1 = 4
  // - negS: 4 cols x 1 = 4
  // Total 40 candidates, but we only keep the best (ties arbitrary).
  logic signed [31:0] best_sum_cand;
  op_t best_op;
  op_t ops [0:39];
  logic [5:0] op_count; // 0..40

  // Compute candidate matrices for every possible single operation
  function signed [15:0] rotate_right(input signed [15:0] a, input [1:0] sh);
    integer s;
    s = sh & 2'b11;
    case (s)
      2'b00: rotate_right = a;
      2'b01: rotate_right = {a[0], a[15:1]};
      2'b10: rotate_right = {a[1:0], a[15:2]};
      2'b11: rotate_right = {a[2:0], a[15:3]};
      default: rotate_right = a;
    endcase
  endfunction

  function signed [15:0] rotate_shift(input signed [15:0] a, input [1:0] sh);
    integer s;
    s = sh & 2'b11;
    case (s)
      2'b00: rotate_shift = a; // identical; still allowed for completeness
      2'b01: rotate_shift = {a[3:0], a[15:4]};
      2'b10: rotate_shift = {a[7:0], a[15:8]};
      2'b11: rotate_shift = {a[11:0], a[15:12]};
      default: rotate_shift = a;
    endcase
  endfunction

  // Apply a given operation to cur_matrix to produce out_matrix
  function void apply_op(op_t op, ref signed [15:0] out_matrix [0:3][0:3]);
    integer r, c;
    // Initialize with current matrix
    for (r = 0; r < 4; r = r + 1) begin
      for (c = 0; c < 4; c = c + 1) begin
        out_matrix[r][c] = cur_matrix[r][c];
      end
    end
    case (op.op_code)
      2'b00: begin // rotR
        for (r = 0; r < 4; r = r + 1) begin
          if (r == op.index) begin
            for (c = 0; c < 4; c = c + 1) begin
              out_matrix[r][c] = rotate_right(cur_matrix[r][c], op.shift);
            end
          end
        end
      end
      2'b01: begin // rotS
        for (c = 0; c < 4; c = c + 1) begin
          if (c == op.index) begin
            for (r = 0; r < 4; r = r + 1) begin
              out_matrix[r][c] = rotate_shift(cur_matrix[r][c], op.shift);
            end
          end
        end
      end
      2'b10: begin // negR
        for (c = 0; c < 4; c = c + 1) begin
          out_matrix[op.index][c] = -cur_matrix[op.index][c];
        end
      end
      2'b11: begin // negS
        for (r = 0; r < 4; r = r + 1) begin
          out_matrix[r][op.index] = -cur_matrix[r][op.index];
        end
      end
      default: ; // no-op
    endcase
  endfunction

  // Sum of matrix elements
  function signed [31:0] sum_matrix(input signed [15:0] m [0:3][0:3]);
    integer i, j;
    sum_matrix = 0;
    for (i = 0; i < 4; i = i + 1) begin
      for (j = 0; j < 4; j = j + 1) begin
        sum_matrix = sum_matrix + m[i][j];
      end
    end
  endfunction

  // Stage 1 logic (combinational but captured on next clock edge)
  always_comb begin
    // Seed candidates list with rotR (16)
    op_count = 0;
    for (int r = 0; r < 4; r = r + 1) begin
      for (int sh = 0; sh < 4; sh = sh + 1) begin
        ops[op_count] = '{op_code: 2'b00, index: r[1:0], shift: sh[1:0]};
        op_count++;
      end
    end
    // rotS (skip shift 0 to avoid duplicate identity, but code supports 0..3; we will include all for completeness)
    for (int c = 0; c < 4; c = c + 1) begin
      for (int sh = 0; sh < 4; sh = sh + 1) begin
        ops[op_count] = '{op_code: 2'b01, index: c[1:0], shift: sh[1:0]};
        op_count++;
      end
    end
    // negR (4)
    for (int r = 0; r < 4; r = r + 1) begin
      ops[op_count] = '{op_code: 2'b10, index: r[1:0], shift: 2'b00};
      op_count++;
    end
    // negS (4)
    for (int c = 0; c < 4; c = c + 1) begin
      ops[op_count] = '{op_code: 2'b11, index: c[1:0], shift: 2'b00};
      op_count++;
    end

    best_sum_cand = sum_matrix(cur_matrix);
    best_op = '{default: '0};

    // Evaluate all candidates
    for (int i = 0; i < op_count; i = i + 1) begin
      signed [15:0] cand [0:3][0:3];
      apply_op(ops[i], cand);
      if (sum_matrix(cand) > best_sum_cand) begin
        best_sum_cand = sum_matrix(cand);
        best_op = ops[i];
      end
    end
  end

  // Registered update of cur_matrix/next_matrix and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_matrix <= '{default: '0};
      next_matrix <= '{default: '0};
      best_sum <= '0;
      operation_count <= '0;
      operation_sequence <= '0;
    end else begin
      // Load input matrix when started
      if (start) begin
        cur_matrix <= matrix_in;
      end else begin
        cur_matrix <= next_matrix;
      end

      // Compute next_matrix (stage 1 combinational) registered here
      // We must apply best_op to cur_matrix to compute next_matrix for the next cycle.
      // If start=1, we are on cycle 0 (after start), stage 1 produces next_matrix for cycle 1.
      begin
        signed [15:0] temp [0:3][0:3];
        apply_op(best_op, temp);
        next_matrix <= temp;
      end

      // Stage 2 and Stage 3: Latch the best operation and apply twice over 3 cycles.
      // Pipeline:
      //  Cycle 0 (start=1): cur = matrix_in; stage1 computes best_op0; next = apply(best_op0, cur)
      //  Cycle 1:          cur = next (apply best_op0); stage1 computes best_op1; next = apply(best_op1, cur)
      //  Cycle 2:          cur = next (apply best_op1 o best_op0); stage1 computes best_op2; next = apply(best_op2, cur)
      //  Cycle 3 (output): result cur holds matrix after up to 3 operations (if beneficial).

      // Use shift register of best_op across 3 cycles (stage2) and then finalize (stage3)
      // To keep logic simple, we re-evaluate best_op every cycle based on current cur_matrix.
      // At cycle 2, we fix the final best sequence and produce outputs.

      // If we want exactly 3 total cycles after start, the outputs should be registered
      // on the 3rd rising edge after start. We'll use a 2-bit counter to track this.
    end
  end

  // Separate always block to handle the 3-cycle window after start (registered FSM)
  reg [1:0] stage_cnt; // 0,1,2; after 2 -> outputs valid on next cycle
  reg signed [31:0] stored_sum;
  op_t op_hist [0:2]; // up to 3 ops in sequence

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stage_cnt <= 2'b00;
      stored_sum <= '0;
      op_hist <= '{default: '{default: '0}};
      // Outputs are set elsewhere on reset
    end else begin
      if (start) begin
        stage_cnt <= 2'b00;
        stored_sum <= best_sum_cand; // sum after 0 or 1 op on the same cycle
        op_hist[0] <= best_op;       // first op if any
        op_hist[1] <= '{default: '0};
        op_hist[2] <= '{default: '0};
        // best_sum and outputs will be registered on the third cycle
      end else begin
        // Not started: keep state, but ensure outputs remain stable if not resetting.
        if (stage_cnt < 2'b10) begin
          stage_cnt <= stage_cnt + 1;
          if (stage_cnt == 2'b00) begin
            // After first non-start cycle: we have one op applied to next_matrix
            stored_sum <= sum_matrix(next_matrix);
            op_hist[1] <= best_op;
          end else if (stage_cnt == 2'b01) begin
            // After second non-start cycle: we have two ops applied
            // Compute sum again using cur_matrix (which now has two ops applied)
            stored_sum <= sum_matrix(cur_matrix);
            op_hist[2] <= best_op;
          end
        end
      end

      // On the third cycle after start (stage_cnt == 2), latch final outputs
      if (start) begin
        // We'll set outputs this cycle based on best_op0 and cur_matrix=matrix_in
        best_sum <= best_sum_cand; // could be unchanged or improved by one op
        // Determine operation_count and sequence for up to 1 op (cycle 0)
        if (best_op == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) begin
          // No-op; encode 0 ops
          operation_count <= 3'b000;
          operation_sequence <= 128'b0;
        end else begin
          operation_count <= 3'b001;
          // Pack 1 op (3-bit op + 2-bit index + 2-bit shift) -> 7 bits used, rest zeros
          operation_sequence <= {96'b0, best_op, 7'b0};
        end
      end else begin
        if (stage_cnt == 2'b00) begin
          // Cycle 1 after start: outputs reflect one op (already applied to next_matrix)
          best_sum <= stored_sum;
          if (op_hist[0] == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) begin
            operation_count <= 3'b000;
            operation_sequence <= 128'b0;
          end else begin
            operation_count <= 3'b001;
            operation_sequence <= {96'b0, op_hist[0], 7'b0};
          end
        end else if (stage_cnt == 2'b01) begin
          // Cycle 2 after start: outputs reflect up to two ops
          // Determine if second op is no-op
          if (op_hist[1] == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) begin
            // Only first op used
            operation_count <= (op_hist[0] == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) ? 3'b000 : 3'b001;
            if (op_hist[0] == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) begin
              operation_sequence <= 128'b0;
            end else begin
              operation_sequence <= {96'b0, op_hist[0], 7'b0};
            end
          end else begin
            // Two ops
            operation_count <= 3'b010;
            // Pack: op0 (bits 6:0), op1 (bits 13:7), rest zeros
            operation_sequence <= {
              121'b0,
              op_hist[1], 7'b0,
              op_hist[0], 7'b0
            };
          end
          best_sum <= stored_sum;
        end else if (stage_cnt == 2'b10) begin
          // Cycle 3 after start: outputs reflect up to three ops
          // Determine if third op is no-op
          if (op_hist[2] == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) begin
            if (op_hist[1] == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) begin
              operation_count <= (op_hist[0] == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) ? 3'b000 : 3'b001;
              if (op_hist[0] == '{op_code: 2'b00, index: 2'b00, shift: 2'b00}) begin
                operation_sequence <= 128'b0;
              end else begin
                operation_sequence <= {96'b0, op_hist[0], 7'b0};
              end
            end else begin
              operation_count <= 3'b010;
              operation_sequence <= {
                121'b0,
                op_hist[1], 7'b0,
                op_hist[0], 7'b0
              };
            end
          end else begin
            // Three ops
            operation_count <= 3'b011;
            // Pack: op0 (6:0), op1 (13:7), op2 (20:14)
            operation_sequence <= {
              107'b0,
              op_hist[2], 7'b0,
              op_hist[1], 7'b0,
              op_hist[0], 7'b0
            };
          end
          best_sum <= stored_sum; // sum after up to 3 ops
        end
      end
    end
  end

endmodule
