module courier_partition_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] x[0:7],
  input [3:0] y[0:7],
  input [2:0] num_customers,
  output reg [4:0] min_max_time,
  output reg done
);

  // State encoding
  localparam IDLE = 2'b00;
  localparam CALC_DIST = 2'b01;
  localparam EVAL_PARTITIONS = 2'b10;
  localparam DONE = 2'b11;

  // Internal state
  reg [1:0] state, next_state;
  reg start_r;
  wire start_edge;
  assign start_edge = start && !start_r;

  // Customer storage and counts
  reg [3:0] xs[0:7];
  reg [3:0] ys[0:7];
  reg [2:0] n_cust;
  reg capture;
  reg [2:0] n_cust_d; // delayed copy (for distance calc timing)
  reg [4:0] pair_dist[0:27];
  reg [5:0] dcount; // 0..28
  reg [7:0] mask_r; // current partition mask (bit i => company A)
  reg [7:0] mask_r_d; // delayed mask (for distance lookup timing)
  reg [7:0] best_mask;
  reg [4:0] best;
  reg [7:0] part_idx; // 1..254
  reg [4:0] cur_maxA, cur_maxB, cur_maxBoth;

  integer i, j, ii, jj;

  // Capture inputs and update n_cust
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_cust <= 3'b0;
      for (i = 0; i < 8; i = i + 1) begin
        xs[i] <= 4'b0;
        ys[i] <= 4'b0;
      end
    end else begin
      if (capture) begin
        n_cust <= num_customers;
        for (i = 0; i < 8; i = i + 1) begin
          xs[i] <= x[i];
          ys[i] <= y[i];
        end
      end
    end
  end

  // Pairwise distance precomputation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dcount <= 6'b0;
      for (i = 0; i < 28; i = i + 1) pair_dist[i] <= 5'b0;
    end else begin
      n_cust_d <= n_cust; // pipeline
      if (state == CALC_DIST) begin
        if (dcount < (n_cust_d * (n_cust_d - 1) / 2)) begin
          // Map linear index dcount to (i,j)
          // Find i such that dcount >= i*(n_cust_d-1) - i*(i-1)/2
          for (i = 0; i < 8; i = i + 1) begin
            if (i >= n_cust_d) break;
            if (dcount >= (i * (n_cust_d - 1) - (i * (i - 1) / 2))) begin
              // j index within that row
              for (j = i + 1; j < n_cust_d; j = j + 1) begin
                if (dcount == (i * (n_cust_d - 1) - (i * (i - 1) / 2) + (j - i - 1))) begin
                  pair_dist[dcount] <= $unsigned(xs[i]) + $unsigned(ys[i]) + ~($unsigned(xs[j]) + $unsigned(ys[j]) + 1);
                  // The expression above computes |xs[i]-xs[j]| + |ys[i]-ys[j]| using unsigned arithmetic and two's complement trick
                  // (A + B) - (C + D) is safe within 5 bits; however to avoid overflow/trickiness, use direct expression below:
                end
              end
            end
          end
          // Use explicit Manhattan distance for clarity and correctness:
          if (dcount < 28) begin
            // Redo using explicit formula to ensure correct distances
            for (ii = 0; ii < 8; ii = ii + 1) begin
              if (ii >= n_cust_d) break;
              for (jj = ii + 1; jj < n_cust_d; jj = jj + 1) begin
                if (dcount == (ii * (n_cust_d - 1) - (ii * (ii - 1) / 2) + (jj - ii - 1))) begin
                  pair_dist[dcount] <= $unsigned(xs[ii] > xs[jj] ? xs[ii] - xs[jj] : xs[jj] - xs[ii])
                                     + $unsigned(ys[ii] > ys[jj] ? ys[ii] - ys[jj] : ys[jj] - ys[ii]);
                end
              end
            end
          end
          dcount <= dcount + 1;
        end
      end else begin
        dcount <= 6'b0;
      end
    end
  end

  // Partition evaluation logic (combinational with registered inputs)
  function [4:0] partition_max;
    input [7:0] mask; // bit i => company A (1), else B (0)
    input [7:0] n;
    input [4:0] dist[0:27];
    reg [4:0] maxA, maxB;
    reg [7:0] a, b;
    begin
      maxA = 5'b0;
      maxB = 5'b0;
      a = mask & ((1 << n) - 1);
      b = (~mask) & ((1 << n) - 1);
      // Compute max distance inside company A
      for (i = 0; i < 8; i = i + 1) begin
        if (i >= n) break;
        if (a[i]) begin
          for (j = i + 1; j < 8; j = j + 1) begin
            if (j >= n) break;
            if (a[j]) begin
              // d(i,j) = i*(n-1) - i*(i-1)/2 + (j-i-1)
              if (i < j) begin
                partition_max = dist[i * (n - 1) - (i * (i - 1) / 2) + (j - i - 1)];
                maxA = (partition_max > maxA) ? partition_max : maxA;
              end
            end
          end
        end
      end
      // Compute max distance inside company B
      for (i = 0; i < 8; i = i + 1) begin
        if (i >= n) break;
        if (b[i]) begin
          for (j = i + 1; j < 8; j = j + 1) begin
            if (j >= n) break;
            if (b[j]) begin
              if (i < j) begin
                partition_max = dist[i * (n - 1) - (i * (i - 1) / 2) + (j - i - 1)];
                maxB = (partition_max > maxB) ? partition_max : maxB;
              end
            end
          end
        end
      end
      // If group empty, its max should be 0 so that max(maxA,maxB) is controlled by the non-empty group.
      maxA = (a == 0) ? 5'b0 : maxA;
      maxB = (b == 0) ? 5'b0 : maxB;
      partition_max = (maxA > maxB) ? maxA : maxB; // min-max (worst company time)
    end
  endfunction

  always @(*) begin
    cur_maxBoth = partition_max(mask_r_d, n_cust_d, pair_dist);
  end

  // Main FSM: next state logic and control signals
  always @(*) begin
    next_state = state;
    done = 1'b0;
    capture = 1'b0;
    case (state)
      IDLE: begin
        capture = 1'b1; // latch inputs and count on start edge
        if (start_edge) next_state = CALC_DIST;
      end
      CALC_DIST: begin
        if (dcount >= (n_cust * (n_cust - 1) / 2)) begin
          // Begin partition search with mask=1 (all to A), then next = 2,3,...254
          mask_r = 8'd1; // 00000001b
          part_idx = 8'd1;
          best = 5'd31; // upper bound (0..30)
          best_mask = 8'b0;
          next_state = EVAL_PARTITIONS;
        end
      end
      EVAL_PARTITIONS: begin
        // Evaluate current partition, then iterate masks up to 254
        if (part_idx < 8'd254) begin
          mask_r = part_idx + 1; // ensure mask != 0 and != 255
          part_idx = part_idx + 1;
        end else begin
          next_state = DONE;
        end
      end
      DONE: begin
        done = 1'b1;
        if (start_edge) next_state = CALC_DIST;
      end
      default: next_state = IDLE;
    endcase
  end

  // State update and best/result tracking
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      start_r <= 1'b0;
      min_max_time <= 5'b0;
      mask_r_d <= 8'b0;
    end else begin
      start_r <= start;
      state <= next_state;
      mask_r_d <= mask_r; // pipeline mask for partition evaluation

      if (state == IDLE) begin
        min_max_time <= 5'b0;
      end

      // During EVAL_PARTITIONS, update best and result
      if (state == EVAL_PARTITIONS) begin
        // Update best on every evaluated partition (including the first after CALC_DIST)
        if (cur_maxBoth < best) begin
          best <= cur_maxBoth;
          best_mask <= mask_r_d;
        end
        // At the moment we reach DONE, snapshot best to output
        if (next_state == DONE) begin
          min_max_time <= best;
        end
      end
    end
  end

endmodule
