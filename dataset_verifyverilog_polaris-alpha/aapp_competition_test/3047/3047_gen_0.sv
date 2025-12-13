module puzzle_solver(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] burger   [0:2],
  input  [7:0] slop     [0:2],
  input  [7:0] sushi    [0:2],
  input  [7:0] drumstick[0:2],
  output reg [15:0] num_solutions,
  output reg        many_flag,
  output reg        done
);

  // State encoding
  localparam IDLE  = 2'b00;
  localparam RUN   = 2'b01;
  localparam FIN   = 2'b10;

  reg [1:0] state, next_state;

  reg [7:0] cand;              // candidate value 1..255
  reg [7:0] cand_next;

  reg [15:0] sol_cnt, sol_cnt_next;
  reg        many_next;
  reg        done_next;

  // Sticky flag once many_flag is detected
  wire       at_last = (cand == 8'd255);

  integer i;

  // Helper function: determine base ratio from plates and candidate, and check consistency
  // We treat three independent ratio groups (monster 0,1,2) and require them all to match.
  // Each group:
  //   known1: burger, slop
  //   known2: sushi, drumstick
  // Some are 255 (missing), replaced by cand if 255.
  // If after substitution any remains 255, that candidate invalid.
  // Use 16-bit products for comparison.

  function automatic bit is_valid_candidate(input [7:0] val);
    // Local substituted values
    reg [7:0] b[0:2];
    reg [7:0] s[0:2];
    reg [7:0] u[0:2];
    reg [7:0] d[0:2];

    // base ratio numerator/denominator from first fully-known plate pair
    reg [15:0] base_num, base_den;
    bit base_set;

    reg [15:0] num, den;
    integer j;

    begin
      // Substitute cand for any 255
      for (j = 0; j < 3; j = j + 1) begin
        b[j] = (burger[j]    == 8'hFF) ? val : burger[j];
        s[j] = (slop[j]      == 8'hFF) ? val : slop[j];
        u[j] = (sushi[j]     == 8'hFF) ? val : sushi[j];
        d[j] = (drumstick[j] == 8'hFF) ? val : drumstick[j];
      end

      // If any remains 255, invalid (we required substitution to cover all missings)
      for (j = 0; j < 3; j = j + 1) begin
        if (b[j] == 8'hFF || s[j] == 8'hFF || u[j] == 8'hFF || d[j] == 8'hFF)
          return 1'b0;
      end

      // Additionally require all values 1..255 (no zeros allowed per problem scanning domain)
      for (j = 0; j < 3; j = j + 1) begin
        if (b[j] == 8'd0 || s[j] == 8'd0 || u[j] == 8'd0 || d[j] == 8'd0)
          return 1'b0;
      end

      // Set base ratio from first plate
      base_set = 1'b0;
      base_num = 16'd0;
      base_den = 16'd0;

      // Scan each plate, enforce burger*drumstick == slop*sushi
      for (j = 0; j < 3; j = j + 1) begin
        num = b[j] * d[j];
        den = s[j] * u[j];

        // All positive, check equality for this plate itself
        if (num != den)
          return 1'b0;

        // Also use this as ratio reference
        if (!base_set) begin
          base_num = num;
          base_den = den;
          base_set = 1'b1;
        end else begin
          // Ensure same ratio across plates: num/den == base_num/base_den
          // Cross-multiply: num * base_den == base_num * den
          if (num * base_den != base_num * den)
            return 1'b0;
        end
      end

      // If we reached here, candidate is valid
      return 1'b1;
    end
  endfunction

  // Detect if infinite (many) solutions exist based on constraints only.
  // Simplified interpretation for this scaled-down version:
  // - If there exists at least one plate where all four entries are missing (255),
  //   then that plate is completely unconstrained and can scale arbitrarily,
  //   hence infinitely many solutions.

  function automatic bit detect_infinite;
    integer j;
    begin
      detect_infinite = 1'b0;
      for (j = 0; j < 3; j = j + 1) begin
        if (burger[j]    == 8'hFF &&
            slop[j]      == 8'hFF &&
            sushi[j]     == 8'hFF &&
            drumstick[j] == 8'hFF) begin
          detect_infinite = 1'b1;
        end
      end
    end
  endfunction

  // Sequential state / regs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      cand          <= 8'd0;
      sol_cnt       <= 16'd0;
      many_flag     <= 1'b0;
      num_solutions <= 16'd0;
      done          <= 1'b0;
    end else begin
      state         <= next_state;
      cand          <= cand_next;
      sol_cnt       <= sol_cnt_next;
      many_flag     <= many_next;
      num_solutions <= (next_state == FIN) ? sol_cnt_next : num_solutions;
      done          <= done_next;
    end
  end

  // Combinational next-state logic
  always @(*) begin
    next_state    = state;
    cand_next     = cand;
    sol_cnt_next  = sol_cnt;
    many_next     = many_flag;
    done_next     = done;

    case (state)
      IDLE: begin
        done_next    = 1'b0;
        sol_cnt_next = 16'd0;
        cand_next    = 8'd1;
        many_next    = 1'b0;
        if (start) begin
          // Check infinite condition immediately
          if (detect_infinite()) begin
            many_next   = 1'b1;
            done_next   = 1'b1;
            next_state  = FIN;
          end else begin
            next_state  = RUN;
          end
        end
      end

      RUN: begin
        done_next = 1'b0;

        // Evaluate current candidate
        if (is_valid_candidate(cand)) begin
          sol_cnt_next = sol_cnt + 16'd1;
        end

        // Advance candidate
        if (at_last) begin
          // Completed search
          next_state = FIN;
          done_next  = 1'b1;
        end else begin
          cand_next = cand + 8'd1;
        end
      end

      FIN: begin
        // Hold results until next start pulse
        done_next = 1'b1;
        if (start) begin
          // Restart computation
          sol_cnt_next = 16'd0;
          cand_next    = 8'd1;
          many_next    = 1'b0;
          done_next    = 1'b0;
          if (detect_infinite()) begin
            many_next   = 1'b1;
            done_next   = 1'b1;
            next_state  = FIN;
          end else begin
            next_state  = RUN;
          end
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule