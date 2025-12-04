module digit_sum (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] numbers [7:0],
  output reg [6:0] total_sum,
  output reg done
);

  // State machine states
  typedef enum logic [1:0] { S_IDLE = 2'd0, S_WORK = 2'd1, S_DONE = 2'd2 } state_t;
  state_t state, next_state;

  // Control and datapath registers
  reg [2:0] num_idx;     // which number (0..7) we are processing
  reg [1:0] phase;       // 0=load/abs, 1=extract d0, 2=extract d1, 3=extract d2
  reg [8:0] work;        // unsigned working value (9-bit to handle abs(-128))
  reg [6:0] sum;         // 7-bit accumulator (clamped at 127)
  reg sum_clamp;

  // Next-state logic for FSM
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: next_state = start ? S_WORK : S_IDLE;
      S_WORK: next_state = (num_idx == 3'd7 && phase == 2'd3) ? S_DONE : S_WORK;
      S_DONE: next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      num_idx  <= 3'd0;
      phase    <= 2'd0;
      work     <= 9'd0;
      sum      <= 7'd0;
      sum_clamp<= 1'b0;
      done     <= 1'b0;
      total_sum<= 7'd0;
    end else begin
      case (next_state)
        S_IDLE: begin
          num_idx  <= 3'd0;
          phase    <= 2'd0;
          work     <= 9'd0;
          sum      <= 7'd0;
          sum_clamp<= 1'b0;
          done     <= 1'b0;
          total_sum<= 7'd0;
        end

        S_WORK: begin
          // Default: advance phase/num_idx each cycle
          if (phase == 2'd3) begin
            phase   <= 2'd0;
            num_idx <= num_idx + 1'b1;
          end else begin
            phase   <= phase + 1'b1;
          end

          // Current-phase operations
          if (phase == 2'd0) begin
            // Load and take absolute value (unsigned) of numbers[num_idx]
            work <= (numbers[num_idx] < 0) ? (9'd128) : (9'd(unsigned'(numbers[num_idx])));
          end else if (phase == 2'd1) begin
            // Add ones digit (0..9), keep working value for next extraction
            work <= work / 10;
          end else if (phase == 2'd2) begin
            // Add tens digit (0..9), keep working value for next extraction
            work <= work / 10;
          end else begin // phase == 2'd3
            // Add hundreds digit (0..1), done with this number
            work <= work / 10;
          end

          // Accumulate sum (clamped at 127 to keep total_sum in 7 bits)
          if (phase == 2'd0) begin
            sum      <= sum;  // no add on load/abs cycle
            sum_clamp<= 1'b0;
          end else begin
            if (!sum_clamp) begin
              if (sum + {6'd0, (work % 10)} >= 7'd128) begin
                sum       <= 7'd127;
                sum_clamp <= 1'b1;
              end else begin
                sum       <= sum + {6'd0, (work % 10)};
                sum_clamp <= sum_clamp;
              end
            end else begin
              sum       <= 7'd127; // stay clamped
            end
          end

          done     <= 1'b0;
          total_sum<= total_sum; // keep previous until DONE
        end

        S_DONE: begin
          done     <= 1'b1;
          total_sum<= sum;
          // Hold steady until returning to IDLE
        end

        default: begin
          done     <= 1'b0;
          total_sum<= 7'd0;
        end
      endcase

      state <= next_state;
    end
  end

endmodule
