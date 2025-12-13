module string_sublist_sorter(
  input clk,
  input rst_n,
  input start,
  input [3:0][31:0] sublist_in,
  output reg [3:0][31:0] sorted_sublist,
  output reg done
);

  // Internal pipeline registers
  reg active;                    // Indicates an operation is in progress
  reg [1:0] cycle_cnt;           // Counts cycles 0..3 during sorting

  reg [31:0] s0, s1, s2, s3;     // Working registers for bubble sort

  // Next-state signals
  reg [31:0] n_s0, n_s1, n_s2, n_s3;
  reg [1:0]  n_cycle_cnt;
  reg        n_active;
  reg        n_done;

  // String less-than comparison (lexicographical, ASCII, MSB char first)
  function automatic logic str_is_less(input [31:0] a, input [31:0] b);
    logic [7:0] a3, a2, a1, a0;
    logic [7:0] b3, b2, b1, b0;
    begin
      {a3, a2, a1, a0} = a;
      {b3, b2, b1, b0} = b;

      if (a3 != b3)      str_is_less = (a3 < b3);
      else if (a2 != b2) str_is_less = (a2 < b2);
      else if (a1 != b1) str_is_less = (a1 < b1);
      else if (a0 != b0) str_is_less = (a0 < b0);
      else               str_is_less = 1'b0;
    end
  endfunction

  // Treat 0 string as maximal so empties move to end
  function automatic logic str_a_gt_b_eff(input [31:0] a, input [31:0] b);
    logic a_zero, b_zero;
    begin
      a_zero = (a == 32'b0);
      b_zero = (b == 32'b0);

      // If both zero or equal, not greater
      if ((a_zero && b_zero) || (a == b)) begin
        str_a_gt_b_eff = 1'b0;
      end else if (a_zero && !b_zero) begin
        // zero considered maximal -> a > b
        str_a_gt_b_eff = 1'b1;
      end else if (!a_zero && b_zero) begin
        // non-zero < zero -> a not greater
        str_a_gt_b_eff = 1'b0;
      end else begin
        // both non-zero: lex compare
        str_a_gt_b_eff = str_is_less(b, a);
      end
    end
  endfunction

  // Combinational next-state logic
  always @* begin
    // Default hold
    n_s0        = s0;
    n_s1        = s1;
    n_s2        = s2;
    n_s3        = s3;
    n_cycle_cnt = cycle_cnt;
    n_active    = active;
    n_done      = 1'b0;

    if (!active) begin
      // Idle: wait for start to load new inputs
      if (start) begin
        n_s0        = sublist_in[0];
        n_s1        = sublist_in[1];
        n_s2        = sublist_in[2];
        n_s3        = sublist_in[3];
        n_cycle_cnt = 2'd0;
        n_active    = 1'b1;
      end
    end else begin
      // Active: perform one bubble-sort pass step per cycle
      case (cycle_cnt)
        2'd0: begin
          // Pass 0: compare (0,1), (1,2), (2,3)
          if (str_a_gt_b_eff(n_s0, n_s1)) begin
            {n_s0, n_s1} = {n_s1, n_s0};
          end
          if (str_a_gt_b_eff(n_s1, n_s2)) begin
            {n_s1, n_s2} = {n_s2, n_s1};
          end
          if (str_a_gt_b_eff(n_s2, n_s3)) begin
            {n_s2, n_s3} = {n_s3, n_s2};
          end
          n_cycle_cnt = 2'd1;
        end

        2'd1: begin
          // Pass 1: compare (0,1), (1,2)
          if (str_a_gt_b_eff(n_s0, n_s1)) begin
            {n_s0, n_s1} = {n_s1, n_s0};
          end
          if (str_a_gt_b_eff(n_s1, n_s2)) begin
            {n_s1, n_s2} = {n_s2, n_s1};
          end
          n_cycle_cnt = 2'd2;
        end

        2'd2: begin
          // Pass 2: compare (0,1)
          if (str_a_gt_b_eff(n_s0, n_s1)) begin
            {n_s0, n_s1} = {n_s1, n_s0};
          end
          n_cycle_cnt = 2'd3;
        end

        2'd3: begin
          // Sorting complete: latch result and signal done
          n_active = 1'b0;
          n_done   = 1'b1;
        end

        default: begin
          n_active = 1'b0;
        end
      endcase
    end
  end

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s0             <= 32'b0;
      s1             <= 32'b0;
      s2             <= 32'b0;
      s3             <= 32'b0;
      cycle_cnt      <= 2'b0;
      active         <= 1'b0;
      sorted_sublist <= '{default:32'b0};
      done           <= 1'b0;
    end else begin
      s0        <= n_s0;
      s1        <= n_s1;
      s2        <= n_s2;
      s3        <= n_s3;
      cycle_cnt <= n_cycle_cnt;
      active    <= n_active;
      done      <= n_done;

      // Update sorted_sublist when operation completes
      if (active && (cycle_cnt == 2'd3)) begin
        sorted_sublist[0] <= n_s0;
        sorted_sublist[1] <= n_s1;
        sorted_sublist[2] <= n_s2;
        sorted_sublist[3] <= n_s3;
      end
    end
  end

endmodule