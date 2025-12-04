module rebus_solver(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // pulse to start computation
  input [3:0] num_terms, // number of question marks (1-16)
  input [15:0] n, // target value (1-65535)
  input [15:0] sign_pattern, // 1=positive, 0=negative for each term [bit0=first_term]
  output reg [15:0] solution [0:15], // solution values (1-n)
  output reg possible, // 1 if solvable
  output reg done // high when computation completes
);

  // State machine
  localparam IDLE = 2'b00;
  localparam POS  = 2'b01;
  localparam NEG  = 2'b10;
  localparam DONE = 2'b11;

  // Internal signals
  reg [1:0] state, next_state;
  reg [3:0] term_idx;   // current term index within num_terms
  reg [3:0] terms_left; // how many terms left to process
  reg [15:0] remaining; // how much of n is still to be allocated
  reg [15:0] pos_left;  // positive terms left to process
  reg [15:0] neg_left;  // negative terms left to process
  reg [15:0] pos_rem;   // remaining sum that must be allocated to positive terms
  integer i;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next-state and datapath
  always @* begin
    // Default outputs and signals
    next_state = state;
    done = 1'b0;
    possible = 1'b0;
    term_idx = term_idx;
    terms_left = terms_left;
    remaining = remaining;
    pos_left = pos_left;
    neg_left = neg_left;
    pos_rem = pos_rem;
    // solution array will be driven by sequential block below

    case (state)
      IDLE: begin
        term_idx = 4'd0;
        terms_left = 4'd0;
        remaining = 16'd0;
        pos_left = 16'd0;
        neg_left = 16'd0;
        pos_rem = 16'd0;
        if (start) begin
          // Clear solution array
          for (i = 0; i < 16; i = i + 1) begin
            solution[i] = 16'd0;
          end
          // Count number of positive and negative terms
          pos_left = 16'd0;
          neg_left = 16'd0;
          for (i = 0; i < 16; i = i + 1) begin
            if (i < num_terms) begin
              if (sign_pattern[i]) pos_left = pos_left + 1;
              else neg_left = neg_left + 1;
            end
          end
          // Minimal sum = sum of 1 for each term = num_terms
          // Positive part of min sum is 1*pos_left
          // The rest (1*neg_left) will subtract; equivalent to pos_rem = 0
          terms_left = num_terms;
          remaining = n; // We'll allocate to positive terms until remaining is matched
          pos_rem = remaining - pos_left; // remaining to allocate to positive terms beyond their 1s
          next_state = (num_terms == 4'd0) ? DONE : POS;
        end
      end

      POS: begin
        // Allocate to positive terms first
        if (pos_left > 0) begin
          if (pos_rem >= n) begin
            // We can fill this positive term to max (n) and consume one term
            solution[term_idx] = n;
            remaining = remaining - n;
            pos_left = pos_left - 1;
            term_idx = term_idx + 1;
            terms_left = terms_left - 1;
            if (terms_left == 1) begin
              // Last term is positive, must absorb remainder exactly
              pos_rem = remaining - pos_left; // remaining sum beyond the 1s of the remaining positives
            end else begin
              pos_rem = remaining - pos_left; // update the still-to-allocate positive sum
            end
          end else begin
            // Allocate as much as possible, but not exceeding n
            // This term's max possible value is n; we need total remaining to match n*pos_left when all are max
            // The sum remaining to allocate to the remaining positive terms is pos_rem; if pos_rem < n, we set this term to 1 + pos_rem, else to n
            if (pos_rem < n) begin
              solution[term_idx] = 16'd1 + pos_rem; // allocate all remaining positive budget here
              remaining = remaining - (16'd1 + pos_rem);
              pos_rem = 16'd0;
            end else begin
              solution[term_idx] = n;
              remaining = remaining - n;
              pos_rem = pos_rem - n;
            end
            pos_left = pos_left - 1;
            term_idx = term_idx + 1;
            terms_left = terms_left - 1;
          end
          // Continue with positive terms or move on
          if (pos_left > 0) begin
            next_state = POS;
          end else begin
            next_state = NEG;
          end
        end else begin
          next_state = NEG;
        end
      end

      NEG: begin
        // Allocate negative terms (all fixed to 1; they subtract from the total)
        if (neg_left > 0) begin
          solution[term_idx] = 16'd1;
          remaining = remaining - 16'd1; // will subtract; subtract by 1 now
          neg_left = neg_left - 1;
          term_idx = term_idx + 1;
          terms_left = terms_left - 1;
          next_state = NEG;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        done = 1'b1;
        possible = (remaining == 16'd0); // solvable iff exactly matched
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end
endmodule
