module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);

  // State encoding for previous level
  typedef enum reg [1:0] {
    LEVEL_BELOW_S0 = 2'b00,
    LEVEL_S0_S1 = 2'b01,
    LEVEL_S1_S2 = 2'b10,
    LEVEL_ABOVE_S2 = 2'b11
  } level_t;

  level_t prev_level, curr_level;

  // Determine current water level from sensors
  always_comb begin
    case (s)
      3'b111: curr_level = LEVEL_ABOVE_S2;    // Above s[2]
      3'b011: curr_level = LEVEL_S1_S2;       // Between s[2] and s[1]
      3'b001: curr_level = LEVEL_S0_S1;       // Between s[1] and s[0]
      3'b000: curr_level = LEVEL_BELOW_S0;    // Below s[0]
      default: curr_level = LEVEL_BELOW_S0;   // Default to lowest
    endcase
  end

  // State register for previous level
  always_ff @(posedge clk) begin
    if (reset) begin
      prev_level <= LEVEL_BELOW_S0;
    end else begin
      prev_level <= curr_level;
    end
  end

  // Output logic
  always_ff @(posedge clk) begin
    if (reset) begin
      fr2 <= 1'b1;
      fr1 <= 1'b1;
      fr0 <= 1'b1;
      dfr <= 1'b1;
    end else begin
      // Determine nominal flow rate based on current level
      case (curr_level)
        LEVEL_ABOVE_S2: begin
          fr2 <= 1'b0;
          fr1 <= 1'b0;
          fr0 <= 1'b0;
        end
        LEVEL_S1_S2: begin
          fr2 <= 1'b0;
          fr1 <= 1'b0;
          fr0 <= 1'b1;
        end
        LEVEL_S0_S1: begin
          fr2 <= 1'b0;
          fr1 <= 1'b1;
          fr0 <= 1'b1;
        end
        LEVEL_BELOW_S0: begin
          fr2 <= 1'b1;
          fr1 <= 1'b1;
          fr0 <= 1'b1;
        end
      endcase

      // Determine if supplemental flow valve should be opened
      // dfr is asserted if water level is rising (prev < current)
      if (prev_level < curr_level) begin
        dfr <= 1'b1;
      end else begin
        dfr <= 1'b0;
      end
    end
  end

endmodule