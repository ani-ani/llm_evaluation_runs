module sublist_checker (
  input clk,
  input rst_n,
  input start,
  input [15:0] array_A,
  input [15:0] array_B,
  input [1:0] ENA, // actual length = ENA + 1 (0..3)
  input [1:0] ENB, // actual length = ENB + 1 (0..3)
  output reg found,
  output reg done
);

  // Extract elements from flat 16-bit inputs (4x4-bit each)
  wire [3:0] A0, A1, A2, A3;
  wire [3:0] B0, B1, B2, B3;

  assign {A3, A2, A1, A0} = array_A;
  assign {B3, B2, B1, B0} = array_B;

  // For each possible starting position p in A (0..3), evaluate a full parallel comparison
  // if all involved B elements are within bounds and equal to their A counterparts.
  // This becomes the combinatorial match_all signal.
  wire match0, match1, match2, match3;

  // Helper: bounds and equality for up to 4 elements
  wire a0_in = (ENA >= 0);
  wire a1_in = (ENA >= 1);
  wire a2_in = (ENA >= 2);
  wire a3_in = (ENA >= 3);

  wire b0_in = (ENB >= 0);
  wire b1_in = (ENB >= 1);
  wire b2_in = (ENB >= 2);
  wire b3_in = (ENB >= 3);

  // Position 0 in A: uses A[0..min(3,ENB)]
  wire eq0_0 = (A0 == B0) | ~b0_in;  // if B[0] not in range, skip comparison
  wire eq0_1 = (A1 == B1) | ~b1_in;  // similarly for the rest
  wire eq0_2 = (A2 == B2) | ~b2_in;
  wire eq0_3 = (A3 == B3) | ~b3_in;
  wire pos0_valid = (ENA >= ENB);
  assign match0 = pos0_valid & eq0_0 & eq0_1 & eq0_2 & eq0_3;

  // Position 1 in A: requires ENA >= 1 and B fully within range (ENB <= ENA-1)
  wire pos1_valid = (ENA >= 1) && (ENA >= ENB);
  wire eq1_0 = (A1 == B0) | ~b0_in;
  wire eq1_1 = (A2 == B1) | ~b1_in;
  wire eq1_2 = (A3 == B2) | ~b2_in;
  wire eq1_3 = (A3 == B3) | ~b3_in; // unused due to pos1_valid; kept for clarity
  assign match1 = pos1_valid & eq1_0 & eq1_1 & eq1_2;

  // Position 2 in A: requires ENA >= 2 and B fully within range (ENB <= ENA-2)
  wire pos2_valid = (ENA >= 2) && (ENA >= ENB);
  wire eq2_0 = (A2 == B0) | ~b0_in;
  wire eq2_1 = (A3 == B1) | ~b1_in;
  assign match2 = pos2_valid & eq2_0 & eq2_1;

  // Position 3 in A: requires ENA >= 3 and B fully within range (ENB <= ENA-3)
  wire pos3_valid = (ENA >= 3) && (ENA >= ENB);
  wire eq3_0 = (A3 == B0) | ~b0_in;
  assign match3 = pos3_valid & eq3_0;

  // Any position match -> found
  wire match_all = match0 | match1 | match2 | match3;

  // State machine
  typedef enum logic { IDLE = 1'b0, CALC = 1'b1 } state_t;
  state_t state, next_state;

  // Registered outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      found <= 1'b0;
      done  <= 1'b0;
    end else begin
      state <= next_state;
      case (next_state)
        IDLE: begin
          found <= 1'b0;            // idle: result not valid
          done  <= 1'b0;
        end
        CALC: begin
          found <= match_all;       // combinatorial result, valid this cycle
          done  <= 1'b1;            // asserted only during CALC
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE: begin
        next_state = start ? CALC : IDLE;
      end
      CALC: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule