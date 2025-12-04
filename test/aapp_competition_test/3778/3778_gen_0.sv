module boomerang_target_config(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  input  [1:0] a_0,
  input  [1:0] a_1,
  input  [1:0] a_2,
  input  [1:0] a_3,
  input  [1:0] a_4,
  input  [1:0] a_5,
  input  [1:0] a_6,
  input  [1:0] a_7,
  output reg        valid,
  output reg        failed,
  output reg [2:0]  t_row,
  output reg [2:0]  t_col,
  output reg        t_valid,
  output reg        done
);

  // States
  localparam S_IDLE   = 3'd0;
  localparam S_INIT   = 3'd1;
  localparam S_CHECK  = 3'd2;
  localparam S_SOLVE  = 3'd3;
  localparam S_OUT    = 3'd4;
  localparam S_DONE   = 3'd5;
  localparam S_FAIL   = 3'd6;

  reg [2:0] state, next_state;

  // Column requirements
  reg [1:0] col_req [0:7];

  // Row target count (max 2 per row), rows indexed 0..7 -> output as +1
  reg [1:0] row_cnt [0:7];

  // Store up to 16 targets
  reg [2:0] tgt_row [0:15];
  reg [2:0] tgt_col [0:15];
  reg [4:0] tgt_count;  // up to 16
  reg [4:0] out_idx;

  // Internal signals
  reg constraint_fail;
  reg [2:0] i_row;
  reg [2:0] i_col;

  integer i;

  // Combinational next_state
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_CHECK;
      end
      S_CHECK: begin
        if (constraint_fail)
          next_state = S_FAIL;
        else
          next_state = S_SOLVE;
      end
      S_SOLVE: begin
        if (constraint_fail)
          next_state = S_FAIL;
        else
          next_state = S_OUT;
      end
      S_OUT: begin
        if (out_idx == tgt_count)
          next_state = S_DONE;
      end
      S_DONE: begin
        next_state = S_IDLE;
      end
      S_FAIL: begin
        next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      valid       <= 1'b0;
      failed      <= 1'b0;
      t_row       <= 3'd0;
      t_col       <= 3'd0;
      t_valid     <= 1'b0;
      done        <= 1'b0;
      tgt_count   <= 5'd0;
      out_idx     <= 5'd0;
      constraint_fail <= 1'b0;
      for (i=0; i<8; i=i+1) begin
        col_req[i] <= 2'd0;
        row_cnt[i] <= 2'd0;
      end
    end else begin
      // Default outputs each cycle
      t_valid <= 1'b0;
      done    <= 1'b0;

      state <= next_state;

      case (state)
        S_IDLE: begin
          valid          <= 1'b0;
          failed         <= 1'b0;
          tgt_count      <= 5'd0;
          out_idx        <= 5'd0;
          constraint_fail<= 1'b0;
          for (i=0; i<8; i=i+1) begin
            row_cnt[i] <= 2'd0;
          end
        end

        S_INIT: begin
          // Load column requirements
          col_req[0] <= (n > 3'd0) ? a_0 : 2'd0;
          col_req[1] <= (n > 3'd1) ? a_1 : 2'd0;
          col_req[2] <= (n > 3'd2) ? a_2 : 2'd0;
          col_req[3] <= (n > 3'd3) ? a_3 : 2'd0;
          col_req[4] <= (n > 3'd4) ? a_4 : 2'd0;
          col_req[5] <= (n > 3'd5) ? a_5 : 2'd0;
          col_req[6] <= (n > 3'd6) ? a_6 : 2'd0;
          col_req[7] <= (n > 3'd7) ? a_7 : 2'd0;

          // Reset row counters and target storage
          for (i=0; i<8; i=i+1) begin
            row_cnt[i] <= 2'd0;
          end
          tgt_count       <= 5'd0;
          out_idx         <= 5'd0;
          constraint_fail <= 1'b0;
        end

        S_CHECK: begin
          // Basic constraints: each column <=2 and total targets <=16
          // Also ensure given inputs are consistent with n
          constraint_fail <= 1'b0;

          // Per-column limit
          for (i=0; i<8; i=i+1) begin
            if (col_req[i] > 2'd2) begin
              constraint_fail <= 1'b1;
            end
          end

          // Total sum and ignore columns >=n in sum
          begin
            reg [4:0] sum;
            sum = 5'd0;
            for (i=0; i<8; i=i+1) begin
              if (i < n)
                sum = sum + col_req[i];
              else if (col_req[i] != 2'd0)
                constraint_fail <= 1'b1; // non-zero outside n is invalid
            end
            if (sum > 5'd16)
              constraint_fail <= 1'b1;
          end
        end

        S_SOLVE: begin
          // Greedy solver: process columns from n-1 down to 0.
          // For each column j, place col_req[j] targets in rows
          // that currently have <2 targets, preferring higher rows.

          constraint_fail <= 1'b0;
          tgt_count       <= 5'd0;

          // Working copies
          for (i=0; i<8; i=i+1) begin
            row_cnt[i] <= 2'd0;
          end

          begin : solve_blk
            integer j;
            integer r;
            integer placed;
            reg [1:0] need;
            reg [1:0] rc [0:7];
            reg [4:0] tc;

            // init local copies
            for (r=0; r<8; r=r+1) begin
              rc[r] = 2'd0;
            end
            tc = 5'd0;

            // columns in reverse order
            for (j=7; j>=0; j=j-1) begin
              if (j < n) begin
                need = col_req[j];
                placed = 0;
                while ((need > 0) && (placed < 2)) begin
                  // find row from bottom (7) to top (0) with <2
                  integer pick;
                  pick = -1;
                  for (r=7; r>=0; r=r-1) begin
                    if (rc[r] < 2'd2) begin
                      pick = r;
                      r = -1; // break
                    end
                  end
                  if (pick == -1) begin
                    constraint_fail <= 1'b1;
                    need = 0;
                  end else begin
                    // assign target
                    rc[pick] = rc[pick] + 2'd1;
                    tgt_row[tc] <= pick[2:0];
                    tgt_col[tc] <= j[2:0];
                    tc = tc + 5'd1;
                    need = need - 1;
                    placed = placed + 1;
                    if (tc > 5'd16) begin
                      constraint_fail <= 1'b1;
                      need = 0;
                    end
                  end
                end
                if (need != 0) begin
                  constraint_fail <= 1'b1;
                end
              end
            end

            // commit if no fail
            if (!constraint_fail) begin
              tgt_count <= tc;
              for (r=0; r<8; r=r+1) begin
                row_cnt[r] <= rc[r];
                if (rc[r] > 2'd2) begin
                  constraint_fail <= 1'b1;
                end
              end
            end
          end
        end

        S_OUT: begin
          // Stream out all targets (one per cycle)
          valid  <= 1'b1;
          failed <= 1'b0;

          if (out_idx < tgt_count) begin
            t_row   <= tgt_row[out_idx] + 3'd1; // convert to 1-based
            t_col   <= tgt_col[out_idx] + 3'd1; // convert to 1-based
            t_valid <= 1'b1;
            out_idx <= out_idx + 5'd1;
          end
        end

        S_DONE: begin
          done  <= 1'b1;
          valid <= (tgt_count != 0) ? 1'b1 : 1'b1; // valid if solution exists (even 0 targets is valid)
        end

        S_FAIL: begin
          failed <= 1'b1;
          done   <= 1'b1;
          valid  <= 1'b0;
        end

        default: begin
        end
      endcase
    end
  end

endmodule