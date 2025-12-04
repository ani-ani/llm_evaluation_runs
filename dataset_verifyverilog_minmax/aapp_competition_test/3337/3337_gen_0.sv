module stack_operations (
  input  wire        clk,
  input  wire        rst_n,
  input  wire        cmd_valid,
  input  wire  [1:0] op_type,
  input  wire  [3:0] v,
  input  wire  [3:0] w,
  output reg   [4:0] result,
  output reg         result_valid,
  output reg         done
);

  // Storage: 16 stacks, each 16 deep x 4 bits per element
  reg [3:0] stacks [0:15][0:15];
  reg [3:0] tops   [0:15];        // number of valid elements in each stack (0..16)
  reg [3:0] step;                  // current step (1..15), 0 after reset
  integer i, j, k;

  function [15:0] build_presence (input [3:0] sid);
    reg [15:0] pv;
    reg [3:0] val;
    begin
      pv = 16'b0;
      for (j = 0; j < 16; j = j + 1) begin
        if (j < tops[sid]) begin
          val = stacks[sid][j];
          pv[val] = 1'b1;
        end
      end
      build_presence = pv;
    end
  endfunction

  function [3:0] popcount4 (input [15:0] v);
    begin
      case (v)
        16'b0000: popcount4 = 4'd0;
        16'b0001: popcount4 = 4'd1;
        16'b0010: popcount4 = 4'd1;
        16'b0011: popcount4 = 4'd2;
        16'b0100: popcount4 = 4'd1;
        16'b0101: popcount4 = 4'd2;
        16'b0110: popcount4 = 4'd2;
        16'b0111: popcount4 = 4'd3;
        16'b1000: popcount4 = 4'd1;
        16'b1001: popcount4 = 4'd2;
        16'b1010: popcount4 = 4'd2;
        16'b1011: popcount4 = 4'd3;
        16'b1100: popcount4 = 4'd2;
        16'b1101: popcount4 = 4'd3;
        16'b1110: popcount4 = 4'd3;
        default  : popcount4 = 4'd4;
      endcase
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize stack 0 empty, all other stacks arbitrary but valid
      for (i = 0; i < 16; i = i + 1) begin
        tops[i] = 4'd0;
        for (j = 0; j < 16; j = j + 1)
          stacks[i][j] = 4'd0;
      end
      step         <= 4'd0;
      result       <= 5'd0;
      result_valid <= 1'b0;
      done         <= 1'b0;
    end else begin
      // Default pulse for result_valid; it will be overridden below
      result_valid <= 1'b0;
      done         <= 1'b0;

      if (cmd_valid) begin
        // i is the new stack index for this step (1..15)
        i = step;
        if (i == 4'd0) begin
          // Should not happen if reset sequences are followed; ignore if it does
        end else begin
          // Copy stack v to new stack i
          for (k = 0; k < 16; k = k + 1)
            stacks[i][k] <= stacks[v][k];
          tops[i] <= tops[v];

          case (op_type)
            2'b00: begin // 'a' = push step number i onto new stack
              // The new stack has already been copied above (non-blocking)
              // Push i onto it; since each step pushes at most once, tops[i] will never exceed 15
              stacks[i][tops[i]] <= i;  // push value i (4-bit, range 1..15)
              tops[i] <= tops[i] + 1;
            end

            2'b01: begin // 'b' = pop from new stack and output top element
              // Already copied stack v to new stack i; now pop from new stack
              if (tops[i] > 4'd0) begin
                result       <= {1'b0, stacks[i][tops[i]-1]};
                result_valid <= 1'b1;
                tops[i]      <= tops[i] - 1; // pop
                // stacks[i][tops[i]-1] left as-is; content unchanged in mem
              end else begin
                // Underflow safeguard: output 0 if empty
                result       <= 5'd0;
                result_valid <= 1'b1;
              end
            end

            2'b10: begin // 'c' = count distinct common elements with stack w
              // Presence vectors for new stack i and target stack w
              begin
                reg [15:0] pv_new, pv_w, common;
                pv_new = build_presence(i);
                pv_w   = build_presence(w);
                common = pv_new & pv_w;
                result       <= {1'b0, popcount4(common)};
                result_valid <= 1'b1;
                // No modifications to stacks for 'c'
              end
            end

            default: begin
              // No-op for reserved op_type; preserve state
            end
          endcase

          // Advance step; assert done after step 15 completes
          if (step < 4'd15) begin
            step <= step + 1;
          end else begin
            step <= 4'd0; // wrap back to 0 or hold at 15; choose wrap for next session
            done <= 1'b1;
          end
        end
      end else begin
        // No command this cycle; keep state stable
      end
    end
  end

endmodule
