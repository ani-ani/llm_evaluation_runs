module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);

  // State encoding: represents previous water level
  typedef enum reg [1:0] {
    LEVEL_BELOW_S0 = 2'b00,
    LEVEL_S0_S1 = 2'b01,
    LEVEL_S1_S2 = 2'b10,
    LEVEL_ABOVE_S2 = 2'b11
  } state_t;

  state_t current_state, next_state;

  // Determine current water level from sensors
  function [1:0] get_level;
    input [2:0] sensors;
    begin
      case (sensors)
        3'b111: get_level = 2'b11; // Above s[2]
        3'b011: get_level = 2'b10; // Between s[1] and s[2]
        3'b001: get_level = 2'b01; // Between s[0] and s[1]
        default: get_level = 2'b00; // Below s[0]
      endcase
    end
  endfunction

  // State register
  always @(posedge clk) begin
    if (reset)
      current_state <= LEVEL_BELOW_S0;
    else
      current_state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = state_t'(get_level(s));
  end

  // Output logic
  always @(*) begin
    // Default values
    fr2 = 1'b0;
    fr1 = 1'b0;
    fr0 = 1'b0;
    dfr = 1'b0;

    case (s)
      3'b111: begin // Above s[2]
        fr2 = 1'b0;
        fr1 = 1'b0;
        fr0 = 1'b0;
        dfr = 1'b0;
      end
      3'b011: begin // Between s[1] and s[2]
        fr0 = 1'b1;
        fr1 = 1'b0;
        fr2 = 1'b0;
        // dfr = 1 if previous level was lower
        if (current_state < LEVEL_S1_S2)
          dfr = 1'b1;
        else
          dfr = 1'b0;
      end
      3'b001: begin // Between s[0] and s[1]
        fr0 = 1'b1;
        fr1 = 1'b1;
        fr2 = 1'b0;
        // dfr = 1 if previous level was lower
        if (current_state < LEVEL_S0_S1)
          dfr = 1'b1;
        else
          dfr = 1'b0;
      end
      default: begin // Below s[0]
        fr0 = 1'b1;
        fr1 = 1'b1;
        fr2 = 1'b1;
        dfr = 1'b1;
      end
    endcase
  end

endmodule