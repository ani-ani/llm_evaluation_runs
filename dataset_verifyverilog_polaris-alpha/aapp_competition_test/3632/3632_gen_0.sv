module composite_string_position(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] k,
  input [7:0][31:0] sorted_strings,
  input [3:0][2:0] test_indices,
  output reg [15:0] position,
  output reg done
);

  // Internal registers
  reg [7:0] used_mask;
  reg [1:0] step_cnt;          // supports up to 3 (for k up to 4)
  reg [15:0] accum;            // accumulation of rank contribution
  reg [1:0] k_reg;             // latched k
  reg [2:0] n_reg;             // latched n
  reg active;                  // indicates computation is in progress

  // current index and count
  reg [2:0] cur_idx;
  reg [2:0] count_smaller;

  // function for permutation P(a,b) = a! / (a-b)!
  function automatic [15:0] perm;
    input [2:0] a;
    input [2:0] b;
    reg [15:0] fact_a;
    reg [15:0] fact_d;
    reg [3:0] d;
    begin
      // factorial values for 0..8
      case (a)
        3'd0: fact_a = 16'd1;
        3'd1: fact_a = 16'd1;
        3'd2: fact_a = 16'd2;
        3'd3: fact_a = 16'd6;
        3'd4: fact_a = 16'd24;
        3'd5: fact_a = 16'd120;
        3'd6: fact_a = 16'd720;
        3'd7: fact_a = 16'd5040;
        3'd8: fact_a = 16'd40320;
        default: fact_a = 16'd1;
      endcase

      d = a - b; // (a-b)
      case (d[2:0])
        3'd0: fact_d = 16'd1;
        3'd1: fact_d = 16'd1;
        3'd2: fact_d = 16'd2;
        3'd3: fact_d = 16'd6;
        3'd4: fact_d = 16'd24;
        3'd5: fact_d = 16'd120;
        3'd6: fact_d = 16'd720;
        3'd7: fact_d = 16'd5040;
        3'd8: fact_d = 16'd40320;
        default: fact_d = 16'd1;
      endcase

      if (b == 3'd0)
        perm = 16'd1;
      else if (a < b)
        perm = 16'd0;
      else
        perm = fact_a / fact_d;
    end
  endfunction

  // combinational: count number of unused indices smaller than cur_idx
  function automatic [2:0] count_unused_smaller;
    input [7:0] used;
    input [2:0] idx;
    integer j;
    reg [2:0] c;
    begin
      c = 3'd0;
      for (j = 0; j < 8; j = j + 1) begin
        if ((j < idx) && (used[j] == 1'b0))
          c = c + 3'd1;
      end
      count_unused_smaller = c;
    end
  endfunction

  // combinational: fetch current index based on step_cnt (MSB first)
  function automatic [2:0] get_cur_idx;
    input [1:0] step;
    input [3:0][2:0] idx_vec;
    begin
      case (step)
        2'd0: get_cur_idx = idx_vec[3];
        2'd1: get_cur_idx = idx_vec[2];
        2'd2: get_cur_idx = idx_vec[1];
        2'd3: get_cur_idx = idx_vec[0];
        default: get_cur_idx = 3'd0;
      endcase
    end
  endfunction

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      used_mask <= 8'd0;
      step_cnt  <= 2'd0;
      accum     <= 16'd0;
      k_reg     <= 2'd0;
      n_reg     <= 3'd0;
      active    <= 1'b0;
      position  <= 16'd0;
      done      <= 1'b0;
    end else begin
      if (start && !active) begin
        // Initialize computation on start pulse
        used_mask <= 8'd0;
        step_cnt  <= 2'd0;
        accum     <= 16'd0;
        k_reg     <= k;
        n_reg     <= n;
        active    <= 1'b1;
        done      <= 1'b0;
      end else if (active) begin
        // Compute for current step
        cur_idx       <= get_cur_idx(step_cnt, test_indices);
        count_smaller <= count_unused_smaller(used_mask, get_cur_idx(step_cnt, test_indices));

        // Update accumulation with permutation weight
        // weight = P( n_reg - step_cnt - 1, k_reg - step_cnt - 1 )
        if ((k_reg - step_cnt - 1) != 2'd3 && (k_reg - step_cnt - 1) <= n_reg) begin
          accum <= accum + (count_unused_smaller(used_mask, get_cur_idx(step_cnt, test_indices)) *
                            perm(n_reg - step_cnt - 1, k_reg - step_cnt - 1));
        end else begin
          accum <= accum;
        end

        // Mark current index as used
        used_mask[get_cur_idx(step_cnt, test_indices)] <= 1'b1;

        // Advance step counter
        if (step_cnt + 1 == k_reg) begin
          // Final step completed
          active   <= 1'b0;
          done     <= 1'b1;
          position <= accum + 16'd1;
        end else begin
          step_cnt <= step_cnt + 2'd1;
        end
      end
    end
  end

endmodule