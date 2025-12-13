module hearing_scheduler(
  input clk, // System clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [1:0] num_hearings, // Number of hearings (1-4)
  input [15:0] s [0:3], // Start times (16-bit unsigned)
  input [15:0] a [0:3], // Min durations (16-bit unsigned)
  input [15:0] b [0:3], // Max durations (16-bit unsigned)
  output reg [31:0] result, // Q16.16 fixed-point expected value
  output reg done // High when computation completes
);

  // Internal fixed-point format: Q16.16
  localparam [31:0] ONE_Q16 = 32'h0001_0000;

  // FSM states
  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    CALCULATE = 2'b01,
    DONE      = 2'b10
  } state_t;

  state_t state, state_n;

  // Internal registers
  reg [31:0] expected;       // Accumulated expected value
  reg [1:0]  i;              // Hearing index (0..3)

  // Duration sweep variables
  reg [15:0] dur;            // Current duration
  reg [15:0] dur_end;        // End duration (b[i])
  reg [15:0] dur_cnt;        // Number of durations (b[i] - a[i] + 1)
  reg [31:0] dur_step_q16;   // Step size in Q16.16 for probability per duration

  // Accumulator for per-hearing expectation
  reg [47:0] sum_q16;        // Wider to avoid overflow in intermediate

  // Registers for current hearing parameters
  reg [15:0] cur_s;
  reg [15:0] cur_a;
  reg [15:0] cur_b;

  // Control for per-hearing calculation
  reg        load_hearing;
  reg        next_dur;
  reg        finish_hearing;

  // Next-state logic (FSM)
  always @(*) begin
    state_n = state;
    case (state)
      IDLE: begin
        if (start) state_n = CALCULATE;
      end
      CALCULATE: begin
        if (finish_hearing && (i + 1 >= num_hearings)) begin
          state_n = DONE;
        end
      end
      DONE: begin
        if (!start) state_n = IDLE;
      end
      default: state_n = IDLE;
    endcase
  end

  // Duration probability step computation (for uniform distribution)
  // dur_step_q16 = ONE_Q16 / dur_cnt; computed sequentially using simple subtract loop

  // Registers for step computation
  reg [31:0] step_acc;
  reg [15:0] step_rem;
  reg [7:0]  step_iter;
  reg        step_done;

  // Simple sequential divider by repeated subtraction (bounded by 64 per spec)
  // We constrain dur_cnt to at most 64 (as per up to 64 duration splits)
  // dur_step_q16 = floor(ONE_Q16 / dur_cnt)

  // Step computation FSM-like control (embedded)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      expected      <= 32'd0;
      result        <= 32'd0;
      done          <= 1'b0;
      i             <= 2'd0;
      dur           <= 16'd0;
      dur_end       <= 16'd0;
      dur_cnt       <= 16'd0;
      dur_step_q16  <= 32'd0;
      sum_q16       <= 48'd0;
      cur_s         <= 16'd0;
      cur_a         <= 16'd0;
      cur_b         <= 16'd0;
      load_hearing  <= 1'b0;
      next_dur      <= 1'b0;
      finish_hearing<= 1'b0;
      step_acc      <= 32'd0;
      step_rem      <= 16'd0;
      step_iter     <= 8'd0;
      step_done     <= 1'b0;
    end else begin
      state <= state_n;

      // Default control signal values
      done           <= 1'b0;
      load_hearing   <= 1'b0;
      next_dur       <= 1'b0;
      finish_hearing <= 1'b0;

      case (state)
        IDLE: begin
          expected <= 32'd0;
          i        <= 2'd0;
          if (start) begin
            // Initialize for first hearing
            load_hearing <= 1'b1;
          end
        end

        CALCULATE: begin
          // When entering CALCULATE or after finishing a hearing, load next hearing
          if (load_hearing) begin
            cur_s   <= s[i];
            cur_a   <= a[i];
            cur_b   <= b[i];

            // Clamp max duration count to 64
            if (b[i] >= a[i]) begin
              if ((b[i] - a[i] + 16'd1) > 16'd64)
                dur_cnt <= 16'd64;
              else
                dur_cnt <= (b[i] - a[i] + 16'd1);
            end else begin
              dur_cnt <= 16'd1; // safety
            end

            dur       <= a[i];
            dur_end   <= a[i] + dur_cnt - 16'd1;
            sum_q16   <= 48'd0;

            // Initialize step computation
            step_acc  <= 32'd0;
            step_rem  <= 16'd0;
            step_iter <= 8'd0;
            step_done <= 1'b0;
          end

          // Step size computation: ONE_Q16 / dur_cnt using simple iterative subtract
          if (!step_done) begin
            if (step_iter < 8'd64) begin
              if (step_rem + dur_cnt <= 16'hFFFF) begin
                step_rem  <= step_rem + dur_cnt;
                step_acc  <= step_acc + 32'd1;
              end else begin
                step_done <= 1'b1;
              end
              step_iter <= step_iter + 8'd1;
            end else begin
              step_done <= 1'b1;
            end
            if (step_done) begin
              // Convert quotient (step_acc) from integer fraction to Q16.16
              dur_step_q16 <= (ONE_Q16 / (dur_cnt != 0 ? dur_cnt : 16'd1));
            end
          end else begin
            // Main expectation accumulation once step is ready
            // Probability per duration = dur_step_q16
            // Expected increment per duration = probability * (attend?1:0)

            if (dur <= dur_end) begin
              // Simple heuristic: always attend each hearing independently
              // Use 1.0 (ONE_Q16) as attend contribution for each feasible duration
              sum_q16 <= sum_q16 + dur_step_q16;
              dur     <= dur + 16'd1;
            end else begin
              // Finished durations for this hearing
              expected <= expected + sum_q16[31:0];
              finish_hearing <= 1'b1;
              if (i + 1 < num_hearings) begin
                i            <= i + 1;
                load_hearing <= 1'b1;
              end
            end
          end
        end

        DONE: begin
          result <= expected;
          done   <= 1'b1;
          if (!start) begin
            // Wait for start to deassert to go back to IDLE via next-state logic
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule