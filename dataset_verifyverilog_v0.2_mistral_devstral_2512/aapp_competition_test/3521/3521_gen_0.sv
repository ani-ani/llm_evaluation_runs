module interstellar_optimizer #(
  parameter N = 8,
  parameter ANGLE_WIDTH = 8,
  parameter DATA_WIDTH = 16,
  parameter ACCUM_WIDTH = 24
)(
  input clk,
  input rst_n,
  input start,
  input [2:0] star_idx,
  input config_valid,
  input [DATA_WIDTH-1:0] config_T,
  input [DATA_WIDTH-1:0] config_s,
  input [ANGLE_WIDTH-1:0] config_a,
  output reg [ACCUM_WIDTH-1:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CONFIG,
    PREP_SORT,
    SORT,
    CALCULATE,
    DONE
  } state_t;
  state_t state, next_state;

  // Star configuration storage
  reg [DATA_WIDTH-1:0] T [0:N-1];
  reg [DATA_WIDTH-1:0] s [0:N-1];
  reg [ANGLE_WIDTH-1:0] a [0:N-1];

  // Event storage (3 events per star: peak, left zero, right zero)
  reg [ANGLE_WIDTH-1:0] event_angle [0:3*N-1];
  reg signed [ACCUM_WIDTH-1:0] event_delta_slope [0:3*N-1];
  reg [5:0] event_count;

  // Sorting variables
  reg [5:0] sort_i, sort_j, sort_min_idx;
  reg [ANGLE_WIDTH-1:0] sort_temp_angle;
  reg signed [ACCUM_WIDTH-1:0] sort_temp_delta;

  // Calculation variables
  reg [ANGLE_WIDTH-1:0] current_angle;
  reg signed [ACCUM_WIDTH-1:0] current_slope;
  reg [ACCUM_WIDTH-1:0] current_dist;
  reg [ACCUM_WIDTH-1:0] max_dist;
  reg [5:0] calc_idx;

  // Configuration counter
  reg [2:0] config_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      config_counter <= 0;
      event_count <= 0;
      sort_i <= 0;
      sort_j <= 0;
      sort_min_idx <= 0;
      calc_idx <= 0;
      current_angle <= 0;
      current_slope <= 0;
      current_dist <= 0;
      max_dist <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CONFIG;
      end
      CONFIG: begin
        if (config_counter == N-1 && config_valid) next_state = PREP_SORT;
      end
      PREP_SORT: next_state = SORT;
      SORT: begin
        if (sort_i == 3*N-1) next_state = CALCULATE;
      end
      CALCULATE: begin
        if (calc_idx == 3*N) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Configuration phase
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      config_counter <= 0;
    end else if (state == CONFIG && config_valid) begin
      T[star_idx] <= config_T;
      s[star_idx] <= config_s;
      a[star_idx] <= config_a;
      config_counter <= config_counter + 1;
    end
  end

  // Event generation (computed during CONFIG state)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      event_count <= 0;
    end else if (state == CONFIG && config_valid) begin
      // Peak event
      event_angle[3*star_idx] <= a[star_idx];
      event_delta_slope[3*star_idx] <= 2 * s[star_idx];
      
      // Left zero event (a_i - T_i/s_i)
      // Handle wrap-around
      if (config_T > config_s * config_a) begin
        event_angle[3*star_idx + 1] <= (config_a + 256) - (config_T / config_s);
      end else begin
        event_angle[3*star_idx + 1] <= config_a - (config_T / config_s);
      end
      event_delta_slope[3*star_idx + 1] <= config_s;
      
      // Right zero event (a_i + T_i/s_i)
      if (config_a + (config_T / config_s) >= 256) begin
        event_angle[3*star_idx + 2] <= (config_a + (config_T / config_s)) - 256;
      end else begin
        event_angle[3*star_idx + 2] <= config_a + (config_T / config_s);
      end
      event_delta_slope[3*star_idx + 2] <= -config_s;
      
      event_count <= event_count + 3;
    end
  end

  // Sorting phase (simple selection sort)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_i <= 0;
      sort_j <= 0;
      sort_min_idx <= 0;
    end else if (state == SORT) begin
      if (sort_j == 3*N) begin
        sort_i <= sort_i + 1;
        sort_j <= sort_i + 1;
        sort_min_idx <= sort_i;
      end else if (event_angle[sort_j] < event_angle[sort_min_idx]) begin
        sort_min_idx <= sort_j;
        sort_j <= sort_j + 1;
      end else begin
        sort_j <= sort_j + 1;
      end
      
      // Swap if needed
      if (sort_j == 3*N && sort_min_idx != sort_i) begin
        sort_temp_angle <= event_angle[sort_i];
        sort_temp_delta <= event_delta_slope[sort_i];
        event_angle[sort_i] <= event_angle[sort_min_idx];
        event_delta_slope[sort_i] <= event_delta_slope[sort_min_idx];
        event_angle[sort_min_idx] <= sort_temp_angle;
        event_delta_slope[sort_min_idx] <= sort_temp_delta;
      end
    end
  end

  // Calculation phase
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      calc_idx <= 0;
      current_angle <= 0;
      current_slope <= 0;
      current_dist <= 0;
      max_dist <= 0;
    end else if (state == CALCULATE) begin
      if (calc_idx == 0) begin
        current_angle <= event_angle[0];
        current_slope <= event_delta_slope[0];
        current_dist <= 0;
        max_dist <= 0;
        calc_idx <= calc_idx + 1;
      end else if (calc_idx < 3*N) begin
        // Calculate angle difference (handle wrap-around)
        reg signed [ANGLE_WIDTH:0] angle_diff;
        if (event_angle[calc_idx] >= current_angle) begin
          angle_diff <= event_angle[calc_idx] - current_angle;
        end else begin
          angle_diff <= (event_angle[calc_idx] + 256) - current_angle;
        end
        
        // Update current distance
        current_dist <= current_dist + current_slope * angle_diff;
        
        // Update max distance
        if (current_dist > max_dist) begin
          max_dist <= current_dist;
        end
        
        // Update current slope
        current_slope <= current_slope + event_delta_slope[calc_idx];
        current_angle <= event_angle[calc_idx];
        calc_idx <= calc_idx + 1;
      end
    end
  end

  // Output results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (state == DONE) begin
      result <= max_dist;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule