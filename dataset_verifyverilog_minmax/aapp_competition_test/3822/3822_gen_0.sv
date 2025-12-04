module pupil_transport_time(
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [15:0] l,
  input [15:0] v1,
  input [15:0] v2,
  input [15:0] k,
  output reg [31:0] time_q16,
  output reg done
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam RUN  = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg start_d;
  wire start_pulse;

  // Edge detection for start pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else        start_d <= start;
  end
  assign start_pulse = start & ~start_d;

  // Internal registers
  reg [31:0] low, high;        // Q16.16 bounds
  reg [4:0] iter_cnt;          // 0..15, counts completed iterations

  // Wire definitions for constants derived from inputs (Q16.16)
  wire [15:0] groups = (n + k - 1) / k;               // number of bus trips
  wire [31:0] v1_q   = {v1, 16'b0};
  wire [31:0] v2_q   = {v2, 16'b0};
  wire [31:0] l_q    = {l, 16'b0};
  wire [31:0] sum_speed = v1_q + v2_q;                 // v1+v2 (Q16.16)

  // term = (v2 * (groups-1)) / (v1+v2)  (Q16.16)
  wire [31:0] numer   = v2_q * (groups - 1);
  wire [31:0] term    = numer / sum_speed;              // integer division

  // factor = groups + term (Q16.16)
  wire [31:0] factor  = (groups << 16) + term;

  // C = ((factor * v1) >> 16) + (v2 - v1)  (Q16.16)
  wire [63:0] factor_times_v1 = factor * v1_q;
  wire [31:0] factor_times_v1_q = factor_times_v1 >> 16;
  wire [31:0] C = factor_times_v1_q + (v2_q - v1_q);

  // LHS = factor * l (Q32.32)
  wire [63:0] LHS = $unsigned(factor) * $unsigned(l_q);

  // Upper bound for binary search: time if all pupils walk (l / v1) (Q16.16)
  wire [31:0] high_bound = l_q / v1_q;

  // Binary search internal signals
  wire [32:0] sum = {1'b0, low} + {1'b0, high};
  wire [31:0] mid = (iter_cnt == 0) ? (high_bound >> 1) : sum[32:1];
  wire [63:0] prod = $unsigned(mid) * $unsigned(C);

  // Next state logic
  wire do_done = (state == RUN) && (iter_cnt == 5'b01111); // iter_cnt == 15 triggers DONE after this iteration
  always_comb begin
    case (state)
      IDLE: next_state = start_pulse ? RUN : IDLE;
      RUN : next_state = do_done    ? DONE : RUN;
      DONE: next_state = start_pulse ? RUN : DONE;
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      time_q16 <= 32'b0;
      done <= 1'b0;
      low <= 32'b0;
      high <= 32'b0;
      iter_cnt <= 5'b0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          time_q16 <= 32'b0;
          done     <= 1'b0;
          low      <= 32'b0;
          high     <= 32'b0;
          iter_cnt <= 5'b0;
        end
        RUN: begin
          // Output cleared while computing
          time_q16 <= 32'b0;
          done     <= 1'b0;
          // Initialise bounds on first iteration
          if (iter_cnt == 0) begin
            low  <= 32'b0;
            high <= high_bound;
          end
          // Update bounds based on current mid and condition
          if (iter_cnt == 0) begin
            // First iteration uses high_bound directly
            if (prod >= LHS) high <= (high_bound >> 1);
            else             low  <= (high_bound >> 1);
          end else begin
            if (prod >= LHS) high <= mid;
            else             low  <= mid;
          end
          // Increment iteration counter
          iter_cnt <= iter_cnt + 1;
        end
        DONE: begin
          time_q16 <= high;   // final result
          done     <= 1'b1;   // result valid
        end
      endcase
    end
  end

endmodule
