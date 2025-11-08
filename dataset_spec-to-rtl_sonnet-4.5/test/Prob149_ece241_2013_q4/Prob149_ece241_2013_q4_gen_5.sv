module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);

  // State encoding for previous water level
  typedef enum reg [1:0] {
    LEVEL_BELOW_S0 = 2'b00,
    LEVEL_S0_S1 = 2'b01,
    LEVEL_S1_S2 = 2'b10,
    LEVEL_ABOVE_S2 = 2'b11
  } level_state_t;

  level_state_t prev_level, curr_level;

  // Determine current water level based on sensors
  always @(*) begin
    case(s)
      3'b111: curr_level = LEVEL_ABOVE_S2;   // Above s[2]
      3'b011: curr_level = LEVEL_S1_S2;      // Between s[2] and s[1]
      3'b001: curr_level = LEVEL_S0_S1;      // Between s[1] and s[0]
      3'b000: curr_level = LEVEL_BELOW_S0;   // Below s[0]
      default: curr_level = prev_level;      // Invalid sensor reading, maintain previous
    endcase
  end

  // Sequential logic for state tracking
  always @(posedge clk) begin
    if (reset) begin
      prev_level <= LEVEL_BELOW_S0;
    end else begin
      prev_level <= curr_level;
    end
  end

  // Combinational logic for outputs
  always @(*) begin
    // Default values
    fr2 = 1'b0;
    fr1 = 1'b0;
    fr0 = 1'b0;
    dfr = 1'b0;

    // Determine nominal flow rate based on current level
    case(curr_level)
      LEVEL_ABOVE_S2: begin
        // No flow needed
        fr2 = 1'b0;
        fr1 = 1'b0;
        fr0 = 1'b0;
      end
      LEVEL_S1_S2: begin
        // Between s[2] and s[1]: fr0 only
        fr0 = 1'b1;
      end
      LEVEL_S0_S1: begin
        // Between s[1] and s[0]: fr0, fr1
        fr0 = 1'b1;
        fr1 = 1'b1;
      end
      LEVEL_BELOW_S0: begin
        // Below s[0]: fr0, fr1, fr2
        fr0 = 1'b1;
        fr1 = 1'b1;
        fr2 = 1'b1;
      end
    endcase

    // Determine if supplemental flow (dfr) should be enabled
    // dfr is enabled if water level is rising (prev_level < curr_level)
    // or if we're at reset condition
    if (reset) begin
      dfr = 1'b1;
      fr0 = 1'b1;
      fr1 = 1'b1;
      fr2 = 1'b1;
    end else if (prev_level < curr_level) begin
      dfr = 1'b1;
    end
  end

endmodule