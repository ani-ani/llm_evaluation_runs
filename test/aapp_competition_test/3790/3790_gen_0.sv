module longest_non_decreasing(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] T,
  input [8:0] a [0:7],
  output reg [7:0] result,
  output reg done
);

  // Internal parameters and signals
  reg [3:0] eff_T;                 // effective T = min(T,16)
  reg [7:0] total_len;             // total length = eff_T * n (max 128)

  reg [7:0] i_idx;                 // outer index over extended buffer
  reg [7:0] j_idx;                 // inner index for DP scan

  reg [8:0] cur_val;               // current value for position i
  reg [8:0] j_val;                 // value at position j

  reg [7:0] max_count_mem [0:127]; // DP array for lengths
  reg [7:0] global_max;            // global maximum length
  reg [7:0] best_prev;             // best previous length for current i

  reg [7:0] cycles_left;           // cycle countdown for fixed latency

  // FSM states
  localparam S_IDLE   = 3'd0;
  localparam S_INIT   = 3'd1;
  localparam S_LOAD_I = 3'd2;
  localparam S_INNER  = 3'd3;
  localparam S_WRITE  = 3'd4;
  localparam S_WAIT   = 3'd5;
  localparam S_DONE   = 3'd6;

  reg [2:0] state, next_state;

  // Combinational helpers
  wire [3:0] min_T = (T < 4'd16) ? T : 4'd16;

  // Compute extended index mapping: buffer_idx -> source index
  function automatic [2:0] ext_src_idx;
    input [7:0] idx;
    input [3:0] n_local;
    begin
      if (n_local == 0)
        ext_src_idx = 3'd0;
      else begin
        // idx % n_local, with n_local in 1..8
        case (n_local)
          4'd1: ext_src_idx = 3'd0;
          4'd2: ext_src_idx = idx[0];
          4'd3: ext_src_idx = (idx % 3);
          4'd4: ext_src_idx = idx[1:0];
          4'd5: ext_src_idx = (idx % 5);
          4'd6: ext_src_idx = (idx % 6);
          4'd7: ext_src_idx = (idx % 7);
          default: ext_src_idx = idx[2:0]; // n_local == 8
        endcase
      end
    end
  endfunction

  // Compute cycles needed for latency: 2 + total_len * 9
  function automatic [7:0] compute_cycles;
    input [7:0] total;
    reg [11:0] prod;
    begin
      prod = total * 9; // max 1152, fits in 12 bits
      if (prod + 12'd2 > 12'd255)
        compute_cycles = 8'd255; // saturate (not expected for given bounds)
      else
        compute_cycles = prod[7:0] + 8'd2;
    end
  endfunction

  // Sequential state and main logic
  integer k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      eff_T      <= 4'd0;
      total_len  <= 8'd0;
      i_idx      <= 8'd0;
      j_idx      <= 8'd0;
      cur_val    <= 9'd0;
      j_val      <= 9'd0;
      best_prev  <= 8'd0;
      global_max <= 8'd0;
      result     <= 8'd0;
      done       <= 1'b0;
      cycles_left<= 8'd0;
      for (k = 0; k < 128; k = k + 1) begin
        max_count_mem[k] <= 8'd0;
      end
    end else begin
      state <= next_state;

      done <= 1'b0; // default, one-cycle pulse when set in S_DONE

      case (state)
        S_IDLE: begin
          if (start) begin
            eff_T      <= min_T;
            total_len  <= min_T * n; // n in 1..8, min_T in 1..16, max 128
            i_idx      <= 8'd0;
            j_idx      <= 8'd0;
            best_prev  <= 8'd0;
            global_max <= 8'd0;
            // clear DP memory
            for (k = 0; k < 128; k = k + 1) begin
              max_count_mem[k] <= 8'd0;
            end
            // cycles_left will be set in S_INIT
          end
        end

        S_INIT: begin
          // Set the latency counter: 2 + total_len * 9
          cycles_left <= compute_cycles(total_len);
          if (total_len != 0) begin
            // Prepare first element load
            cur_val <= a[ext_src_idx(8'd0, n)];
            j_idx   <= 8'd0;
            best_prev <= 8'd0;
          end
        end

        S_LOAD_I: begin
          if (i_idx < total_len) begin
            // Load current value for this i
            cur_val   <= a[ext_src_idx(i_idx, n)];
            j_idx     <= 8'd0;
            best_prev <= 8'd0;
          end
        end

        S_INNER: begin
          if (i_idx == 0) begin
            // No previous elements; skip scanning
          end else begin
            if (j_idx < i_idx) begin
              j_val <= a[ext_src_idx(j_idx, n)];
              if (j_val <= cur_val) begin
                if (max_count_mem[j_idx] + 8'd1 > best_prev)
                  best_prev <= max_count_mem[j_idx] + 8'd1;
              end
              j_idx <= j_idx + 8'd1;
            end
          end
        end

        S_WRITE: begin
          // Write DP value for position i
          if (i_idx == 0) begin
            max_count_mem[i_idx] <= 8'd1;
            if (8'd1 > global_max)
              global_max <= 8'd1;
          end else begin
            if (best_prev == 8'd0)
              max_count_mem[i_idx] <= 8'd1;
            else
              max_count_mem[i_idx] <= best_prev;

            if (best_prev == 8'd0) begin
              if (8'd1 > global_max)
                global_max <= 8'd1;
            end else begin
              if (best_prev > global_max)
                global_max <= best_prev;
            end
          end

          i_idx <= i_idx + 8'd1;

          // Decrement cycles_left every DP-step (one per i)
          if (cycles_left != 8'd0)
            cycles_left <= cycles_left - 8'd1;
        end

        S_WAIT: begin
          // Drain remaining cycles to match specified latency
          if (cycles_left != 8'd0)
            cycles_left <= cycles_left - 8'd1;
        end

        S_DONE: begin
          result <= global_max;
          done   <= 1'b1; // one-cycle pulse
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        if (total_len == 0) begin
          // Edge case: no elements, go directly to DONE after latency
          if (cycles_left == 0)
            next_state = S_DONE;
          else
            next_state = S_WAIT;
        end else begin
          next_state = S_LOAD_I;
        end
      end

      S_LOAD_I: begin
        if (i_idx < total_len) begin
          if (i_idx == 0)
            next_state = S_WRITE; // no inner scan needed
          else
            next_state = S_INNER;
        end else begin
          next_state = S_WAIT;
        end
      end

      S_INNER: begin
        if (i_idx == 0) begin
          next_state = S_WRITE;
        end else if (j_idx >= i_idx) begin
          next_state = S_WRITE;
        end else begin
          next_state = S_INNER;
        end
      end

      S_WRITE: begin
        if (i_idx + 8'd1 < total_len)
          next_state = S_LOAD_I;
        else
          next_state = S_WAIT;
      end

      S_WAIT: begin
        if (cycles_left == 0)
          next_state = S_DONE;
        else
          next_state = S_WAIT;
      end

      S_DONE: begin
        // After signaling done, return to IDLE
        next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule