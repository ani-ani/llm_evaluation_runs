module wheel_rotator(
  input clk,
  input rst_n,
  input start,
  input [2:0] str_len,
  input [7:0][1:0] wheel0,
  input [7:0][1:0] wheel1,
  input [7:0][1:0] wheel2,
  output reg [3:0] result,
  output reg done
);

  // State encoding
  localparam [1:0]
    S_IDLE  = 2'd0,
    S_INIT  = 2'd1,
    S_CALC  = 2'd2,
    S_DONE  = 2'd3;

  reg [1:0] state, next_state;

  // Internal registers
  reg [6:0] best_cost;           // track minimal rotations (0-14, 7 bits for safety)
  reg [6:0] cycle_cnt;          // watchdog to ensure <1000 cycles

  // Offset enumeration indices: 0..15 -> offsets -7..+8, but we only use -7..+7
  reg [4:0] idx1, idx2, idx3;   // each 0..15

  reg [4:0] idx1_next, idx2_next, idx3_next;

  reg [3:0] cur_cost;
  reg cur_valid;

  // decode idx (0..15) into signed offset (-7..+7), ignore 15
  function automatic signed [4:0] idx_to_off(input [4:0] idx);
    begin
      // map 0->-7,1->-6,...,7->0,...,14->+7
      idx_to_off = $signed(idx) - 5'sd7;
    end
  endfunction

  // modulo for positive/negative offsets in range [0,7]
  function automatic [2:0] add_mod_len(
    input [2:0] base,
    input signed [4:0] off,
    input [2:0] len
  );
    integer tmp;
    begin
      tmp = base + off;
      // Normalize within [0,len-1]
      while (tmp < 0)
        tmp = tmp + len;
      while (tmp >= len)
        tmp = tmp - len;
      add_mod_len = tmp[2:0];
    end
  endfunction

  // Manhattan-like rotation cost on ring of length len
  function automatic [3:0] rot_cost(
    input signed [4:0] o1,
    input signed [4:0] o2,
    input [2:0] len
  );
    integer a1, a2;
    integer diff;
    begin
      a1 = (o1 < 0) ? -o1 : o1;
      a2 = (o2 < 0) ? -o2 : o2;
      // cost = |o1| + |o2| (single-wheel rotations, no wrap-shortcut per spec)
      diff = a1 + a2;
      rot_cost = diff[3:0];
    end
  endfunction

  // Check distinctness for given offsets; compute cost and validity
  task automatic check_offsets(
    input signed [4:0] o1,
    input signed [4:0] o2,
    input signed [4:0] o3,
    input [2:0] len,
    input [7:0][1:0] w0,
    input [7:0][1:0] w1,
    input [7:0][1:0] w2,
    output reg [3:0] cost,
    output reg valid
  );
    integer i;
    reg [2:0] p0, p1, p2;
    reg [1:0] c0, c1, c2;
    begin
      valid = 1'b1;
      // Check for invalid offset index: we only allow -7..+7, so caller must enforce
      for (i = 0; i < 8; i = i + 1) begin
        if (i < len) begin
          p0 = add_mod_len(i[2:0], o1, len);
          p1 = add_mod_len(i[2:0], o2, len);
          p2 = add_mod_len(i[2:0], o3, len);

          c0 = w0[p0];
          c1 = w1[p1];
          c2 = w2[p2];

          // any invalid letter 11
          if (c0 == 2'b11 || c1 == 2'b11 || c2 == 2'b11) begin
            valid = 1'b0;
          end else begin
            // all distinct letters in this column
            if (!((c0 != c1) && (c0 != c2) && (c1 != c2))) begin
              valid = 1'b0;
            end
          end
        end
      end

      if (valid) begin
        cost = rot_cost(o1, o2, len) + rot_cost(o3, 5'sd0, len);
        // Correction: spec says single-wheel rotations across 3 wheels.
        // Adjust: cost = |o1| + |o2| + |o3|
        begin
          integer a1, a2, a3;
          a1 = (o1 < 0) ? -o1 : o1;
          a2 = (o2 < 0) ? -o2 : o2;
          a3 = (o3 < 0) ? -o3 : o3;
          cost = (a1 + a2 + a3) [3:0];
        end
      end else begin
        cost = 4'hF;
      end
    end
  endtask

  // Combinational next-state and iteration logic
  always @* begin
    next_state = state;
    idx1_next = idx1;
    idx2_next = idx2;
    idx3_next = idx3;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_INIT;
        end
      end

      S_INIT: begin
        // Start with all offsets index=7 -> offset 0
        idx1_next = 5'd0; // will be set sequentially, but start from 0
        idx2_next = 5'd0;
        idx3_next = 5'd0;
        next_state = S_CALC;
      end

      S_CALC: begin
        // Iterate idx3 fastest, then idx2, then idx1
        idx1_next = idx1;
        idx2_next = idx2;
        idx3_next = idx3;

        // Advance after each evaluation (happens in sequential always)
        if (idx3 == 5'd14) begin
          idx3_next = 5'd0;
          if (idx2 == 5'd14) begin
            idx2_next = 5'd0;
            if (idx1 == 5'd14) begin
              // all combinations done
              next_state = S_DONE;
            end else begin
              idx1_next = idx1 + 5'd1;
            end
          } else begin
            idx2_next = idx2 + 5'd1;
          end
        end else begin
          idx3_next = idx3 + 5'd1;
        end
      end

      S_DONE: begin
        // wait here until next start
        if (start)
          next_state = S_INIT;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Combinational evaluation of current offsets
  always @* begin
    cur_valid = 1'b0;
    cur_cost  = 4'hF;

    if (state == S_CALC) begin
      // translate indices to offsets; ignore idx=15 (not used)
      if (idx1 <= 5'd14 && idx2 <= 5'd14 && idx3 <= 5'd14) begin
        signed [4:0] o1, o2, o3;
        o1 = idx_to_off(idx1);
        o2 = idx_to_off(idx2);
        o3 = idx_to_off(idx3);

        // Only consider offsets magnitude <=7 (by construction) and length in [2..8]
        if (str_len >= 3'd2 && str_len <= 3'd8) begin
          check_offsets(o1, o2, o3, str_len, wheel0, wheel1, wheel2, cur_cost, cur_valid);
        end else begin
          cur_valid = 1'b0;
          cur_cost  = 4'hF;
        end
      end else begin
        cur_valid = 1'b0;
        cur_cost  = 4'hF;
      end
    end
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      idx1      <= 5'd0;
      idx2      <= 5'd0;
      idx3      <= 5'd0;
      best_cost <= 7'd127;
      result    <= 4'hF;
      done      <= 1'b0;
      cycle_cnt <= 7'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done      <= 1'b0;
          result    <= 4'hF;
          best_cost <= 7'd127;
          cycle_cnt <= 7'd0;
          if (start) begin
            idx1 <= 5'd0;
            idx2 <= 5'd0;
            idx3 <= 5'd0;
          end
        end

        S_INIT: begin
          done      <= 1'b0;
          best_cost <= 7'd127;
          result    <= 4'hF;
          idx1      <= 5'd0;
          idx2      <= 5'd0;
          idx3      <= 5'd0;
          cycle_cnt <= 7'd0;
        end

        S_CALC: begin
          // Update best_cost if current combo valid and better
          if (cur_valid) begin
            if (cur_cost < best_cost[3:0]) begin
              best_cost <= {3'b000, cur_cost};
            end
          end

          // Advance indices
          idx1 <= idx1_next;
          idx2 <= idx2_next;
          idx3 <= idx3_next;

          // Increment cycle counter (7 bits: up to 127, enough for our small search)
          cycle_cnt <= cycle_cnt + 7'd1;
        end

        S_DONE: begin
          done <= 1'b1;
          // Determine result from best_cost
          if (best_cost == 7'd127) begin
            result <= 4'hF; // no valid combination
          end else begin
            if (best_cost[3:0] > 4'd14)
              result <= 4'hF;
            else
              result <= best_cost[3:0];
          end

          // If new start, re-init indices (next_state handles transition)
          if (start) begin
            done      <= 1'b0;
            best_cost <= 7'd127;
            result    <= 4'hF;
            idx1      <= 5'd0;
            idx2      <= 5'd0;
            idx3      <= 5'd0;
            cycle_cnt <= 7'd0;
          end
        end

        default: begin
          state     <= S_IDLE;
          done      <= 1'b0;
          result    <= 4'hF;
          idx1      <= 5'd0;
          idx2      <= 5'd0;
          idx3      <= 5'd0;
          best_cost <= 7'd127;
          cycle_cnt <= 7'd0;
        end
      endcase
    end
  end

endmodule