module media_companies (
  input clk,
  input rst_n,
  input start,
  input [3:0] k_min,
  input [3:0] c_min,
  input [7:0][3:0] sectors,
  output reg [3:0] max_companies,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    CHECK_RANGE,
    COUNT_COLORS,
    VALIDATE,
    SELECT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] start_pos; // Current starting position (0-7)
  reg [2:0] range_len; // Current range length (1-8)
  reg [3:0] color_count; // Count of distinct colors in current range
  reg [3:0] temp_companies; // Temporary count of valid companies
  reg [2:0] last_end; // End position of last selected range
  reg [3:0] window [0:7]; // Sliding window buffer
  reg [3:0] distinct_colors [0:15]; // Bitmask for distinct colors
  reg [3:0] i, j; // Loop counters
  reg valid_range; // Current range is valid
  reg [3:0] k_min_reg, c_min_reg; // Registered versions of inputs

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_companies <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State transition logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        next_state = CHECK_RANGE;
      end
      CHECK_RANGE: begin
        if (start_pos == 7) begin
          if (temp_companies > max_companies) begin
            max_companies = temp_companies;
          end
          next_state = DONE;
        end else begin
          next_state = COUNT_COLORS;
        end
      end
      COUNT_COLORS: begin
        next_state = VALIDATE;
      end
      VALIDATE: begin
        next_state = SELECT;
      end
      SELECT: begin
        next_state = CHECK_RANGE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_pos <= 0;
      range_len <= 0;
      color_count <= 0;
      temp_companies <= 0;
      last_end <= 0;
      valid_range <= 0;
      i <= 0;
      j <= 0;
      k_min_reg <= 0;
      c_min_reg <= 0;
      for (int k = 0; k < 8; k++) window[k] <= 0;
      for (int k = 0; k < 16; k++) distinct_colors[k] <= 0;
    end else begin
      case (current_state)
        INIT: begin
          k_min_reg <= k_min;
          c_min_reg <= c_min;
          start_pos <= 0;
          range_len <= k_min_reg;
          temp_companies <= 0;
          last_end <= 0;
          // Initialize window with circular buffer
          for (int k = 0; k < 8; k++) begin
            window[k] <= sectors[k];
          end
        end
        CHECK_RANGE: begin
          if (start_pos == 7) begin
            // Check if we need to wrap around
            if (start_pos + range_len > 8) begin
              // Handle circular case
              for (int k = 0; k < range_len; k++) begin
                if (start_pos + k < 8) begin
                  window[k] <= sectors[start_pos + k];
                end else begin
                  window[k] <= sectors[start_pos + k - 8];
                end
              end
            end else begin
              for (int k = 0; k < range_len; k++) begin
                window[k] <= sectors[start_pos + k];
              end
            end
            start_pos <= start_pos + 1;
          end else begin
            start_pos <= 0;
            temp_companies <= 0;
            last_end <= 0;
          end
        end
        COUNT_COLORS: begin
          // Reset distinct colors tracking
          for (int k = 0; k < 16; k++) distinct_colors[k] <= 0;
          color_count <= 0;
          i <= 0;
          j <= 0;
        end
        VALIDATE: begin
          // Count distinct colors in window
          if (i < range_len) begin
            if (j < i) begin
              if (window[i] == window[j]) begin
                distinct_colors[window[i]] <= 1;
              end
              j <= j + 1;
            end else begin
              if (!distinct_colors[window[i]]) begin
                color_count <= color_count + 1;
                distinct_colors[window[i]] <= 1;
              end
              i <= i + 1;
              j <= 0;
            end
          end else begin
            valid_range <= (color_count >= c_min_reg);
          end
        end
        SELECT: begin
          if (valid_range && start_pos >= last_end + k_min_reg) begin
            temp_companies <= temp_companies + 1;
            last_end <= start_pos + range_len - 1;
          end
        end
        DONE: begin
          done <= 1;
        end
        default: ;
      endcase
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (current_state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule