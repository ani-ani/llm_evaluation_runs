module sum_non_repeated(
  input clk,
  input rst_n,
  input start,
  input [7:0] data [0:15],
  input [3:0] length,
  output [15:0] sum,
  output done
);

  // Frequency table: 256 entries, 8-bit counters
  reg [7:0] freq [0:255];
  // FSM state
  reg [4:0] state, next_state;
  // Keep track of which elements to process
  reg [3:0] length_latched;
  // Current element index (0..15)
  reg [3:0] idx;
  // Pipelined frequencies for read-after-write timing
  reg [7:0] freq_q1, freq_q2;

  localparam IDLE   = 5'b00001;
  localparam COUNT0 = 5'b00010;
  localparam COUNT1 = 5'b00100;
  localparam COUNT2 = 5'b01000;
  localparam SUM    = 5'b10000;

  // Reset (active low)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      sum   <= 16'h0;
      length_latched <= 4'd0;
      idx   <= 4'd0;
      freq_q1 <= 8'd0;
      freq_q2 <= 8'd0;
    end else begin
      // Defaults to avoid latches
      done <= 1'b0;
      sum  <= 16'h0;
      freq_q1 <= 8'd0;
      freq_q2 <= 8'd0;

      // FSM combinatorial control (outputs driven here)
      case (state)
        IDLE: begin
          sum <= 16'h0;
          if (start) begin
            length_latched <= length;
            idx <= 4'd0;
            state <= COUNT0;
          end else begin
            state <= IDLE;
          end
        end

        // COUNT0: sample current element, increment freq[data]
        COUNT0: begin
          sum <= 16'h0;
          idx <= idx;
          if (idx < 4'd15) begin
            state <= COUNT1;
          end else begin
            state <= COUNT1;
          end
          if (idx < length_latched) begin
            freq[data[idx]] <= freq[data[idx]] + 1'b1;
            freq_q1 <= freq[data[idx]]; // current value (before increment)
          end else begin
            freq_q1 <= freq[data[idx]]; // still read for consistency
          end
        end

        // COUNT1: advance index; hold freq from previous stage
        COUNT1: begin
          sum <= 16'h0;
          if (idx < 4'd15) begin
            idx <= idx + 1'b1;
          end else begin
            idx <= idx;
          end
          freq_q2 <= freq_q1;
          if (idx < 4'd15) begin
            state <= COUNT2;
          end else begin
            state <= SUM; // after last element, go to summation
          end
        end

        // COUNT2: ensure 1-cycle per element; pipeline tail
        COUNT2: begin
          sum <= 16'h0;
          freq_q2 <= freq_q1;
          state <= (idx < 4'd15) ? COUNT0 : SUM;
        end

        // SUM: sum elements with count == 1 using pipelined freq_q2
        SUM: begin
          if (idx < 4'd15) begin
            idx <= idx + 1'b1;
            // Add current element if it was unique (freq_q2 == 1)
            if (freq_q2 == 8'd1) begin
              sum <= sum + {8'd0, data[idx]};
            end else begin
              sum <= sum;
            end
            state <= SUM;
          end else begin
            // Final element (index 15) on last cycle of SUM
            if (freq_q2 == 8'd1) begin
              sum <= sum + {8'd0, data[4'd15]};
            end else begin
              sum <= sum;
            end
            done <= 1'b1;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
