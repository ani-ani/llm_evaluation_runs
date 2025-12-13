module digit_product_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] B,
  input [15:0] N,
  output reg [31:0] X,
  output reg impossible,
  output reg done
);

  // State encoding
  localparam S_IDLE       = 3'd0;
  localparam S_INIT       = 3'd1;
  localparam S_FACT_DIGIT = 3'd2;
  localparam S_CHECK_IMP  = 3'd3;
  localparam S_SORT       = 3'd4;
  localparam S_BUILD      = 3'd5;
  localparam S_DONE       = 3'd6;

  reg [2:0] state, next_state;

  // Internal registers
  reg [15:0] remN;                // remaining N during factorization
  reg [4:0] digits[0:15];         // up to 16 digits (each up to 15)
  reg [4:0] digit_count;          // number of used digits

  reg [4:0] cur_digit;            // current digit candidate in factorization
  reg [4:0] cur_idx;              // generic index (sorting/build)
  reg [4:0] cmp_idx;              // compare index for sorting

  reg [4:0] min_idx;              // for selection sort
  reg [4:0] min_digit;            // for selection sort

  reg [31:0] build_value;         // building X in base-10

  reg start_d;                    // registered start to detect rising edge

  wire start_pulse = start & ~start_d;

  // Sequential state and flops
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      start_d     <= 1'b0;

      remN        <= 16'd0;
      digit_count <= 5'd0;
      cur_digit   <= 5'd0;
      cur_idx     <= 5'd0;
      cmp_idx     <= 5'd0;
      min_idx     <= 5'd0;
      min_digit   <= 5'd0;
      build_value <= 32'd0;

      X           <= 32'd0;
      impossible  <= 1'b0;
      done        <= 1'b0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          impossible <= 1'b0;
          if (start_pulse) begin
            remN        <= N;
            digit_count <= 5'd0;
            cur_digit   <= (B > 4'd1) ? (B - 4'd1) : 5'd1; // safe init
            cur_idx     <= 5'd0;
            cmp_idx     <= 5'd0;
            min_idx     <= 5'd0;
            min_digit   <= 5'd0;
            build_value <= 32'd0;
          end
        end

        S_INIT: begin
          // Initialization already largely done in S_IDLE on start_pulse
          // Just ensure digit_count cleared (in case of transition corner)
          digit_count <= 5'd0;
          // Ensure starting digit is B-1 (>=2) for factorization
          if (B > 4'd1)
            cur_digit <= B - 4'd1;
          else
            cur_digit <= 5'd1;
        end

        S_FACT_DIGIT: begin
          // Factorization: successive division from cur_digit down to 2
          if (cur_digit >= 5'd2 && cur_digit < B) begin
            if (cur_digit != 5'd0 && (remN % cur_digit) == 16'd0 && remN != 16'd1) begin
              // Take this factor as a digit
              remN <= remN / cur_digit;
              if (digit_count < 5'd16) begin
                digits[digit_count] <= cur_digit[4:0];
                digit_count <= digit_count + 5'd1;
              end
              // Stay on same cur_digit to factor more
            end else begin
              // Move to next smaller digit or stop
              if (cur_digit > 5'd2)
                cur_digit <= cur_digit - 5'd1;
              else
                cur_digit <= 5'd1; // indicates finished trying digits
            end
          end else begin
            // cur_digit < 2 or cur_digit >= B: end factorization
            cur_digit <= 5'd1; // mark done
          end
        end

        S_CHECK_IMP: begin
          // After factorization attempts, decide if impossible or proceed
          if (N == 16'd1) begin
            // Special: product 1 -> smallest X is digit '1'
            digit_count <= 5'd1;
            digits[0]   <= 5'd1;
          end
        end

        S_SORT: begin
          // Selection sort (ascending) over digits[0..digit_count-1]
          if (digit_count <= 5'd1) begin
            // nothing to sort
          end else begin
            if (cur_idx < digit_count - 5'd1) begin
              if (cmp_idx == 5'd0) begin
                // start new pass
                min_idx   <= cur_idx;
                min_digit <= digits[cur_idx];
                cmp_idx   <= cur_idx + 5'd1;
              end else if (cmp_idx < digit_count) begin
                if (digits[cmp_idx] < min_digit) begin
                  min_digit <= digits[cmp_idx];
                  min_idx   <= cmp_idx;
                end
                cmp_idx <= cmp_idx + 5'd1;
              end else begin
                // swap digits[cur_idx] and digits[min_idx]
                if (min_idx != cur_idx) begin
                  reg [4:0] tmp;
                  tmp                 <= digits[cur_idx];
                  digits[cur_idx]     <= digits[min_idx];
                  digits[min_idx]     <= tmp;
                end
                // next outer index
                cur_idx <= cur_idx + 5'd1;
                cmp_idx <= 5'd0;
              end
            end
          end
        end

        S_BUILD: begin
          // Build final value X from sorted digits as base-B digits
          if (digit_count == 5'd0) begin
            build_value <= 32'd0;
          end else begin
            if (cur_idx == 5'd0) begin
              // initialize
              build_value <= 32'd0;
              cur_idx     <= 5'd0;
            end
            if (cur_idx < digit_count) begin
              // X = X * B + digits[cur_idx]
              build_value <= build_value * B + digits[cur_idx];
              cur_idx     <= cur_idx + 5'd1;
            end
          end
        end

        S_DONE: begin
          // Latch outputs
          X    <= build_value;
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start_pulse)
          next_state = S_INIT;
      end

      S_INIT: begin
        // Directly proceed to factorization
        next_state = S_FACT_DIGIT;
      end

      S_FACT_DIGIT: begin
        // When cur_digit hit marker (1) and no further division possible
        if (cur_digit == 5'd1) begin
          next_state = S_CHECK_IMP;
        end
      end

      S_CHECK_IMP: begin
        // Evaluate conditions for impossible or proceed
        if (N == 16'd0) begin
          // N=0 not in spec (1-65535), treat as impossible
          next_state = S_DONE;
        end else if (N == 16'd1) begin
          // Special handled in seq: one digit '1'
          next_state = S_SORT;
        end else begin
          // Check if factorization finished correctly: remN must be 1
          // and we must have some digits (or N==1 case already handled)
          if (remN != 16'd1 || digit_count == 5'd0) begin
            next_state = S_DONE;
          end else begin
            next_state = S_SORT;
          end
        end
      end

      S_SORT: begin
        // When sorting done, go to build
        if (digit_count <= 5'd1) begin
          next_state = S_BUILD;
        end else begin
          if (cur_idx >= digit_count - 5'd1 && cmp_idx == 5'd0)
            next_state = S_BUILD;
        end
      end

      S_BUILD: begin
        // When build completes
        if (digit_count == 5'd0) begin
          next_state = S_DONE;
        end else if (cur_idx >= digit_count) begin
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        // Determine impossible flag here based on conditions
        // On next clock, if start_pulse occurs, go back; else wait
        if (start_pulse)
          next_state = S_INIT;
        else
          next_state = S_DONE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Combinational control for impossible flag and X in DONE state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      impossible <= 1'b0;
      X          <= 32'd0;
    end else begin
      if (state == S_CHECK_IMP) begin
        // Decide preliminary impossibility
        if (N == 16'd0) begin
          impossible <= 1'b1;
          X          <= 32'd0;
        end else if (N != 16'd1 && (remN != 16'd1 || digit_count == 5'd0)) begin
          // Not fully factorized or no digits obtained
          impossible <= 1'b1;
          X          <= 32'd0;
        end else if (N == 16'd1) begin
          // Always possible: X=1
          impossible <= 1'b0;
        end else begin
          impossible <= 1'b0;
        end
      end
      if (state == S_DONE) begin
        if (impossible) begin
          X <= 32'd0;
        end else begin
          X <= build_value;
        end
      end
    end
  end

endmodule