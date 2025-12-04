module max_table_perimeter(
  input clk,
  input rst_n,
  input start,
  input [63:0] grid_flat,  // Flattened grid (row-major: grid_flat[7:0]=row0, 0=free, 1=blocked
  output reg [5:0] max_perimeter,
  output reg done
);

  // State encoding
  localparam IDLE        = 2'b00;
  localparam CALCULATING = 2'b01;
  localparam DONE        = 2'b10;

  reg [1:0] state, next_state;

  // Loop indices: i (top row), k (bottom row), j (left col), l (right col)
  reg [2:0] i, k, j, l;

  // Rectangle checking control
  reg [5:0] cell_idx;        // up to 63
  reg checking;              // 1 when scanning cells of current rectangle
  reg rect_valid;            // 1 if current rectangle remains valid
  reg rect_done;             // 1 when finished scanning current rectangle

  // Perimeter registers
  reg [3:0] height;          // up to 8
  reg [3:0] width;           // up to 8
  reg [5:0] perimeter;       // up to 31 (fits in 6 bits)

  // Combinational next-state for FSM
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALCULATING;
      end
      CALCULATING: begin
        // Transition to DONE once the final rectangle has been processed
        if (rect_done && (i == 3'd7) && (k == 3'd7) && (j == 3'd7) && (l == 3'd7)) begin
          next_state = DONE;
        end
      end
      DONE: begin
        // Single-cycle done pulse, then go back to IDLE
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      max_perimeter <= 6'd0;
      done          <= 1'b0;
      i             <= 3'd0;
      k             <= 3'd0;
      j             <= 3'd0;
      l             <= 3'd0;
      cell_idx      <= 6'd0;
      checking      <= 1'b0;
      rect_valid    <= 1'b0;
      rect_done     <= 1'b0;
      height        <= 4'd0;
      width         <= 4'd0;
      perimeter     <= 6'd0;
    end else begin
      state <= next_state;

      // Default registered outputs each cycle
      done      <= 1'b0;
      rect_done <= 1'b0;

      case (state)
        IDLE: begin
          max_perimeter <= 6'd0;
          done          <= 1'b0;

          if (start) begin
            // Initialize loop indices to first rectangle (0,0)-(0,0)
            i          <= 3'd0;
            k          <= 3'd0;
            j          <= 3'd0;
            l          <= 3'd0;

            // Start checking first rectangle
            checking   <= 1'b1;
            rect_valid <= 1'b1;
            cell_idx   <= 6'd0;
          end else begin
            checking   <= 1'b0;
            rect_valid <= 1'b0;
            cell_idx   <= 6'd0;
          end
        end

        CALCULATING: begin
          if (checking) begin
            // Map cell_idx to (r, c) within current rectangle
            // Using iterative increment: we interpret cell_idx as linear index
            // r = i + (cell_idx / width)
            // c = j + (cell_idx % width)
            // We'll compute width and use it to control traversal.

            // First cycle after (re)starting checking, compute width/height
            if (cell_idx == 6'd0) begin
              height <= (k - i) + 4'd1;
              width  <= (l - j) + 4'd1;
            end

            // Use temporary row/col via counters derived from cell_idx and width
            // Implement row/col traversal incrementally
            // We'll maintain internal row/col counters via cell_idx math each cycle.
            // Note: All signals registered only; combinational uses grid_flat directly.

            // Compute linearized absolute index for current cell
            // r = i + (cell_idx / width)
            // c = j + (cell_idx % width)
            // For synthesis-friendliness (small search space), use division/mod.
            // These are combinational from registered signals (allowed).

          end

          // Combinational-like helpers (must be derived only from regs)
          // We'll define them as automatic regs via a separate block (not allowed),
          // so instead compute inside CALCULATING using temporary variables.

          begin : rect_scan
            integer div_res;
            integer mod_res;
            reg [2:0] r;
            reg [2:0] c;
            if (checking) begin
              if (width != 0) begin
                div_res = cell_idx / width;
                mod_res = cell_idx % width;
              end else begin
                div_res = 0;
                mod_res = 0;
              end
              r = i + div_res[2:0];
              c = j + mod_res[2:0];

              // Bounds safety (should naturally hold for valid rectangles)
              if (r > k || c > l || r > 3'd7 || c > 3'd7) begin
                // If bounds wrong, terminate this rectangle as invalid
                rect_valid <= 1'b0;
                checking   <= 1'b0;
                rect_done  <= 1'b1;
              end else begin
                // Check cell: 0 = free, 1 = blocked
                if (grid_flat[{r,3'b000} + c] == 1'b1) begin
                  rect_valid <= 1'b0;
                end

                // Move to next cell
                if (cell_idx + 6'd1 >= (height * width)) begin
                  // Finished scanning this rectangle
                  checking  <= 1'b0;
                  rect_done <= 1'b1;

                  // If valid, compute perimeter and update max
                  if (rect_valid) begin
                    perimeter <= (height + width) << 1; // 2*(h+w)
                    // Adjust to required: 2*((k-i+1)+(l-j+1)) - 1
                    // by subtracting 1
                    if (((height + width) << 1) > 0)
                      perimeter <= (((height + width) << 1) - 6'd1);
                    else
                      perimeter <= 6'd0;

                    if ((((height + width) << 1) > 0 ? (((height + width) << 1) - 6'd1) : 6'd0) > max_perimeter) begin
                      max_perimeter <= (((height + width) << 1) - 6'd1);
                    end
                  end
                end else begin
                  // Continue scanning
                  cell_idx <= cell_idx + 6'd1;
                end
              end
            end
          end

          // When current rectangle done, advance to next rectangle indices
          if (rect_done && !checking) begin
            // Generate next (i,j,k,l)
            if (l < 3'd7) begin
              l        <= l + 3'd1;
            end else begin
              l <= 3'd0;
              if (j < 3'd7) begin
                j <= j + 3'd1;
              end else begin
                j <= 3'd0;
                if (k < 3'd7) begin
                  k <= k + 3'd1;
                end else begin
                  k <= 3'd0;
                  if (i < 3'd7) begin
                    i <= i + 3'd1;
                  end else begin
                    // All rectangles done; FSM will move to DONE via next_state
                    i <= i; // hold
                  end
                end
              end
            end

            // Start checking next rectangle if not finished all
            if (!((i == 3'd7) && (k == 3'd7) && (j == 3'd7) && (l == 3'd7))) begin
              checking   <= 1'b1;
              rect_valid <= 1'b1;
              cell_idx   <= 6'd0;
            end
          end
        end

        DONE: begin
          // One-cycle done pulse with stable max_perimeter
          done <= 1'b1;

          // Prepare for IDLE next
          checking   <= 1'b0;
          rect_valid <= 1'b0;
          rect_done  <= 1'b0;
          cell_idx   <= 6'd0;
        end

        default: begin
          // Safety defaults
          state         <= IDLE;
          max_perimeter <= 6'd0;
          done          <= 1'b0;
          checking      <= 1'b0;
          rect_valid    <= 1'b0;
          rect_done     <= 1'b0;
          cell_idx      <= 6'd0;
        end
      endcase
    end
  end

endmodule