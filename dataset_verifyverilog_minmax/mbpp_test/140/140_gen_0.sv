module flatten_unique_numbers(
  input clk,
  input rst_n,
  input start,
  input [2:0][2:0][7:0] list_data,
  output reg [7:0] unique_array [0:7],
  output reg [2:0] unique_count,
  output reg done
);

  // 256-bit seen register: seen[value] == 1 means value already seen
  logic [255:0] seen;
  logic [255:0] seen_next;

  // 4-bit index to process 9 elements in row-major order over 9 cycles
  logic [3:0] idx;
  logic [3:0] idx_next;

  // Two-stage pipeline for unique detection and storage
  logic add_en, add_en_next;
  logic [7:0] add_value, add_value_next;
  logic processing, processing_next;
  logic [2:0] unique_count_next;

  always_comb begin
    // Defaults
    seen_next    = seen;
    idx_next     = idx;
    add_en_next  = 1'b0;
    add_value_next = 8'b0;
    unique_count_next = unique_count;
    processing_next   = processing;
    done = 1'b0;

    // Start pulse detection and initiation
    if (start && !processing) begin
      processing_next = 1'b1;
      idx_next        = 4'b0;
      // Will be cleared in FF (next clock)
    end

    // Always 9 cycles from start pulse (if start is deasserted in the first cycle)
    if (processing) begin
      if (idx == 4'd8) begin
        // Last cycle
        done = 1'b1;
        processing_next = 1'b0; // stop after 9th cycle
        idx_next        = 4'b0;
      end else begin
        // Normal progression
        processing_next = 1'b1;
        idx_next        = idx + 1'b1;
      end
    end

    // First stage: check current element, set up add for next stage
    if (processing) begin
      integer r, c;
      r = idx[3:2]; // 0..2
      c = idx[1:0]; // 0..2
      logic [7:0] cur;
      cur = list_data[r][c];
      if (!seen[cur]) begin
        seen_next[cur] = 1'b1;      // mark seen for next cycle
        add_en_next    = 1'b1;      // enqueue to write next cycle
        add_value_next = cur;
        unique_count_next = (idx == 4'd8) ? (unique_count + 1'b1) : unique_count; // Count last addition this cycle
      end
    end
  end

  // Update memory and counters on the next clock edge
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset state
      seen          <= 256'b0;
      idx           <= 4'b0;
      add_en        <= 1'b0;
      add_value     <= 8'b0;
      processing    <= 1'b0;
      unique_count  <= 3'b0;
      unique_array[0] <= 8'b0;
      unique_array[1] <= 8'b0;
      unique_array[2] <= 8'b0;
      unique_array[3] <= 8'b0;
      unique_array[4] <= 8'b0;
      unique_array[5] <= 8'b0;
      unique_array[6] <= 8'b0;
      unique_array[7] <= 8'b0;
    end else begin
      // Latch combinatorial next-state
      seen          <= seen_next;
      idx           <= idx_next;
      add_en        <= add_en_next;
      add_value     <= add_value_next;
      processing    <= processing_next;
      unique_count  <= unique_count_next;

      // Second stage: write unique value (if any) to array
      if (add_en) begin
        unique_array[unique_count_next] <= add_value;
      end
    end
  end

endmodule
