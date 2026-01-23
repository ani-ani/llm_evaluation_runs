module color_code_finder (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] p_count,
  input [3:0][3:0] palette,
  output reg [15:0] result_valid,
  output reg [3:0][3:0] next_value,
  output reg done,
  output reg impossible
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    DFS_START,
    DFS_STEP,
    CHECK_COMPLETE,
    FOUND,
    IMPOSSIBLE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [15:0] visited; // Bitmask for visited nodes (16 bits max)
  reg [3:0][3:0] path; // Path storage (16 elements max)
  reg [3:0] path_idx; // Current path index
  reg [3:0] bit_idx; // Current bit being tried
  reg [3:0] candidate; // Candidate value
  reg [3:0] output_idx; // Index for outputting sequence
  reg [3:0] hamming_dist; // Computed Hamming distance
  reg [3:0] palette_idx; // Index for palette checking
  reg palette_match; // Flag for palette match

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      visited <= 0;
      path_idx <= 0;
      bit_idx <= 0;
      candidate <= 0;
      output_idx <= 0;
      hamming_dist <= 0;
      palette_idx <= 0;
      palette_match <= 0;
      result_valid <= 0;
      done <= 0;
      impossible <= 0;
    end else begin
      state <= next_state;

      // State-specific register updates
      case (state)
        IDLE: begin
          if (start) begin
            visited <= 0;
            path_idx <= 0;
            bit_idx <= 0;
            candidate <= 0;
            output_idx <= 0;
            hamming_dist <= 0;
            palette_idx <= 0;
            palette_match <= 0;
            result_valid <= 0;
            done <= 0;
            impossible <= 0;
          end
        end

        INIT: begin
          visited <= 1 << 0; // Mark node 0 as visited
          path[0] <= 0; // Start with 0
          path_idx <= 0;
          bit_idx <= 0;
          candidate <= 0;
          output_idx <= 0;
          hamming_dist <= 0;
          palette_idx <= 0;
          palette_match <= 0;
        end

        DFS_START: begin
          bit_idx <= 0;
          candidate <= 0;
          hamming_dist <= 0;
          palette_idx <= 0;
          palette_match <= 0;
        end

        DFS_STEP: begin
          if (palette_match && !visited[candidate]) begin
            visited <= visited | (1 << candidate);
            path[path_idx + 1] <= candidate;
            path_idx <= path_idx + 1;
            bit_idx <= 0;
          end else begin
            bit_idx <= bit_idx + 1;
          end
        end

        CHECK_COMPLETE: begin
          if (path_idx == (1 << n) - 1) begin
            output_idx <= 0;
          end else begin
            path_idx <= path_idx - 1;
            visited <= visited & ~(1 << path[path_idx]);
            bit_idx <= bit_idx + 1;
          end
        end

        FOUND: begin
          output_idx <= output_idx + 1;
          if (output_idx == (1 << n) - 1) begin
            done <= 1;
          end
        end

        IMPOSSIBLE: begin
          impossible <= 1;
        end

        default: begin
          // Default case for safety
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end

      INIT: begin
        next_state = DFS_START;
      end

      DFS_START: begin
        next_state = DFS_STEP;
      end

      DFS_STEP: begin
        // Compute candidate and check conditions
        candidate = path[path_idx] ^ (1 << bit_idx);
        hamming_dist = $clog2(candidate ^ path[path_idx]);

        // Check if Hamming distance is in palette
        palette_match = 0;
        for (int i = 0; i < p_count; i++) begin
          if (palette[i] == hamming_dist) begin
            palette_match = 1;
            break;
          end
        end

        if (bit_idx == n - 1) begin
          if (path_idx == 0) begin
            next_state = IMPOSSIBLE;
          end else begin
            next_state = CHECK_COMPLETE;
          end
        end else if (palette_match && !visited[candidate]) begin
          next_state = DFS_START;
        end
      end

      CHECK_COMPLETE: begin
        if (path_idx == (1 << n) - 1) begin
          next_state = FOUND;
          result_valid = 1;
        end else if (bit_idx == n) begin
          if (path_idx == 0) begin
            next_state = IMPOSSIBLE;
          end else begin
            next_state = CHECK_COMPLETE;
          end
        end else begin
          next_state = DFS_STEP;
        end
      end

      FOUND: begin
        if (output_idx == (1 << n) - 1) begin
          next_state = IDLE;
        end
      end

      IMPOSSIBLE: begin
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output logic
  always @(*) begin
    case (state)
      FOUND: begin
        next_value = path[output_idx];
      end

      default: begin
        next_value = 0;
      end
    endcase
  end

endmodule