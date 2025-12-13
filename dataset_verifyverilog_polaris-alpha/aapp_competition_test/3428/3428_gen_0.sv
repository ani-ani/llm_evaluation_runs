module gcd_distinct_count(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0][15:0] a,
  output reg [5:0] count,
  output reg done
);

  // FSM states
  typedef enum logic [1:0] {IDLE=2'b00, COMPUTE=2'b01, COUNT=2'b10} state_t;
  state_t state, next_state;

  // GCD table: 8x8, only lower triangular [i][j], i<=j used
  reg [11:0] gcd_table [7:0][7:0];
  reg        valid_table [7:0][7:0];

  // Indices for subsequence endpoints
  reg [2:0] i_idx, j_idx;

  // Iterative GCD engine registers
  reg [15:0] gcd_a, gcd_b;
  reg [15:0] gcd_curr;      // current gcd of subsequence (i..j)
  reg [15:0] gcd_prev;      // previous gcd(i..j-1)
  reg       gcd_busy;       // 1 when Euclid running
  reg       gcd_start;      // pulse to start Euclid
  reg       gcd_done;       // 1 when Euclid result valid

  // Distinct-counting structures
  reg [11:0] unique_vals [35:0]; // up to 36 distinct values
  reg [5:0]  unique_count;
  reg [5:0]  scan_idx;          // 0..35 for table index
  reg [5:0]  ins_idx;           // insertion index for new unique
  reg        scan_done;
  reg        check_in_progress;
  reg [11:0] current_gcd;

  // Performance / done timing
  reg [7:0] cycle_cnt;
  reg       compute_started;

  // Combinational: next_state
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE;
      end
      COMPUTE: begin
        // Transition to COUNT when all gcds computed
        if (!gcd_busy && (i_idx == n-1) && (j_idx == n-1))
          next_state = COUNT;
      end
      COUNT: begin
        if (scan_done)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Euclidean GCD iterative step (combinational for next values)
  wire [15:0] ea_next_a = (gcd_b != 16'd0) ? gcd_b : gcd_a;
  wire [15:0] ea_next_b = (gcd_b != 16'd0) ? (gcd_a % gcd_b) : 16'd0;

  // Main sequential logic
  integer x, y;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      done             <= 1'b0;
      count            <= 6'd0;
      i_idx            <= 3'd0;
      j_idx            <= 3'd0;
      gcd_a            <= 16'd0;
      gcd_b            <= 16'd0;
      gcd_curr         <= 16'd0;
      gcd_prev         <= 16'd0;
      gcd_busy         <= 1'b0;
      gcd_start        <= 1'b0;
      gcd_done         <= 1'b0;
      cycle_cnt        <= 8'd0;
      compute_started  <= 1'b0;
      unique_count     <= 6'd0;
      scan_idx         <= 6'd0;
      ins_idx          <= 6'd0;
      scan_done        <= 1'b0;
      check_in_progress<= 1'b0;
      current_gcd      <= 12'd0;
      // clear tables
      for (x = 0; x < 8; x = x + 1) begin
        for (y = 0; y < 8; y = y + 1) begin
          gcd_table[x][y]  <= 12'd0;
          valid_table[x][y]<= 1'b0;
        end
      end
      for (x = 0; x < 36; x = x + 1) begin
        unique_vals[x] <= 12'd0;
      end
    end else begin
      state <= next_state;

      // default strobes
      done      <= 1'b0;
      gcd_done  <= 1'b0;
      gcd_start <= 1'b0;

      // cycle counter for timing (from start of COMPUTE)
      if (state == IDLE && next_state == COMPUTE) begin
        cycle_cnt       <= 8'd0;
        compute_started <= 1'b1;
      end else if (compute_started) begin
        cycle_cnt <= cycle_cnt + 8'd1;
        if (cycle_cnt == 8'd255) begin
          done <= 1'b1; // assert at 256th cycle after computation start
          compute_started <= 1'b0;
        end
      end

      case (state)
        IDLE: begin
          // reset internal structures on entry to IDLE
          if (next_state == IDLE) begin
            i_idx   <= 3'd0;
            j_idx   <= 3'd0;
            gcd_busy<= 1'b0;
            scan_done <= 1'b0;
            check_in_progress <= 1'b0;
          end
          if (start) begin
            // clear gcd table and valids when starting new computation
            for (x = 0; x < 8; x = x + 1) begin
              for (y = 0; y < 8; y = y + 1) begin
                gcd_table[x][y]   <= 12'd0;
                valid_table[x][y] <= 1'b0;
              end
            end
            i_idx   <= 3'd0;
            j_idx   <= 3'd0;
            gcd_busy<= 1'b0;
          end
        end

        COMPUTE: begin
          // Manage GCD engine
          if (!gcd_busy) begin
            // Start a new subsequence GCD computation for (i_idx, j_idx)
            if (i_idx < n && j_idx < n) begin
              if (i_idx == j_idx) begin
                // base: gcd(i,i) = a[i]
                gcd_curr <= a[i_idx];
              end else begin
                // gcd(i,j) = gcd( gcd(i,j-1), a[j] )
                gcd_prev <= gcd_table[i_idx][j_idx-1];
                gcd_curr <= 16'd0; // will be updated when gcd_done
                // start Euclid between gcd_prev and a[j_idx]
                gcd_a    <= gcd_table[i_idx][j_idx-1];
                gcd_b    <= a[j_idx];
                gcd_busy <= 1'b1;
                gcd_start<= 1'b1;
              end

              // For single element subsequence, directly store and advance
              if (i_idx == j_idx) begin
                gcd_table[i_idx][j_idx]   <= a[i_idx][11:0];
                valid_table[i_idx][j_idx] <= 1'b1;

                // advance indices
                if (j_idx + 3'd1 < n) begin
                  j_idx <= j_idx + 3'd1;
                end else begin
                  i_idx <= i_idx + 3'd1;
                  j_idx <= i_idx + 3'd2; // next j = i+1
                  if (i_idx + 3'd1 >= n)
                    j_idx <= n - 1; // safety
                end
              end
            end
          end else begin
            // Euclidean iteration when busy
            if (gcd_b != 16'd0) begin
              gcd_a <= ea_next_a;
              gcd_b <= ea_next_b;
            end else begin
              // done, gcd_a holds the result
              gcd_done <= 1'b1;
              gcd_busy <= 1'b0;
              gcd_curr <= gcd_a;

              // store into table
              if (i_idx < 8 && j_idx < 8) begin
                gcd_table[i_idx][j_idx]   <= gcd_a[11:0];
                valid_table[i_idx][j_idx] <= 1'b1;
              end

              // advance (i,j)
              if (j_idx + 3'd1 < n) begin
                j_idx <= j_idx + 3'd1;
              end else begin
                i_idx <= i_idx + 3'd1;
                j_idx <= i_idx + 3'd2; // set to new i+1 next cycle
                if (i_idx + 3'd1 >= n)
                  j_idx <= n - 1; // safety cap
              end
            end
          end
        end

        COUNT: begin
          // Distinct-counting over all valid gcd_table entries
          if (!check_in_progress) begin
            // initialize on entry to COUNT
            unique_count      <= 6'd0;
            scan_idx          <= 6'd0;
            ins_idx           <= 6'd0;
            scan_done         <= 1'b0;
            check_in_progress <= 1'b1;
            for (x = 0; x < 36; x = x + 1) begin
              unique_vals[x] <= 12'd0;
            end
          end else if (!scan_done) begin
            // Map scan_idx (0..35) to (i,j) in lower triangular for n
            // Enumerate pairs in order: for i=0..n-1, j=i..n-1
            integer si;
            integer ti;
            integer idx_cnt;
            reg [2:0] mi;
            reg [2:0] mj;

            si = 0;
            ti = 0;
            idx_cnt = 0;
            mi = 3'd0;
            mj = 3'd0;

            // derive (mi,mj) from scan_idx
            for (si = 0; si < 8; si = si + 1) begin
              for (ti = si; ti < 8; ti = ti + 1) begin
                if (si < n && ti < n && idx_cnt == scan_idx) begin
                  mi = si[2:0];
                  mj = ti[2:0];
                end
                if (si < n && ti < n)
                  idx_cnt = idx_cnt + 1;
              end
            end

            if (scan_idx < idx_cnt) begin
              if (valid_table[mi][mj]) begin
                current_gcd = gcd_table[mi][mj];
                // check if current_gcd already in unique_vals
                integer k;
                reg found;
                found = 1'b0;
                for (k = 0; k < unique_count; k = k + 1) begin
                  if (unique_vals[k] == current_gcd)
                    found = 1'b1;
                end
                if (!found && unique_count < 36) begin
                  unique_vals[unique_count] <= current_gcd;
                  unique_count <= unique_count + 6'd1;
                end
              end
              scan_idx <= scan_idx + 6'd1;
            end else begin
              // completed scanning all valid entries
              scan_done <= 1'b1;
              count     <= unique_count;
              done      <= 1'b1; // signal completion (1 cycle)
              check_in_progress <= 1'b0;
            end
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule