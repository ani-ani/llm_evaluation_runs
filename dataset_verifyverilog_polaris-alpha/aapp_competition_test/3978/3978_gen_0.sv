module color_minimizer(
  input clk,
  input rst_n,
  input start,
  input [63:0] data_in,
  output reg [3:0] color_count,
  output reg done
);

  // Internal registers
  reg [7:0] arr [0:7];
  reg painted [0:7];

  reg [5:0] cycle_cnt;        // counts cycles after start (0-39)
  reg       started;          // latched start indicator
  reg [2:0] i_idx;            // index for loops
  reg [2:0] j_idx;            // index for loops

  // Control states for processing phases
  localparam PHASE_IDLE   = 2'd0;
  localparam PHASE_SORT   = 2'd1;
  localparam PHASE_COLOR  = 2'd2;
  localparam PHASE_DONE   = 2'd3;

  reg [1:0] phase;

  // Bubble sort swap temp
  reg [7:0] tmp;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      color_count <= 4'd0;
      done        <= 1'b0;
      cycle_cnt   <= 6'd0;
      started     <= 1'b0;
      phase       <= PHASE_IDLE;
      i_idx       <= 3'd0;
      j_idx       <= 3'd0;
    end else begin
      // Default done deassert behavior when start is low
      if (!start) begin
        done <= 1'b0;
      end

      case (phase)
        PHASE_IDLE: begin
          color_count <= 4'd0;
          cycle_cnt   <= 6'd0;
          i_idx       <= 3'd0;
          j_idx       <= 3'd0;
          started     <= 1'b0;

          if (start) begin
            // Latch inputs into working array
            arr[0] <= data_in[63:56];
            arr[1] <= data_in[55:48];
            arr[2] <= data_in[47:40];
            arr[3] <= data_in[39:32];
            arr[4] <= data_in[31:24];
            arr[5] <= data_in[23:16];
            arr[6] <= data_in[15:8];
            arr[7] <= data_in[7:0];

            // Clear painted flags
            painted[0] <= 1'b0;
            painted[1] <= 1'b0;
            painted[2] <= 1'b0;
            painted[3] <= 1'b0;
            painted[4] <= 1'b0;
            painted[5] <= 1'b0;
            painted[6] <= 1'b0;
            painted[7] <= 1'b0;

            started   <= 1'b1;
            phase     <= PHASE_SORT;
            cycle_cnt <= 6'd0;
            i_idx     <= 3'd0;
            j_idx     <= 3'd0;
          end
        end

        PHASE_SORT: begin
          // Perform bubble sort over 28 cycles (unrolled by one compare per cycle)
          // Use (i_idx, j_idx) as standard nested-loop indices
          if (cycle_cnt < 6'd28) begin
            // Compare and swap arr[j_idx] and arr[j_idx+1]
            if (arr[j_idx] > arr[j_idx + 1]) begin
              tmp              <= arr[j_idx];
              arr[j_idx]       <= arr[j_idx + 1];
              arr[j_idx + 1]   <= tmp;
            end

            // Advance j and i indices as in bubble sort
            if (j_idx < (3'd6 - i_idx)) begin
              j_idx <= j_idx + 3'd1;
            end else begin
              j_idx <= 3'd0;
              i_idx <= i_idx + 3'd1;
            end

            cycle_cnt <= cycle_cnt + 6'd1;
          end else begin
            // Sorting complete, move to coloring phase
            phase       <= PHASE_COLOR;
            cycle_cnt   <= 6'd28; // already at 28
            i_idx       <= 3'd0;
            j_idx       <= 3'd0;
            color_count <= 4'd0;

            // Ensure painted flags cleared before coloring
            painted[0] <= 1'b0;
            painted[1] <= 1'b0;
            painted[2] <= 1'b0;
            painted[3] <= 1'b0;
            painted[4] <= 1'b0;
            painted[5] <= 1'b0;
            painted[6] <= 1'b0;
            painted[7] <= 1'b0;
          end
        end

        PHASE_COLOR: begin
          // From cycle 28 up to 39, perform coloring operations
          if (cycle_cnt < 6'd40) begin
            // Each cycle processes one step in the coloring algorithm

            // If current index within range
            if (i_idx < 3'd8) begin
              // If element not painted, start a new color and mark multiples
              if (!painted[i_idx]) begin
                color_count <= color_count + 4'd1;

                // Mark current element as painted
                painted[i_idx] <= 1'b1;

                // Mark all subsequent divisible elements (simple per-cycle marking)
                // Use j_idx to traverse; restart when new color chosen
                if (j_idx == 3'd0) begin
                  j_idx <= i_idx + 3'd1;
                end else begin
                  // Check divisibility for current j_idx, if in range
                  if (j_idx < 3'd8) begin
                    if (!painted[j_idx]) begin
                      if (arr[j_idx] != 8'd0 && arr[i_idx] != 8'd0) begin
                        if ((arr[j_idx] % arr[i_idx]) == 8'd0) begin
                          painted[j_idx] <= 1'b1;
                        end
                      end
                    end
                    j_idx <= j_idx + 3'd1;
                  end
                end

                // When j_idx reaches end, move to next i_idx
                if (j_idx >= 3'd7) begin
                  i_idx <= i_idx + 3'd1;
                  j_idx <= 3'd0;
                end

              end else begin
                // If already painted, just move to next element
                i_idx <= i_idx + 3'd1;
                j_idx <= 3'd0;
              end
            end

            cycle_cnt <= cycle_cnt + 6'd1;
          end else begin
            // Reached 40th cycle, finish
            phase <= PHASE_DONE;
          end
        end

        PHASE_DONE: begin
          done <= 1'b1;
          // Wait for start to be deasserted, then go idle
          if (!start) begin
            phase       <= PHASE_IDLE;
            started     <= 1'b0;
            color_count <= color_count;
          end
        end

        default: begin
          phase <= PHASE_IDLE;
        end
      endcase
    end
  end

endmodule
