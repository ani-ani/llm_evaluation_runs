module rarity_solver(
  input clk,
  input rst_n,
  input start,
  input [7:0] N,
  input [7:0] K,
  input [7:0] P,
  output reg [7:0] result_char,
  output reg valid,
  output reg done,
  output reg is_possible
);

  // Internal state machine
  typedef enum logic [2:0] {
    IDLE,
    CHECK_FEASIBILITY,
    GENERATE,
    OUTPUT
  } state_t;
  state_t state, next_state;

  // Internal buffer for the generated string
  reg [7:0] string_buffer [0:15];
  reg [3:0] buffer_index;
  reg [3:0] output_index;

  // Feasibility flag
  reg feasible;

  // Generation counters
  reg [3:0] gen_index;
  reg [3:0] block_count;
  reg current_char;
  reg [3:0] char_count;

  // Initialize
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      buffer_index <= 0;
      output_index <= 0;
      gen_index <= 0;
      block_count <= 0;
      char_count <= 0;
      current_char <= 0;
      feasible <= 0;
      valid <= 0;
      done <= 0;
      is_possible <= 0;
      result_char <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CHECK_FEASIBILITY;
      end
      CHECK_FEASIBILITY: begin
        next_state = GENERATE;
      end
      GENERATE: begin
        if (gen_index == N - 1) next_state = OUTPUT;
      end
      OUTPUT: begin
        if (output_index == N - 1) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Feasibility check
  always @(*) begin
    feasible = 1;
    if (N == 0 || K == 0 || P == 0) feasible = 0;
    else if (P == 1 && N > 1) feasible = 0;
    else if (K == 1 && P < N) feasible = 0;
    else if (K == 2 && P == 2 && N > 4) feasible = 0;
    else if (P > N) feasible = 0;
    else if (K > 4) feasible = 0;
    else if (N > 16) feasible = 0;
  end

  // Generation logic
  always @(*) begin
    if (state == GENERATE) begin
      if (P == N) begin
        // Palindrome construction
        if (gen_index <= (N - 1) / 2) begin
          string_buffer[gen_index] = 'a' + (gen_index % K);
        end else begin
          string_buffer[gen_index] = string_buffer[N - 1 - gen_index];
        end
      end else if (K >= 3) begin
        // Prefix: palindrome of length P
        if (gen_index < P) begin
          if (gen_index <= (P - 1) / 2) begin
            string_buffer[gen_index] = 'a' + (gen_index % K);
          end else begin
            string_buffer[gen_index] = string_buffer[P - 1 - gen_index];
          end
        end else begin
          // Suffix: cycle through 'a', 'b', 'c'
          string_buffer[gen_index] = 'a' + ((gen_index - P) % 3);
        end
      end else if (K == 2) begin
        // K=2 case
        if (P == 2) begin
          // Only possible if N <= 4
          if (gen_index < P) begin
            string_buffer[gen_index] = 'a';
          end else begin
            string_buffer[gen_index] = 'b';
          end
        end else begin
          // P >= 3
          if (gen_index < P) begin
            string_buffer[gen_index] = 'a';
          end else if (gen_index < 2 * P) begin
            string_buffer[gen_index] = 'b';
          end else begin
            // Alternate blocks of 'a' and 'b'
            if ((gen_index - 2 * P) % (2 * P) < P) begin
              string_buffer[gen_index] = 'a';
            end else begin
              string_buffer[gen_index] = 'b';
            end
          end
        end
      end
    end
  end

  // Output logic
  always @(*) begin
    valid = 0;
    done = 0;
    is_possible = feasible;
    result_char = 0;
    case (state)
      OUTPUT: begin
        if (output_index < N) begin
          result_char = string_buffer[output_index];
          valid = 1;
        end
        if (output_index == N - 1) begin
          done = 1;
        end
      end
      default: begin
        valid = 0;
        done = 0;
      end
    endcase
  end

  // Index management
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buffer_index <= 0;
      output_index <= 0;
      gen_index <= 0;
    end else begin
      case (state)
        GENERATE: begin
          if (gen_index < N - 1) gen_index <= gen_index + 1;
        end
        OUTPUT: begin
          if (output_index < N - 1) output_index <= output_index + 1;
        end
        default: begin
          buffer_index <= 0;
          output_index <= 0;
          gen_index <= 0;
        end
      endcase
    end
  end

endmodule