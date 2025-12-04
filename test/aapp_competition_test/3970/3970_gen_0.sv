module k_multiple_free(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] k,
  input [9:0] elements [0:15],
  output reg [4:0] result,
  output reg done
);

  // State encoding
  localparam IDLE      = 3'd0;
  localparam LOAD      = 3'd1;
  localparam SORT      = 3'd2;
  localparam SELECT    = 3'd3;
  localparam FINISH    = 3'd4;

  reg [2:0] state, next_state;

  // Internal storage
  reg [9:0] arr [0:15];       // working array for sort and select
  reg [3:0] cur_n;            // number of elements actually used (<=16)

  // Bubble sort indices
  reg [3:0] i_idx;            // outer loop index
  reg [3:0] j_idx;            // inner loop index

  // Temporary registers for swap
  reg [9:0] temp_a, temp_b;

  // Selection stage registers
  reg [3:0] sel_idx;          // index of current element being considered
  reg [3:0] scan_idx;         // index for scanning multiples
  reg       checking;         // 1 if currently scanning for multiple
  reg       conflict;         // 1 if multiple found

  // Track selected elements using a bitmap (1 = selected)
  reg [15:0] selected_mask;

  // Registered version of k to use in datapath
  reg [15:0] k_reg;

  // Counter for selected elements
  reg [4:0] selected_count;

  // Start edge detection
  reg start_d;
  wire start_pulse;

  assign start_pulse = start & ~start_d;

  // Sequential logic: state, registers
  integer idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      start_d         <= 1'b0;
      cur_n           <= 4'd0;
      k_reg           <= 16'd0;
      result          <= 5'd0;
      done            <= 1'b0;
      i_idx           <= 4'd0;
      j_idx           <= 4'd0;
      sel_idx         <= 4'd0;
      scan_idx        <= 4'd0;
      checking        <= 1'b0;
      conflict        <= 1'b0;
      selected_mask   <= 16'd0;
      selected_count  <= 5'd0;
      for (idx = 0; idx < 16; idx = idx + 1) begin
        arr[idx] <= 10'd0;
      end
    end else begin
      // capture delayed start
      start_d <= start;

      // default outputs
      done <= 1'b0;

      // state transition
      state <= next_state;

      case (state)
        IDLE: begin
          if (start_pulse) begin
            // latch inputs in LOAD state via next_state logic
          end
        end

        LOAD: begin
          // inputs already assumed stable on start_pulse
          // store elements and parameters
          k_reg <= (k == 16'd0) ? 16'd1 : k; // ensure k_reg >= 1 as per spec

          // bound n to max 16 and min 0
          if (n > 4'd16)
            cur_n <= 4'd16;
          else
            cur_n <= n;

          for (idx = 0; idx < 16; idx = idx + 1) begin
            arr[idx] <= elements[idx];
          end

          // init sort indices
          i_idx <= 4'd0;
          j_idx <= 4'd0;
        end

        SORT: begin
          // Bubble sort descending: perform one compare-swap per cycle
          // Only sort first cur_n elements; if cur_n <= 1, no swaps.
          if (cur_n > 1) begin
            if (i_idx < (cur_n - 1)) begin
              if (j_idx < (cur_n - 1 - i_idx)) begin
                // compare arr[j_idx] and arr[j_idx+1]
                temp_a = arr[j_idx];
                temp_b = arr[j_idx + 1];
                if (temp_a < temp_b) begin
                  // swap to make descending
                  arr[j_idx]       <= temp_b;
                  arr[j_idx + 1]   <= temp_a;
                end
                j_idx <= j_idx + 1;
              end else begin
                j_idx <= 4'd0;
                i_idx <= i_idx + 1;
              end
            end
          end
        end

        SELECT: begin
          // Sequential FSMD for selecting k-multiple-free subset
          if (cur_n == 0) begin
            // nothing to select
          end else begin
            if (!checking) begin
              // Start processing new element at sel_idx
              if (sel_idx < cur_n) begin
                conflict <= 1'b0;
                scan_idx <= 4'd0;
                checking <= 1'b1;
              end
            end else begin
              // checking == 1: scan through all elements to find arr[sel_idx] * k
              if (scan_idx < cur_n) begin
                // Only care if arr[scan_idx] is selected
                if (selected_mask[scan_idx]) begin
                  // Compute product and compare
                  // product width 26 bits is enough for 10b * 16b
                  // But we only need equality check; use full product
                  if ((arr[scan_idx] * k_reg) == arr[sel_idx]) begin
                    conflict <= 1'b1;
                  end
                end
                scan_idx <= scan_idx + 1;
              end else begin
                // scan finished for this sel_idx
                if (!conflict) begin
                  selected_mask[sel_idx] <= 1'b1;
                  selected_count         <= selected_count + 1'b1;
                end
                // move to next element
                sel_idx  <= sel_idx + 1;
                checking <= 1'b0;
              end
            end
          end
        end

        FINISH: begin
          // Latch final result and signal done
          result <= selected_count;
          done   <= 1'b1;
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
      IDLE: begin
        if (start_pulse)
          next_state = LOAD;
      end

      LOAD: begin
        // Move directly to SORT; sort cost negligible in control
        if (cur_n <= 1)
          next_state = SELECT; // no need to sort
        else
          next_state = SORT;
      end

      SORT: begin
        if ((cur_n <= 1) || (i_idx >= (cur_n - 1))) begin
          // Sorting complete
          next_state = SELECT;
        end
      end

      SELECT: begin
        if (cur_n == 0) begin
          next_state = FINISH;
        end else begin
          // When all elements processed: sel_idx == cur_n and not in checking phase
          if ((sel_idx >= cur_n) && (checking == 1'b0)) begin
            next_state = FINISH;
          end
        end
      end

      FINISH: begin
        // Wait for start_pulse to begin new computation
        if (start_pulse)
          next_state = LOAD;
        else
          next_state = FINISH;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule