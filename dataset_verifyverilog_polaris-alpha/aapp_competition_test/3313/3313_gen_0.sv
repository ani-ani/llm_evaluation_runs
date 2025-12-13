module gem_collector(
  input clk, // 100MHz clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] gem_count, // number of gems (1-8)
  input [3:0] r, // velocity ratio (1-10)
  input [7:0] w, // track width (0-255) -- unused in core algorithm
  input [7:0] h, // finish height (0-255) -- unused in core algorithm
  input [7:0] gem_x [0:7], // gem x coordinates (0-255)
  input [7:0] gem_y [0:7], // gem y coordinates (1-255)
  output reg [3:0] max_gems, // maximum collectable gems (0-8)
  output reg done // high when computation complete
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    SORTING     = 2'b01,
    CALCULATING = 2'b10,
    DONE_STATE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal storage for sorted gems
  reg [7:0] sx [0:7];
  reg [7:0] sy [0:7];

  // DP array: best chain ending at each gem
  reg [3:0] dp [0:7];

  // Indices and counters
  reg [3:0] i_idx; // up to 8
  reg [3:0] j_idx; // up to 8
  reg [3:0] sort_pass; // bubble sort passes (0..gem_count-1)

  // Latched inputs
  reg [3:0] gem_count_r;
  reg [3:0] r_r;

  // Intermediates for comparison
  reg [15:0] dx_abs;
  reg [15:0] dy;
  reg [15:0] dx_scaled; // |dx| * r

  // Helper wires
  wire [3:0] gc_eff = (gem_count_r == 0) ? 4'd0 : gem_count_r;

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_gems   <= 4'd0;
      done       <= 1'b0;
      gem_count_r <= 4'd0;
      r_r         <= 4'd0;
      i_idx      <= 4'd0;
      j_idx      <= 4'd0;
      sort_pass  <= 4'd0;
      for (k = 0; k < 8; k = k + 1) begin
        sx[k] <= 8'd0;
        sy[k] <= 8'd0;
        dp[k] <= 4'd0;
      end
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Latch inputs
            gem_count_r <= (gem_count > 4'd8) ? 4'd8 : gem_count;
            r_r         <= (r == 4'd0) ? 4'd1 : r; // protect divide-by-zero

            // Initialize internal arrays from inputs (only first gem_count entries are valid)
            for (k = 0; k < 8; k = k + 1) begin
              sx[k] <= gem_x[k];
              sy[k] <= gem_y[k];
              dp[k] <= 4'd0;
            end

            i_idx     <= 4'd0;
            j_idx     <= 4'd0;
            sort_pass <= 4'd0;
          end
        end

        SORTING: begin
          // Bubble sort by ascending sy, operating 1 compare-swap per cycle
          if (gc_eff <= 4'd1) begin
            // Nothing to sort
          end else begin
            // Compare indices j_idx and j_idx+1 for current pass
            if (j_idx + 1 < gc_eff) begin
              if (sy[j_idx] > sy[j_idx + 1]) begin
                // swap
                reg [7:0] tmpx;
                reg [7:0] tmpy;
                tmpx = sx[j_idx];
                tmpy = sy[j_idx];
                sx[j_idx] <= sx[j_idx + 1];
                sy[j_idx] <= sy[j_idx + 1];
                sx[j_idx + 1] <= tmpx;
                sy[j_idx + 1] <= tmpy;
              end

              // Advance inner index
              j_idx <= j_idx + 1'b1;
            end else begin
              // End of inner loop for this pass
              j_idx <= 4'd0;
              if (sort_pass + 1 < gc_eff)
                sort_pass <= sort_pass + 1'b1;
            end
          end
        end

        CALCULATING: begin
          if (gc_eff == 4'd0) begin
            max_gems <= 4'd0;
          end else begin
            // DP computation over sorted gems
            // Each gem i: dp[i] = max chain ending at i
            // Process one (i,j) pair per cycle

            // Initialization of dp when starting with new i
            if (i_idx < gc_eff) begin
              if (j_idx == 4'd0) begin
                // Initialize dp[i] to 1 when first visiting this i
                dp[i_idx] <= 4'd1;
                // Also track global max
                if (max_gems < 4'd1)
                  max_gems <= 4'd1;

                // Move to first previous index next cycle if any
                if (i_idx > 0)
                  j_idx <= 4'd0;
                else begin
                  // For i=0, no predecessors; move to next i
                  j_idx <= 4'd0;
                  i_idx <= i_idx + 1'b1;
                end
              end else begin
                // Should not occur with this control scheme
                j_idx <= j_idx;
              end
            end

            // If i_idx within range and i_idx > 0, perform predecessor checks
            if (i_idx < gc_eff && i_idx > 0) begin
              if (j_idx < i_idx) begin
                // Compute condition: |x_i - x_j| <= (y_i - y_j)/r
                if (sx[i_idx] >= sx[j_idx])
                  dx_abs = sx[i_idx] - sx[j_idx];
                else
                  dx_abs = sx[j_idx] - sx[i_idx];

                dy       = sy[i_idx] - sy[j_idx];
                dx_scaled = dx_abs * r_r; // 16-bit intermediate

                if (dx_scaled <= dy) begin
                  // Feasible to go from j to i
                  if (dp[j_idx] + 4'd1 > dp[i_idx]) begin
                    dp[i_idx] <= dp[j_idx] + 4'd1;
                    if (max_gems < dp[j_idx] + 4'd1)
                      max_gems <= dp[j_idx] + 4'd1;
                  end
                end

                j_idx <= j_idx + 1'b1;
              end else begin
                // Finished all j for this i; move to next i
                j_idx <= 4'd0;
                i_idx <= i_idx + 1'b1;
              end
            end
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SORTING;
      end

      SORTING: begin
        if (gc_eff <= 4'd1) begin
          next_state = CALCULATING;
        end else if (sort_pass + 1 >= gc_eff && j_idx + 1 >= gc_eff) begin
          // All passes complete
          next_state = CALCULATING;
        end else begin
          next_state = SORTING;
        end
      end

      CALCULATING: begin
        if (gc_eff == 4'd0) begin
          next_state = DONE_STATE;
        end else if (i_idx >= gc_eff) begin
          next_state = DONE_STATE;
        end else begin
          next_state = CALCULATING;
        end
      end

      DONE_STATE: begin
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE_STATE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule