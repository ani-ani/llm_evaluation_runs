module superdoku_solver(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [31:0] grid_in,
  output reg valid_out,
  output reg [31:0] grid_out,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CHECK = 2'b01,
    GEN   = 2'b10,
    OUT   = 2'b11
  } state_t;

  state_t state, next_state;

  // Latched inputs at start
  reg [2:0] k_reg;
  reg [31:0] grid_reg;

  // Internal variables
  reg invalid;
  reg [31:0] gen_grid;
  reg [1:0] row_vals [0:3][0:3]; // [row][col]
  integer i, r, c;

  // Helper: extract gen_grid from row_vals
  function automatic [31:0] pack_grid;
    input [1:0] rv[0:3][0:3];
    integer rr, cc;
    reg [31:0] tmp;
  begin
    tmp = 32'b0;
    for (rr = 0; rr < 4; rr = rr + 1) begin
      for (cc = 0; cc < 4; cc = cc + 1) begin
        tmp[ (rr*8 + cc*2) +: 2 ] = rv[rr][cc];
      end
    end
    pack_grid = tmp;
  end
  endfunction

  // Unpack grid_reg into row_vals for pre-filled rows
  task automatic unpack_prefilled;
    integer rr, cc;
  begin
    for (rr = 0; rr < 4; rr = rr + 1) begin
      for (cc = 0; cc < 4; cc = cc + 1) begin
        if (rr < k_reg)
          row_vals[rr][cc] = grid_reg[(rr*8 + cc*2) +: 2];
        else
          row_vals[rr][cc] = 2'b00; // will be filled later
      end
    end
  end
  endtask

  // Duplicate check for values 1-4 (encoded 0-3) in one 4-element row
  function automatic logic row_valid;
    input [1:0] a0, a1, a2, a3;
  begin
    // All must be in 0-3 (implicitly true for 2 bits) and non-zero in Latin context not required by spec
    // Check pairwise distinctness
    row_valid = !( (a0==a1) || (a0==a2) || (a0==a3) ||
                   (a1==a2) || (a1==a3) ||
                   (a2==a3) );
  end
  endfunction

  // Column duplicate check across first k_reg rows
  function automatic logic cols_valid_k;
    input [1:0] v[0:3][0:3];
    input [2:0] kk;
    integer cc, r1, r2;
  begin
    cols_valid_k = 1'b1;
    for (cc = 0; cc < 4; cc = cc + 1) begin
      for (r1 = 0; r1 < 4; r1 = r1 + 1) begin
        if (r1 < kk) begin
          for (r2 = r1+1; r2 < 4; r2 = r2 + 1) begin
            if (r2 < kk) begin
              if (v[r1][cc] == v[r2][cc]) begin
                cols_valid_k = 1'b0;
              end
            end
          end
        end
      end
    end
  end
  endfunction

  // Check compatibility: pre-filled rows must themselves be Latin and consistent with cyclic pattern
  function automatic logic prefilled_compatible;
    input [1:0] v[0:3][0:3];
    input [2:0] kk;
    integer rr, cc;
  begin
    // 1) Each prefilled row must have 4 distinct values
    for (rr = 0; rr < kk; rr = rr + 1) begin
      if (!row_valid(v[rr][0], v[rr][1], v[rr][2], v[rr][3])) begin
        prefilled_compatible = 1'b0;
        return;
      end
    end

    // 2) Columns among prefilled rows must have no duplicates
    if (!cols_valid_k(v, kk)) begin
      prefilled_compatible = 1'b0;
      return;
    end

    // 3) Cyclic rotation consistency between consecutive prefilled rows
    for (rr = 0; rr + 1 < kk; rr = rr + 1) begin
      for (cc = 0; cc < 4; cc = cc + 1) begin
        if (v[rr+1][cc] !== v[rr][(cc+1)%4]) begin
          prefilled_compatible = 1'b0;
          return;
        end
      end
    end

    prefilled_compatible = 1'b1;
  end
  endfunction

  // Sequential state/regs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      k_reg     <= 3'd0;
      grid_reg  <= 32'd0;
      valid_out <= 1'b0;
      grid_out  <= 32'd0;
      done      <= 1'b0;
      invalid   <= 1'b0;
      gen_grid  <= 32'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          valid_out <= 1'b0;
          if (start) begin
            k_reg    <= (k > 3'd4) ? 3'd4 : k;
            grid_reg <= grid_in;
          end
        end

        CHECK: begin
          // Perform checks combinationally into invalid, gen_grid in next block
          // Registers updated below via blocking to align with state advance
          if (invalid) begin
            valid_out <= 1'b0;
            grid_out  <= grid_reg; // don't care; keep input
          end else begin
            valid_out <= 1'b1;
            grid_out  <= gen_grid;
          end
        end

        GEN: begin
          // GEN used only as transitional; outputs already prepared
        end

        OUT: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next state and core combinational logic
  always @(*) begin
    next_state = state;

    // Defaults (overwritten in CHECK)
    invalid  = 1'b0;
    gen_grid = grid_out;

    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK;
      end

      CHECK: begin
        // Unpack and verify, then build full cyclic Latin square if possible
        reg [1:0] tmp_vals [0:3][0:3];
        unpack_prefilled();
        // copy unpacked into local tmp_vals for function use
        for (r = 0; r < 4; r = r + 1)
          for (c = 0; c < 4; c = c + 1)
            tmp_vals[r][c] = row_vals[r][c];

        if (!prefilled_compatible(tmp_vals, k_reg)) begin
          invalid = 1'b1;
        end else begin
          // Build full 4x4 by cyclic rotations starting from row0
          // Use first row as base; it is guaranteed valid Latin candidate by checks
          // Row0: already given or zeros if k_reg==0 (zeros form trivial pattern)
          // Compute remaining rows via rotation of previous row
          // Start from tmp_vals
          // Ensure row0 is set: if k_reg==0, let user-provided grid_in row0 be starting row
          if (k_reg == 0) begin
            for (c = 0; c < 4; c = c + 1)
              tmp_vals[0][c] = grid_reg[(0*8 + c*2) +: 2];
            // Optionally ensure distinctness of row0
            if (!row_valid(tmp_vals[0][0], tmp_vals[0][1], tmp_vals[0][2], tmp_vals[0][3]))
              invalid = 1'b1;
          end

          if (!invalid) begin
            // Generate rows 1..3 by cyclic left rotation
            for (r = 1; r < 4; r = r + 1) begin
              for (c = 0; c < 4; c = c + 1) begin
                tmp_vals[r][c] = tmp_vals[r-1][(c+1)%4];
              end
            end

            // For k_reg>0, we already enforced consistency; now pack
            gen_grid = pack_grid(tmp_vals);
          end
        end

        next_state = GEN;
      end

      GEN: begin
        // Move to OUT regardless; outputs already prepared in CHECK
        next_state = OUT;
      end

      OUT: begin
        // Stay done for one cycle then go back to IDLE
        next_state = IDLE;
      end
    endcase
  end

endmodule