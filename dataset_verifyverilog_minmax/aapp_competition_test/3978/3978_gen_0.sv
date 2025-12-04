module color_minimizer(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start signal
  input [63:0] data_in, // packed 8x8-bit input elements
  output reg [3:0] color_count, // result (range 1-8)
  output reg done // high when calculation complete
);

  // Internal signals
  reg [2:0] state, next_state;
  reg [2:0] phase;        // index of the current element being evaluated/loaded
n  reg [4:0] sort_step;   // 0..27 bubble-sort steps (28 total)
  reg [7:0] elem [0:7];   // working array of 8 elements
  reg painted [0:7];      // marks whether an element is already covered
  reg [2:0] ci;           // helper index to scan subsequent elements
  reg [3:0] count;        // running color counter
  reg [2:0] step_count;   // tracks scan progress during processing
  reg [2:0] out_stage;    // 1-cycle staging before asserting done

  // State encoding
  localparam S_IDLE     = 3'b000;
  localparam S_LOAD     = 3'b001;
  localparam S_SORT     = 3'b010;
  localparam S_PROCESS  = 3'b011;
  localparam S_DONE     = 3'b100;

  // Sequential logic with active-low reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      next_state <= S_IDLE;
      done       <= 1'b0;
      out_stage  <= 3'b0;
      color_count <= 4'b0;
      count      <= 4'b0;
      phase      <= 3'b0;
      sort_step  <= 5'b0;
      step_count <= 3'b0;
      ci         <= 3'b0;
      // Clear arrays
      for (integer k = 0; k < 8; k = k + 1) begin
        elem[k]    <= 8'b0;
        painted[k] <= 1'b0;
      end
    end else begin
      // State machine and control signals update
      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          out_stage  <= 3'b0;
          color_count <= 4'b0;
          count      <= 4'b0;
          phase      <= 3'b0;
          sort_step  <= 5'b0;
          step_count <= 3'b0;
          ci         <= 3'b0;
          for (integer k = 0; k < 8; k = k + 1) begin
            elem[k]    <= 8'b0;
            painted[k] <= 1'b0;
          end
          next_state <= S_IDLE;
          if (start) begin
            state      <= S_LOAD;
            next_state <= S_LOAD;
          end else begin
            state      <= S_IDLE;
          end
        end

        S_LOAD: begin
          // Extract 8 elements from packed data_in
          elem[0] <= data_in[7:0];
          elem[1] <= data_in[15:8];
          elem[2] <= data_in[23:16];
          elem[3] <= data_in[31:24];
          elem[4] <= data_in[39:32];
          elem[5] <= data_in[47:40];
          elem[6] <= data_in[55:48];
          elem[7] <= data_in[63:56];
          state      <= S_SORT;
          next_state <= S_SORT;
        end

        S_SORT: begin
          // Bubble sort (28 worst-case steps):
          // phase: 0..6; step: 0..3 within each phase
          case (sort_step)
            5'd0, 5'd1, 5'd2, 5'd3: begin ci <= 3'd3 - sort_step[1:0]; end
            5'd4, 5'd5, 5'd6, 5'd7: begin ci <= 3'd4 - (sort_step[1:0]); end
            5'd8, 5'd9, 5'd10, 5'd11: begin ci <= 3'd5 - (sort_step[1:0]); end
            5'd12, 5'd13, 5'd14, 5'd15: begin ci <= 3'd6 - (sort_step[1:0]); end
            5'd16, 5'd17, 5'd18, 5'd19: begin ci <= 3'd7 - (sort_step[1:0]); end
            5'd20, 5'd21, 5'd22, 5'd23: begin ci <= 3'd7 - (sort_step[1:0]); end
            5'd24, 5'd25, 5'd26, 5'd27: begin ci <= 3'd7 - (sort_step[1:0]); end
            default: ci <= 3'd0;
          endcase

          // Perform swap on the selected pair
          if (elem[ci - 1] > elem[ci]) begin
            elem[ci - 1] <= elem[ci];
            elem[ci]     <= elem[ci - 1];
          end

          // Advance sort step
          if (sort_step < 5'd27) begin
            sort_step <= sort_step + 1;
            state     <= S_SORT;
          end else begin
            sort_step <= 5'b0;
            // Initialize processing registers
            count   <= 4'b0;
            ci      <= 3'd0;
            // Clear painted flags for fresh processing
            for (integer k = 0; k < 8; k = k + 1) begin
              painted[k] <= 1'b0;
            end
            state <= S_PROCESS;
          end
        end

        S_PROCESS: begin
          // Main algorithm: for each i (0..7), if not painted, increment count and mark all j>i divisible by elem[i]
          // We'll break into two sub-steps per i for a balanced pipeline and fit within ~12 cycles total
          // ci holds the current i
          if (ci <= 3'd7) begin
            if (!painted[ci]) begin
              // Step 1: evaluate current i, possibly bump count
              // count increment done here (only when first encounter for a group)
              if (!painted[ci]) begin
                // color chosen
                count <= count + 1;
              end
              // Step 2: mark subsequent elements divisible by current value
              ci <= ci + 1;
              state <= S_PROCESS_CHECK;
            end else begin
              // Already painted, move to next
              ci <= ci + 1;
              state <= S_PROCESS;
            end
          end else begin
            // Done scanning all indices
            state <= S_DONE;
          end
        end

        // Sub-state to complete the marking phase for the current i
        S_PROCESS_CHECK: begin
          // ci was incremented to point to the element to check (j)
          if (ci <= 3'd7) begin
            if (elem[ci] == 0) begin
              // Special case: zero is divisible by any non-zero; avoid 0 marking all others
              // Do not mark 0 as painted by zero values
            end else begin
              // Check divisibility: if elem[ci] % elem[current_i] == 0
              if (elem[ci] % elem[ci - 1] == 0) begin
                painted[ci] <= 1'b1;
              end
            end
            ci <= ci + 1;
            state <= S_PROCESS_CHECK; // continue scanning remaining j's
          end else begin
            // Finished scanning all j for current i
            // Move to next i
            ci <= ci + 1; // now ci = old_ci + 1 already; but we want to continue from next i (ci already > 7)
            // Wrap-around safety: when ci was incremented from 7 to 8, loop will exit next cycle
            state <= S_PROCESS;
          end
        end

        S_DONE: begin
          // Capture the result
          color_count <= count;
          // Raise done for 1 cycle, then lower it when start is de-asserted
          done <= 1'b1;
          if (!start) begin
            done <= 1'b0;
            state <= S_IDLE;
            next_state <= S_IDLE;
          end else begin
            state <= S_DONE;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
