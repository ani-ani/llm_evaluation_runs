module knapsack_solver(
  input clk,
  input rst_n,
  input start,
  input [2:0] jewel_count,
  input [7:0] jewel_sizes [0:7],
  input [7:0] jewel_values [0:7],
  output reg [10:0] dp_table [0:7],
  output reg done
);

  // Internal registers
  reg [2:0] curr_jewel;          // index of current jewel (0-7)
  reg [7:0] size_reg [0:7];      // latched sizes
  reg [7:0] value_reg [0:7];     // latched values
  reg [2:0] jewel_count_reg;     // latched jewel count

  reg processing;                // active computation flag

  // For DP update
  reg [2:0] k_idx;               // current knapsack size index (0..7) representing size k_idx+1
  reg [10:0] dp_next [0:7];      // next cycle dp values
  reg [10:0] candidate;
  reg [10:0] current;
  reg [10:0] base;

  integer i;

  // Combinational DP update for a single jewel over all capacities (1..8)
  always @* begin
    // Default: hold previous values
    for (i = 0; i < 8; i = i + 1) begin
      dp_next[i] = dp_table[i];
    end

    if (processing && (curr_jewel < jewel_count_reg)) begin
      // Apply 0/1 knapsack update for jewel curr_jewel to all capacities in parallel
      for (i = 0; i < 8; i = i + 1) begin
        if ((i + 1) >= size_reg[curr_jewel] && size_reg[curr_jewel] != 0) begin
          // base index = current capacity - jewel_size
          if ((i + 1 - size_reg[curr_jewel]) == 0) begin
            base = 11'd0;
          end else begin
            base = dp_table[(i + 1 - size_reg[curr_jewel]) - 1];
          end
          candidate = base + value_reg[curr_jewel];
          current   = dp_table[i];
          dp_next[i] = (candidate > current) ? candidate : current;
        end
      end
    end
  end

  // Sequential control and state updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      for (i = 0; i < 8; i = i + 1) begin
        dp_table[i] <= 11'd0;
        size_reg[i] <= 8'd0;
        value_reg[i] <= 8'd0;
      end
      jewel_count_reg <= 3'd0;
      curr_jewel <= 3'd0;
      processing <= 1'b0;
      done <= 1'b0;
      k_idx <= 3'd0;
    end else begin
      // Default
      done <= 1'b0;

      if (start && !processing) begin
        // Latch inputs and initialize DP when start asserted
        jewel_count_reg <= jewel_count;
        for (i = 0; i < 8; i = i + 1) begin
          size_reg[i] <= jewel_sizes[i];
          value_reg[i] <= jewel_values[i];
          dp_table[i] <= 11'd0;
        end
        curr_jewel <= 3'd0;
        processing <= 1'b1;
        k_idx <= 3'd0;
      end else if (processing) begin
        if (curr_jewel < jewel_count_reg) begin
          // Apply one jewel per cycle using precomputed dp_next
          for (i = 0; i < 8; i = i + 1) begin
            dp_table[i] <= dp_next[i];
          end
          curr_jewel <= curr_jewel + 3'd1;
        end else begin
          // One extra cycle after last jewel to assert done
          done <= 1'b1;
          processing <= 1'b0;
        end
      end
    end
  end

endmodule