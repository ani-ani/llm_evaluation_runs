module polyline_solver(
    input clk,
    input rst_n,
    input start,
    input [15:0] a_scaled,
    input [15:0] b_scaled,
    output reg [31:0] result_x,
    output reg done,
    output reg no_solution
  );

  // States
  localparam IDLE = 4'd0;
  localparam CHECK_A_LT_B = 4'd1;
  localparam CALCULATE_CASE1 = 4'd2;
  localparam CALCULATE_CASE2 = 4'd3;
  localparam FIND_MIN = 4'd4;
  localparam DONE = 4'd5;

  reg [3:0] state, next_state;

  // Registers for scaled inputs
  reg [15:0] a_reg, b_reg;

  // Intermediate values (Q16.16 format)
  reg signed [31:0] a_fixed;
  reg signed [31:0] b_fixed;
  reg signed [31:0] a_minus_b;
  reg signed [31:0] a_plus_b;

  // Helper variables for k calculations
  reg signed [31:0] temp_divisor; // 2*b or 2*b (temp storage)
  reg signed [31:0] k_calc;       // k from division
  reg signed [31:0] k_calc_minus_1; // k - 1
  reg signed [31:0] denom_case1;  // 2*k
  reg signed [31:0] denom_case2;  // 2*(k+1) = 2*k + 2

  // Candidates
  reg signed [31:0] x_candidate1; // Case 1
  reg signed [31:0] x_candidate2; // Case 2
  reg signed [31:0] x_min;

  // Validity flags
  reg valid1;
  reg valid2;

  // Divider control
  reg div_start;
  reg div_ready;
  reg signed [31:0] div_numer;
  reg signed [31:0] div_denom;
  wire signed [31:0] div_result;
  wire div_valid;

  // Divider Module (Restoring Division, sequential)
  // Implements Q16.16 / Q16.16 -> Q16.16 (approximated via integer math and scaling)
  // We need 32-bit input / 32-bit input.
  // Since inputs are scaled by 2^8, we need to adjust precision.
  // For this module, we implement a simple iterative divider.
  // Inputs: div_numer (Q16.16), div_denom (Q16.16). Output: div_result (Q16.16).
  // Note: To avoid complex FP, we treat inputs as integers and scale back.
  // Integer division: N/D = Result. To get Q16.16: (N << 16) / D.
  // But N and D are already Q16.16. So (N << 16) / D is effectively (N / D) << 16.
  // This might overflow 32-bit easily. We must use 64-bit intermediate or limit range.
  // Given constraints, we will implement a 32-cycle divider (booth or restoring) or use assumption.
  // To meet 20 cycle constraint, we must be efficient.
  // Let's use a 32-bit restoring divider with 32 cycles (simplified for code).
  // However, 20 cycles is tight. Let's assume we use a simplified fixed-point divider or 
  // rely on the fact that we are doing integer division of scaled values.
  // Correct approach: (a-b) is Q16.16. Denom is Q16.16. Result Q16.16.
  // (A << 16) / B = Result.
  // We will implement a sequential restoring divider.

  reg [5:0] div_count;
  reg [63:0] div_reg; // Holds N << 32 (effectively)
  reg [31:0] div_d_reg;
  reg div_running;

  assign div_valid = (div_count == 32 && div_running);
  assign div_result = div_reg[63:32]; // Quotient is upper 32 bits

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_running <= 0;
      div_count <= 0;
      div_reg <= 0;
      div_d_reg <= 0;
    end else begin
      if (div_start && !div_running) begin
        if (div_denom == 0) begin
          // Handle division by zero immediately
          div_running <= 0;
          div_result <= 32'hFFFF_FFFF; // Error indicator or max
        end else begin
          div_running <= 1;
          div_count <= 0;
          // N << 32 format for 32-bit integer division to get Q16.16 result
          // Input div_numer is Q16.16. We want (div_numer / div_denom) * 2^16.
          // Mathematically: (div_numer * 2^16) / div_denom = (div_numer << 16) / div_denom.
          // To maintain precision, let's do (div_numer << 32) / div_denom.
          // Result will be in [63:32].
          div_reg <= {div_numer, 32'h0}; // Shifted left by 32
          div_d_reg <= div_denom;
        end
      end else if (div_running) begin
        if (div_count < 32) begin
          div_reg <= div_reg << 1;
          if (div_reg[63:32] >= div_d_reg) begin
            div_reg[0] <= 1;
            div_reg[63:32] <= div_reg[63:32] - div_d_reg;
          end
          div_count <= div_count + 1;
        end else begin
          div_running <= 0; // Done
        end
      end
    end
  end

  // State Transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Next State Logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start) next_state = CHECK_A_LT_B;
        else next_state = IDLE;
      end
      CHECK_A_LT_B: begin
        if (b_reg == 0) next_state = DONE; // b=0 is invalid generally or implies no segment height
        else if (a_fixed < b_fixed) next_state = DONE; // No solution if a < b (since max y is x, and b <= x, so if b > a, x > a... wait, check logic)
        else next_state = CALCULATE_CASE1;
      end
      CALCULATE_CASE1: begin
        // Calculate k. k = (a-b)/(2b).
        // If division is running, wait. If done, proceed.
        if (div_running) next_state = CALCULATE_CASE1;
        else if (div_valid) next_state = CALCULATE_CASE2;
        else next_state = CALCULATE_CASE1;
      end
      CALCULATE_CASE2: begin
        // Calculate k. k = (a+b)/(2b) - 1.
        if (div_running) next_state = CALCULATE_CASE2;
        else if (div_valid) next_state = FIND_MIN;
        else next_state = CALCULATE_CASE2;
      end
      FIND_MIN: begin
        next_state = DONE;
      end
      DONE: begin
        if (start) next_state = IDLE; // Wait for reset or new start
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath Logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      no_solution <= 0;
      result_x <= 0;
      div_start <= 0;
      a_reg <= 0;
      b_reg <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          no_solution <= 0;
          if (start) begin
            a_reg <= a_scaled;
            b_reg <= b_scaled;
            // Convert scaled to Q16.16 immediately: val << 8
            // a_scaled is Q8.8 (scaled by 2^8). Target Q16.16.
            // Input is [15:0]. We need to shift left by 8 to get integer part in [23:8] and frac in [7:0].
            // Q16.16 has 16 integer, 16 frac.
            // Scaled input has 8 integer, 8 frac (assuming inputs were integers scaled by 256).
            // If input is actual * 256. We want actual * 65536.
            // So shift left by 8. 
            a_fixed <= {8'b0, a_scaled, 8'b0}; // {sign_ext, val, zeros} 
            b_fixed <= {8'b0, b_scaled, 8'b0};
          end
        end

        CHECK_A_LT_B: begin
          // Logic handled in next_state, no ops here usually unless we latch flags
        end

        CALCULATE_CASE1: begin
          // Division 1: (a - b) / (2b)
          if (!div_running && !div_valid && div_count == 0) begin
            div_numer <= a_fixed - b_fixed;
            div_denom <= b_fixed <<< 1; // 2b
            div_start <= 1;
          end else if (div_running) begin
            div_start <= 0;
          end else if (div_valid) begin
            // Result is in div_result. This is k_calc in Q16.16 format (though k is integer)
            // We need floor(k). Since inputs are integers, result is integer.
            k_calc <= div_result;
            div_start <= 0;
          end
        end

        CALCULATE_CASE2: begin
          // Division 2: (a + b) / (2b)
          if (!div_running && !div_valid && div_count == 0 && state == CALCULATE_CASE2) begin
            // Note: We reuse the divider. Must ensure it's ready.
            // But we need to save k_calc from prev step. It's already saved.
            div_numer <= a_fixed + b_fixed;
            div_denom <= b_fixed <<< 1; // 2b
            div_start <= 1;
          end else if (div_running) begin
            div_start <= 0;
          end else if (div_valid) begin
            // k2 = result - 1 (integer arithmetic)
            // div_result is Q16.16. Subtract 1.0 (which is 1<<16)
            k_calc_minus_1 <= div_result - (1 << 16);
            div_start <= 0;
          end
        end

        FIND_MIN: begin
          // 1. Calculate Case 1 x
          // x1 = (a-b) / (2*k)
          // k might be 0 or negative. Check validity.
          // k_calc is Q16.16. Check if k_calc > 0.
          valid1 <= (k_calc > (1 << 16)); // k > 1 (strictly > 0, integer check)

          // 2. Calculate Case 2 x
          // x2 = (a+b) / (2*(k+1)) = (a+b) / (2*k_calc_minus_1 + 4?)
          // k2 = k_calc_minus_1. Need k2 >= 0.
          valid2 <= (k_calc_minus_1 >= 0);

          // Calculate denominators
          // denom1 = 2*k. k is integer. k_calc is Q16.16. 
          // We need to perform division (a-b) / (2*k).
          // We have limited divider. We can chain operations or use combinational if simple.
          // But we need 20 cycles. We've used 2 so far (for initial divisions).
          // We need 2 more for x values. 
          // Let's compute denominators.
          // 2*k: k_calc is Q16.16. Multiply by 2. Denom is Q16.16.
          // (a-b) is Q16.16.

          // To save cycles, we might need to use combinational logic for these divisions if feasible, 
          // or a second state for calculations.
          // Since instructions say 20 cycles, we can spare states.
          // Let's trigger the divider for x1 and x2.

          // If valid1: trigger (a-b) / (2*k)
          // If valid2: trigger (a+b) / (2*(k+1))
        end

        DONE: begin
          done <= 1;
          if (!valid1 && !valid2) no_solution <= 1;
          else no_solution <= 0;

          // Min logic
          if (valid1 && valid2) begin
            if (x_candidate1 < x_candidate2) result_x <= x_candidate1;
            else result_x <= x_candidate2;
          end else if (valid1) begin
            result_x <= x_candidate1;
          end else if (valid2) begin
            result_x <= x_candidate2;
          end
        end
      endcase

      // Additional logic to handle the two sequential divisions for x1 and x2
      // We need to inject these into the cycle. 
      // We can do: 
      // FIND_MIN state starts x1 calc. Next cycle (or same) trigger x2 if valid?
      // Actually, we need to process them. 
      // Let's modify the state machine slightly or add an explicit state.
      // Since strict 20 cycles is required, let's insert states.
      // However, 20 cycles is generous for 4 divisions. 
      // Let's add states: CALC_X1, CALC_X2 between FIND_MIN and DONE.
    end
  end

  // Re-defining FSM to include X calculations for precision
  // States: IDLE, CHECK, K1_DIV, K2_DIV, X1_DIV, X2_DIV, MIN, DONE
  // This covers the logic cleanly.

  // Override the previous state definition for more details
  localparam S_IDLE = 4'd0;
  localparam S_CHECK = 4'd1;
  localparam S_K1_DIV = 4'd2; // Calculate k for case 1
  localparam S_K2_DIV = 4'd3; // Calculate k for case 2
  localparam S_X1_DIV = 4'd4; // Calculate x for case 1
  localparam S_X2_DIV = 4'd5; // Calculate x for case 2
  localparam S_MIN = 4'd6;
  localparam S_DONE = 4'd7;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else begin
      case (state)
        S_IDLE: if (start) state <= S_CHECK; else state <= S_IDLE;
        S_CHECK: begin
          if (b_reg == 0) state <= S_DONE;
          else if (a_fixed < b_fixed) state <= S_DONE;
          else state <= S_K1_DIV;
        end
        S_K1_DIV: if (!div_running && div_valid) state <= S_K2_DIV; else state <= S_K1_DIV;
        S_K2_DIV: if (!div_running && div_valid) state <= S_X1_DIV; else state <= S_X1_DIV; // Optimized: go to X1 immediately, trigger in datapath
        S_X1_DIV: begin
          // Logic to trigger x1 div. If valid1 is false, skip to X2
          if (!valid1 || (!div_running && div_valid)) state <= S_X2_DIV;
          else state <= S_X1_DIV;
        end
        S_X2_DIV: begin
          if (!valid2 || (!div_running && div_valid)) state <= S_MIN;
          else state <= S_X2_DIV;
        end
        S_MIN: state <= S_DONE;
        S_DONE: if (start) state <= S_IDLE; else state <= S_DONE;
      endcase
    end
  end

  // Datapath for refined states
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      no_solution <= 0;
      result_x <= 0;
      div_start <= 0;
      x_candidate1 <= 32'h7FFFFFFF; // Max pos
      x_candidate2 <= 32'h7FFFFFFF;
      valid1 <= 0;
      valid2 <= 0;
    end else begin
      done <= 0;
      no_solution <= 0;

      case (state)
        S_IDLE: begin
          if (start) begin
            a_fixed <= {8'b0, a_scaled, 8'b0};
            b_fixed <= {8'b0, b_scaled, 8'b0};
            x_candidate1 <= 32'h7FFFFFFF;
            x_candidate2 <= 32'h7FFFFFFF;
            valid1 <= 0;
            valid2 <= 0;
          end
        end

        S_CHECK: begin
          // Setup done in transition or here
        end

        S_K1_DIV: begin
          if (state == S_K1_DIV && !div_running && !div_valid && div_count == 0) begin
            div_numer <= a_fixed - b_fixed;
            div_denom <= b_fixed <<< 1;
            div_start <= 1;
          end else if (div_running) div_start <= 0;
          else if (div_valid) begin
            k_calc <= div_result;
          end
        end

        S_K2_DIV: begin
          // Triggered immediately upon entering or in next cycle? 
          // Let's use the first cycle of this state to set up.
          if (!div_running && !div_valid && div_count == 0) begin
             div_numer <= a_fixed + b_fixed;
             div_denom <= b_fixed <<< 1;
             div_start <= 1;
          end else if (div_running) div_start <= 0;
          else if (div_valid) begin
             k_calc_minus_1 <= div_result - (1 << 16);
          end
        end

        S_X1_DIV: begin
          // Check validity of k_calc (k > 0)
          // If valid, trigger (a-b) / (2*k)
          if (k_calc > (1 << 16)) begin
             valid1 <= 1;
             if (!div_running && !div_valid && div_count == 0) begin
               div_numer <= a_fixed - b_fixed;
               // Denom: 2*k. k_calc is Q16.16. So shift left 1.
               // Actually, division (a-b)/k requires (a-b)/(k)
               // k is integer. But stored as Q16.16.
               // We want result in Q16.16. 
               // Formula: x = (a-b)/(2k). 
               // Numerator (a-b) is Q16.16. Denom is 2*k (integer). 
               // But we want Q16.16 result. 
               // If we do ((a-b) << 16) / (2*k), we get Q16.16. 
               // Our divider takes Q16.16 numerator and Q16.16 denom? 
               // Earlier divider does (N << 32) / D.
               // We need to be careful. 
               // Let's define Div(A, B) -> A << 16 / B (approx).
               // If B is integer (k*2), we can do: 
               // (A << 16) / B.
               // To use our divider: DivInput_A = A << 16. DivInput_B = B << 16.
               // Result = (A << 32) / (B << 16) = (A << 16) / B. 
               // So we need to shift inputs.
               div_numer <= (a_fixed - b_fixed) << 16;
               div_denom <= (k_calc <<< 1); // 2*k in Q16.16
               div_start <= 1;
             end else if (div_running) div_start <= 0;
             else if (div_valid) begin
               x_candidate1 <= div_result;
             end
          end
        end

        S_X2_DIV: begin
          if (k_calc_minus_1 >= 0) begin
             valid2 <= 1;
             if (!div_running && !div_valid && div_count == 0) begin
               div_numer <= (a_fixed + b_fixed) << 16;
               // Denom: 2*(k+1) = 2*k - 2 + 4? No.
               // k_case2 = k_calc - 1.
               // Denom = 2*(k_case2 + 1) = 2*k_calc.
               // Wait. Case 2 formula: x = (a+b)/(2k+2) where k is from case 2 formula.
               // k_case2 = floor((a+b)/(2b)) - 1.
               // Denom = 2*(k_case2 + 1) = 2*k_calc (where k_calc is result of (a+b)/(2b)).
               // So we need to reuse k_calc? No, we computed k_calc_minus_1.
               // If k_calc_minus_1 = k_case2.
               // Denom = 2 * (k_case2 + 1) = 2 * (k_calc - 1 + 1) = 2 * k_calc (from the first division of this step? NO!)
               // We computed k_calc_minus_1 = (Result of (a+b)/(2b)) - 1.
               // Let's call Result of (a+b)/(2b) = K_temp.
               // We didn't save K_temp. We saved K_temp - 1.
               // So we can recover K_temp = k_calc_minus_1 + 1.
               // Denom = 2 * K_temp = 2 * (k_calc_minus_1 + 1).
               // So denom = (k_calc_minus_1 + 1) << 1.
               div_denom <= (k_calc_minus_1 + (1 << 16)) <<< 1;
               div_start <= 1;
             end else if (div_running) div_start <= 0;
             else if (div_valid) begin
               x_candidate2 <= div_result;
             end
          end
        end

        S_MIN: begin
          // Just latching results happens in next state or combinational
          // But result_x is output reg. We update it now.
          if (valid1 && valid2) begin
            if (x_candidate1 < x_candidate2) result_x <= x_candidate1;
            else result_x <= x_candidate2;
          end else if (valid1) result_x <= x_candidate1;
          else if (valid2) result_x <= x_candidate2;
          else result_x <= 0;
        end

        S_DONE: begin
          done <= 1;
          if (!valid1 && !valid2) no_solution <= 1;
          else no_solution <= 0;
        end
      endcase
    end
  end

endmodule