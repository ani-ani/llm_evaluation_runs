module max_quotation_level(
  input clk,              // clock
  input rst_n,            // active-low reset
  input start,            // start computation
  input [2:0] n,          // number of segments (1-8)
  input [2:0] a0,         // segment 0 value
  input [2:0] a1,         // segment 1 value
  input [2:0] a2,         // segment 2 value
  input [2:0] a3,         // segment 3 value
  input [2:0] a4,         // segment 4 value
  input [2:0] a5,         // segment 5 value
  input [2:0] a6,         // segment 6 value
  input [2:0] a7,         // segment 7 value
  output reg [2:0] k,     // maximum k found (0 if no quotation)
  output reg valid         // high when result is valid
);

  // State machine
  localparam IDLE = 1'b0;
  localparam BUSY = 1'b1;
  reg state, next_state;

  // Cycle counter (0..7), total 8 cycles after start
  reg [2:0] i_cycle;

  // Computed constants from start cycle
  reg [2:0] k_base;       // base k for n=1, else 0
  reg [2:0] min_end;      // min(a0, a_{n-1}) for n>1
  reg [2:0] inner_count;  // number of inner segments (n-2)
  reg [2:0] inner_vals [5:0]; // up to 6 inner values (segments 1..6)

  // Max k tracker during compute
  reg [2:0] k_max;

  // Sequential block for state and outputs
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      k <= 3'b0;
      valid <= 1'b0;
      i_cycle <= 3'b0;
    end else begin
      state <= next_state;
      i_cycle <= (state == IDLE) ? 3'b0 : (i_cycle + 1);
      case (state)
        IDLE: begin
          valid <= 1'b0;
          k <= 3'b0;
          if (start) begin
            // Base case (n == 1): k = floor(log2(a0)) when a0 >= 2; else k = 0
            if (n == 3'b001) begin
              if (a0 < 3'b010) k_base <= 3'b0;
              else if (a0 < 3'b100) k_base <= 3'b001;   // 2 -> 1
              else if (a0 < 3'b1000) k_base <= 3'b010;  // 4,5,6,7 -> 2
              else k_base <= 3'b011;                    // 8+ (but 3'b1000 doesn't fit 3b) -> keep safe
            end else begin
              k_base <= 3'b0;
            end

            // Endpoints and inners for n > 1
            if (n > 3'b001) begin
              min_end <= (a0 < a7) ? a0 : a7; // min(a0, a_{n-1}) = min(a0, a7)
              inner_count <= n - 3'b010;      // n - 2
              // Load up to 6 inner values (a1..a6)
              inner_vals[0] <= a1;
              inner_vals[1] <= a2;
              inner_vals[2] <= a3;
              inner_vals[3] <= a4;
              inner_vals[4] <= a5;
              inner_vals[5] <= a6;
            end else begin
              min_end <= 3'b0;
              inner_count <= 3'b0;
            end
            k_max <= 3'b0;
          end
        end

        BUSY: begin
          // In cycle 0: initialize k_max for n>1 with min_end
          if (i_cycle == 3'b000) begin
            if (n > 3'b001) k_max <= min_end;
            else k_max <= 3'b0; // unused when n==1
          end

          // For cycles 0..5: check inner segments if they exist
          if (i_cycle < inner_count) begin
            // Check if a_{i+1} >= 2^{k_max}
            if (i_cycle == 3'b000) begin
              if (inner_vals[0] < (1 << k_max)) k_max <= 3'b0;
            end else if (i_cycle == 3'b001) begin
              if (inner_vals[1] < (1 << k_max)) k_max <= 3'b0;
            end else if (i_cycle == 3'b010) begin
              if (inner_vals[2] < (1 << k_max)) k_max <= 3'b0;
            end else if (i_cycle == 3'b011) begin
              if (inner_vals[3] < (1 << k_max)) k_max <= 3'b0;
            end else if (i_cycle == 3'b100) begin
              if (inner_vals[4] < (1 << k_max)) k_max <= 3'b0;
            end else if (i_cycle == 3'b101) begin
              if (inner_vals[5] < (1 << k_max)) k_max <= 3'b0;
            end
          end

          // Finalize result after 8 cycles
          if (i_cycle == 3'b111) begin
            if (n == 3'b001) k <= k_base;
            else k <= k_max;
            valid <= 1'b1;
            // Return to IDLE next cycle
            state <= IDLE;
          end else begin
            valid <= 1'b0;
          end
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE: next_state = (start ? BUSY : IDLE);
      BUSY: next_state = (i_cycle == 3'b111) ? IDLE : BUSY;
      default: next_state = IDLE;
    endcase
  end

endmodule