module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);

  // State encoding: previous water level
  typedef enum reg [1:0] {
    BELOW_S0 = 2'b00,
    BETWEEN_S0_S1 = 2'b01,
    BETWEEN_S1_S2 = 2'b10,
    ABOVE_S2 = 2'b11
  } state_t;

  state_t current_state, next_state;
  reg [1:0] current_level, prev_level;

  // Determine current water level from sensors
  always @(*) begin
    case(s)
      3'b000: current_level = BELOW_S0;
      3'b001: current_level = BETWEEN_S0_S1;
      3'b011: current_level = BETWEEN_S1_S2;
      3'b111: current_level = ABOVE_S2;
      default: current_level = BELOW_S0;
    endcase
  end

  // State register
  always @(posedge clk) begin
    if (reset) begin
      current_state <= BELOW_S0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_level;
  end

  // Output logic
  always @(*) begin
    prev_level = current_state;
    
    // Default values
    fr2 = 1'b0;
    fr1 = 1'b0;
    fr0 = 1'b0;
    dfr = 1'b0;

    case(current_level)
      BELOW_S0: begin
        fr2 = 1'b1;
        fr1 = 1'b1;
        fr0 = 1'b1;
        dfr = 1'b0;
      end
      
      BETWEEN_S0_S1: begin
        fr2 = 1'b0;
        fr1 = 1'b1;
        fr0 = 1'b1;
        // dfr = 1 if previous level was lower
        dfr = (prev_level < current_level) ? 1'b1 : 1'b0;
      end
      
      BETWEEN_S1_S2: begin
        fr2 = 1'b0;
        fr1 = 1'b0;
        fr0 = 1'b1;
        // dfr = 1 if previous level was lower
        dfr = (prev_level < current_level) ? 1'b1 : 1'b0;
      end
      
      ABOVE_S2: begin
        fr2 = 1'b0;
        fr1 = 1'b0;
        fr0 = 1'b0;
        dfr = 1'b0;
      end
    endcase
    
    // Override outputs during reset
    if (reset) begin
      fr2 = 1'b1;
      fr1 = 1'b1;
      fr0 = 1'b1;
      dfr = 1'b1;
    end
  end

endmodule