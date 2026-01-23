module permutation_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] a_i,
  input [2:0] index,
  output reg [7:0] pi_out,
  output reg [7:0] sigma_out,
  output reg [2:0] out_index,
  output reg found,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    SEARCH_0,
    SEARCH_1,
    SEARCH_2,
    SEARCH_3,
    SEARCH_4,
    SEARCH_5,
    SEARCH_6,
    SEARCH_7,
    CHECK,
    FOUND,
    IMPOSSIBLE,
    OUTPUT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] pi [0:7];
  reg [7:0] sigma [0:7];
  reg [7:0] used_pi;
  reg [7:0] used_sigma;
  reg [2:0] pos;
  reg [7:0] try_pi;
  reg [7:0] try_sigma;
  reg [2:0] output_counter;

  // Compute target modulo
  wire [2:0] target_mod = (a_i == 8) ? 0 : a_i[2:0];

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      pos <= 0;
      try_pi <= 0;
      try_sigma <= 0;
      output_counter <= 0;
      found <= 0;
      done <= 0;
      pi_out <= 0;
      sigma_out <= 0;
      out_index <= 0;
      used_pi <= 0;
      used_sigma <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            pos <= 0;
            try_pi <= 1;
            try_sigma <= 1;
            used_pi <= 0;
            used_sigma <= 0;
          end
        end

        SEARCH_0, SEARCH_1, SEARCH_2, SEARCH_3, SEARCH_4, SEARCH_5, SEARCH_6, SEARCH_7: begin
          if (next_state == SEARCH_0 + pos + 1) begin
            pos <= pos + 1;
            try_pi <= 1;
            try_sigma <= 1;
          end else if (next_state == SEARCH_0 + pos) begin
            try_pi <= try_pi + 1;
          end
        end

        CHECK: begin
          if (next_state == FOUND) begin
            output_counter <= 0;
          end
        end

        OUTPUT: begin
          if (next_state == OUTPUT) begin
            output_counter <= output_counter + 1;
          end
        end

        DONE: begin
          done <= 1;
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    found = 0;
    pi_out = 0;
    sigma_out = 0;
    out_index = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SEARCH_0;
        end
      end

      SEARCH_0, SEARCH_1, SEARCH_2, SEARCH_3, SEARCH_4, SEARCH_5, SEARCH_6, SEARCH_7: begin
        reg [7:0] p = try_pi;
        reg [7:0] s = try_sigma;
        reg valid = 0;

        // Try to find valid pair
        for (int i = 0; i < 8; i = i + 1) begin
          if (p > 8) begin
            p = 1;
            s = s + 1;
          end

          if (s > 8) begin
            // No valid pair found, backtrack
            next_state = (pos == 0) ? IMPOSSIBLE : (SEARCH_0 + pos - 1);
            break;
          end

          if (!used_pi[p] && !used_sigma[s] && ((p + s) % 8 == target_mod)) begin
            valid = 1;
            break;
          end

          p = p + 1;
        end

        if (valid) begin
          // Found valid pair, move to next position
          if (pos == 7) begin
            next_state = CHECK;
          end else begin
            next_state = SEARCH_0 + pos + 1;
          end
        end
      end

      CHECK: begin
        // Verify all positions are filled
        reg valid = 1;
        for (int i = 0; i < 8; i = i + 1) begin
          if (!used_pi[pi[i]] || !used_sigma[sigma[i]]) begin
            valid = 0;
            break;
          end
        end

        if (valid) begin
          next_state = FOUND;
        end else begin
          next_state = (pos == 0) ? IMPOSSIBLE : (SEARCH_0 + pos - 1);
        end
      end

      FOUND: begin
        next_state = OUTPUT;
        found = 1;
      end

      OUTPUT: begin
        if (output_counter < 7) begin
          next_state = OUTPUT;
          pi_out = pi[output_counter];
          sigma_out = sigma[output_counter];
          out_index = output_counter;
        end else begin
          next_state = DONE;
          pi_out = pi[7];
          sigma_out = sigma[7];
          out_index = 7;
        end
      end

      IMPOSSIBLE: begin
        next_state = DONE;
      end

      DONE: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Update internal arrays when moving to next state
  always @(posedge clk) begin
    if (current_state == SEARCH_0 + pos && next_state == SEARCH_0 + pos + 1) begin
      pi[pos] <= try_pi;
      sigma[pos] <= try_sigma;
      used_pi[try_pi] <= 1;
      used_sigma[try_sigma] <= 1;
    end else if (current_state == SEARCH_0 + pos && next_state == SEARCH_0 + pos - 1) begin
      // Backtrack: clear current position
      used_pi[pi[pos]] <= 0;
      used_sigma[sigma[pos]] <= 0;
    end
  end

endmodule