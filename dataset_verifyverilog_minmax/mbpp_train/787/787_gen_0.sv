module abbb_matcher(
  input reg clk,
  input reg rst_n,
  input reg [7:0] char,
  input reg valid,
  input reg last,
  output wire match
);

  // State encoding
  localparam IDLE = 3'b000;
  localparam GOT_A = 3'b001;
  localparam GOT_B1 = 3'b010;
  localparam GOT_B2 = 3'b011;
  localparam MATCH_DONE = 3'b100;

  reg [2:0] state, next_state;

  // Sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic (combinational)
  always_comb begin
    next_state = state;
    if (valid) begin
      case (state)
        IDLE: begin
          if (char == 8'h61) next_state = GOT_A;
        end
        GOT_A: begin
          if (char == 8'h62) next_state = GOT_B1;
          else if (char == 8'h61) next_state = GOT_A;
          else next_state = IDLE;
        end
        GOT_B1: begin
          if (char == 8'h62) next_state = GOT_B2;
          else if (char == 8'h61) next_state = GOT_A;
          else next_state = IDLE;
        end
        GOT_B2: begin
          if (char == 8'h62) next_state = MATCH_DONE;
          else if (char == 8'h61) next_state = GOT_A;
          else next_state = IDLE;
        end
        MATCH_DONE: begin
          if (char == 8'h61) next_state = GOT_A;
          else next_state = IDLE;
        end
        default: next_state = IDLE;
      endcase
    end
  end

  // Mealy output: match when pattern completes in current state
  assign match = (state == GOT_B2) && (valid) && (char == 8'h62);

endmodule