module min_uw_distance(
  input clk,
  input rst_n,
  input start,
  input [7:0] gravity [0:7],
  input [7:0] system_type,
  input [7:0][7:0] adjacency_matrix,
  output reg [23:0] min_distance,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_PREP_PAIR = 3'd2,
    S_PIPE1     = 3'd3,
    S_PIPE2     = 3'd4,
    S_PIPE3     = 3'd5,
    S_NEXT      = 3'd6,
    S_DONE      = 3'd7
  } state_t;

  state_t state, next_state;

  // Indices and counters
  reg [3:0] option_idx;      // 0..8 (9 options)
  reg [3:0] human_idx;       // 0..7
  reg [3:0] alien_idx;       // 0..7

  // Flags for valid pairs
  reg has_pair;              // at least one human-alien pair seen overall
  reg cur_pair_valid;        // current pair-based operation valid

  // Latched info for current pair
  reg [7:0] g_h_base, g_a_base;

  // Pipeline registers for cube computation
  // Stage1
  reg [7:0] g_h_s1, g_a_s1;
  reg       valid_s1;

  // Stage2: square and form 24-bit products
  reg [23:0] cube_h_s2, cube_a_s2;
  reg       valid_s2;

  // Stage3: absolute difference
  reg [23:0] diff_s3;
  reg       valid_s3;

  // Helper: compute adjusted gravity for any node index
  function automatic [7:0] get_adj_gravity(
    input [3:0] n,
    input [3:0] opt
  );
    reg [7:0] base_g;
    reg [7:0] res;
    reg is_self;
    reg is_neighbor;
    integer k;
  begin
    base_g = gravity[n];
    res = base_g;
    if (opt != 4'd0) begin
      is_self = (n == opt - 4'd1);
      is_neighbor = 1'b0;
      // neighbor: adjacency_matrix[opt-1][n] == 1
      // direct index; no loop needed, but use generic form
      if (adjacency_matrix[opt-1][n]) begin
        is_neighbor = 1'b1;
      end
      if (is_self) begin
        res = base_g - 8'd1;
      end else if (is_neighbor) begin
        res = base_g + 8'd1;
      end
    end
    get_adj_gravity = res;
  end
  endfunction

  // Next-state logic and control of pair iteration
  always @(*) begin
    next_state = state;
    cur_pair_valid = 1'b0;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_INIT;
        end
      end

      S_INIT: begin
        // Move to pair preparation if any pair exists attempt
        next_state = S_PREP_PAIR;
      end

      S_PREP_PAIR: begin
        // Determine if current (human_idx, alien_idx) is valid
        if (option_idx < 4'd9) begin
          if (human_idx < 4'd8 && alien_idx < 4'd8 &&
              (system_type[human_idx] == 1'b0) &&
              (system_type[alien_idx] == 1'b1)) begin
            // Valid human-alien pair
            cur_pair_valid = 1'b1;
            next_state = S_PIPE1;
          end else begin
            // Not a valid pair, advance indices without using pipeline
            next_state = S_NEXT;
          end
        end else begin
          // All options processed
          next_state = S_DONE;
        end
      end

      S_PIPE1: begin
        next_state = S_PIPE2;
      end

      S_PIPE2: begin
        next_state = S_PIPE3;
      end

      S_PIPE3: begin
        next_state = S_NEXT;
      end

      S_NEXT: begin
        // Advance to next pair/option or done
        if (option_idx < 4'd9) begin
          next_state = S_PREP_PAIR;
        end else begin
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        // Remain done until start deasserted then go idle
        if (!start)
          next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      option_idx   <= 4'd0;
      human_idx    <= 4'd0;
      alien_idx    <= 4'd0;
      min_distance <= 24'hFFFFFF;
      done         <= 1'b0;
      has_pair     <= 1'b0;
      // pipeline clears
      g_h_s1       <= 8'd0;
      g_a_s1       <= 8'd0;
      valid_s1     <= 1'b0;
      cube_h_s2    <= 24'd0;
      cube_a_s2    <= 24'd0;
      valid_s2     <= 1'b0;
      diff_s3      <= 24'd0;
      valid_s3     <= 1'b0;
    end else begin
      state <= next_state;

      // Default pipeline valid shift low unless set in state machine
      if (state != S_PIPE1)
        valid_s1 <= 1'b0;
      if (state != S_PIPE2)
        valid_s2 <= 1'b0;
      if (state != S_PIPE3)
        valid_s3 <= 1'b0;

      case (state)

        S_IDLE: begin
          done       <= 1'b0;
          // Wait for start; keep values as is
        end

        S_INIT: begin
          // Initialize for new full computation
          option_idx   <= 4'd0;
          human_idx    <= 4'd0;
          alien_idx    <= 4'd0;
          min_distance <= 24'hFFFFFF;
          has_pair     <= 1'b0;
          done         <= 1'b0;
        end

        S_PREP_PAIR: begin
          done <= 1'b0;
          if (option_idx < 4'd9) begin
            if (human_idx < 4'd8 && alien_idx < 4'd8 &&
                (system_type[human_idx] == 1'b0) &&
                (system_type[alien_idx] == 1'b1)) begin
              // Setup pipeline inputs for valid pair
              g_h_base <= get_adj_gravity(human_idx, option_idx);
              g_a_base <= get_adj_gravity(alien_idx, option_idx);
            end
          end
        end

        S_PIPE1: begin
          // Latch stage1 values
          g_h_s1   <= g_h_base;
          g_a_s1   <= g_a_base;
          valid_s1 <= 1'b1;
        end

        S_PIPE2: begin
          if (valid_s1) begin
            // Compute cubes within 24-bit range
            // cube = g * g * g, all intermediate kept 24-bit
            cube_h_s2 <= (g_h_s1 * g_h_s1) * g_h_s1;
            cube_a_s2 <= (g_a_s1 * g_a_s1) * g_a_s1;
            valid_s2  <= 1'b1;
          end
        end

        S_PIPE3: begin
          if (valid_s2) begin
            if (cube_a_s2 >= cube_h_s2)
              diff_s3 <= cube_a_s2 - cube_h_s2;
            else
              diff_s3 <= cube_h_s2 - cube_a_s2;
            valid_s3 <= 1'b1;
          end
        end

        S_NEXT: begin
          // If we just completed a valid pipeline result, update min
          if (valid_s3) begin
            has_pair <= 1'b1;
            if (diff_s3 < min_distance)
              min_distance <= diff_s3;
          end

          // Advance pair indices
          if (alien_idx < 4'd7) begin
            alien_idx <= alien_idx + 4'd1;
          end else begin
            alien_idx <= 4'd0;
            if (human_idx < 4'd7) begin
              human_idx <= human_idx + 4'd1;
            end else begin
              // Completed all pairs for this option, move to next option
              human_idx  <= 4'd0;
              alien_idx  <= 4'd0;
              if (option_idx < 4'd9)
                option_idx <= option_idx + 4'd1;
            end
          end
        end

        S_DONE: begin
          // Finalize done; preserve min_distance
          done <= 1'b1;
        end

        default: begin
          // Safety
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule