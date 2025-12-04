module zebra_partition (
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start processing
  input [15:0] s, // input binary string (MSB first)
  input [3:0] str_len, // actual string length (1-16)
  output reg done, // high when computation complete
  output reg valid, // high if partition exists
  output reg [3:0] k, // number of subsequences
  output reg [63:0] indices // packed indices (4 subsequences x 16 bits)
);

  // Internal signals
  reg [1:0] state;
  reg [4:0] pos; // 0..15
  reg [3:0] sub_cnt; // 0..4
  reg [15:0] idx0, idx1, idx2, idx3; // 16-bit masks per subsequence
  reg closed0, closed1, closed2, closed3; // 1 -> subsequence ended with 0 (valid to append 1)
  reg has_one_end0, has_one_end1, has_one_end2, has_one_end3; // 1 -> has at least one 1 appended
  reg error;
  reg [3:0] next_idx;
  reg [3:0] i;

  localparam IDLE = 2'b00;
  localparam RUN  = 2'b01;
  localparam DONE = 2'b10;

  // State + control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize
            pos     <= 5'd0;
            sub_cnt <= 4'd0;
            idx0    <= 16'd0;
            idx1    <= 16'd0;
            idx2    <= 16'd0;
            idx3    <= 16'd0;
            closed0 <= 1'b0;
            closed1 <= 1'b0;
            closed2 <= 1'b0;
            closed3 <= 1'b0;
            has_one_end0 <= 1'b0;
            has_one_end1 <= 1'b0;
            has_one_end2 <= 1'b0;
            has_one_end3 <= 1'b0;
            done    <= 1'b0;
            valid   <= 1'b0;
            k       <= 4'd0;
            indices <= 64'd0;
            error   <= 1'b0;
            state   <= RUN;
          end else begin
            state <= IDLE;
          end
        end
        RUN: begin
          if (error) begin
            done  <= 1'b1;
            valid <= 1'b0;
            k     <= sub_cnt;
            // Keep indices as-is; they are not valid in error case
            state <= DONE;
          end else begin
            if (pos == ({1'b0, str_len} - 1)) begin
              // Last bit processed; validate and finish
              done  <= 1'b1;
              // Valid if no subsequence ends with 1 (i.e., all '1' subsequences were closed by a trailing 0)
              valid <= ~(has_one_end0 || has_one_end1 || has_one_end2 || has_one_end3);
              k     <= sub_cnt;
              // Pack indices: idx0 -> [63:48], idx1 -> [47:32], idx2 -> [31:16], idx3 -> [15:0]
              indices <= {idx0, idx1, idx2, idx3};
              state   <= DONE;
            end else begin
              // Continue processing next bit next cycle
              pos <= pos + 1;
            end
          end
        end
        DONE: begin
          // Wait for start to deassert and go back to IDLE
          done <= 1'b0;
          if (!start) begin
            state <= IDLE;
          end else begin
            state <= DONE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

  // Bit-by-bit processing in RUN state
  always @(posedge clk) begin
    if (state == RUN && !error) begin
      if (pos < str_len) begin
        if (s[pos] == 1'b0) begin
          // Append 0 to an existing 1-ended subsequence, or open a new subsequence
          if (has_one_end0) begin
            closed0 <= 1'b1;
          end else if (has_one_end1) begin
            closed1 <= 1'b1;
          end else if (has_one_end2) begin
            closed2 <= 1'b1;
          end else if (has_one_end3) begin
            closed3 <= 1'b1;
          end else begin
            // No existing 1-ended subsequence; create a new one (0 -> ends with 0)
            if (sub_cnt < 4) begin
              case (sub_cnt)
                4'd0: begin idx0[0] <= 1'b1; closed0 <= 1'b1; end
                4'd1: begin idx1[0] <= 1'b1; closed1 <= 1'b1; end
                4'd2: begin idx2[0] <= 1'b1; closed2 <= 1'b1; end
                4'd3: begin idx3[0] <= 1'b1; closed3 <= 1'b1; end
                default: ;
              endcase
              sub_cnt <= sub_cnt + 1;
            end else begin
              // Should be unreachable due to earlier check
              error <= 1'b1;
            end
          end
        end else begin // s[pos] == 1
          // Append 1 to the oldest 0-ended subsequence
          if (closed0 && !has_one_end0) begin
            // Use subsequence 0
            next_idx <= 4'd0;
          end else if (closed1 && !has_one_end1) begin
            next_idx <= 4'd1;
          end else if (closed2 && !has_one_end2) begin
            next_idx <= 4'd2;
          else if (closed3 && !has_one_end3) begin
            next_idx <= 4'd3;
          end else begin
            error <= 1'b1; // No 0-ended subsequence available
            next_idx <= 4'dx; // don't-care
          end

          if (!error) begin
            case (next_idx)
              4'd0: begin idx0[pos] <= 1'b1; has_one_end0 <= 1'b1; end
              4'd1: begin idx1[pos] <= 1'b1; has_one_end1 <= 1'b1; end
              4'd2: begin idx2[pos] <= 1'b1; has_one_end2 <= 1'b1; end
              4'd3: begin idx3[pos] <= 1'b1; has_one_end3 <= 1'b1; end
              default: ;
            endcase
          end
        end
      end
    end
  end

  // Boundary checks and early termination on invalid inputs
  always @(posedge clk) begin
    if (state == IDLE && start) begin
      if (str_len == 4'd0 || str_len > 4'd16) begin
        error <= 1'b1;
      end else begin
        error <= 1'b0;
      end
    end else if (state == RUN && !error) begin
      // Enforce maximum of 4 subsequences
      if (sub_cnt > 4) begin
        error <= 1'b1;
      end
    end
  end

endmodule
