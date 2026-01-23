module courier_partition (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_customers,
  input [9:0] customer_x [0:7],
  input [9:0] customer_y [0:7],
  output reg [9:0] min_max_diameter,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT_PARTITION,
    COMPUTE_DIAMETER_1,
    COMPUTE_DIAMETER_2,
    UPDATE_MIN,
    NEXT_PARTITION,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] partition; // Current partition being evaluated
  reg [9:0] current_max_diameter; // Current max diameter for this partition
  reg [9:0] diameter_group1; // Diameter of group 1
  reg [9:0] diameter_group2; // Diameter of group 2
  reg [9:0] best_result; // Best result found so far

  reg [3:0] i, j; // Loop counters for pairwise distance calculation
  reg [3:0] partition_counter; // Counter for partition enumeration

  reg [9:0] x1, y1, x2, y2; // Temporary storage for coordinates
  reg [9:0] distance; // Temporary distance calculation

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_max_diameter <= 0;
      partition <= 0;
      current_max_diameter <= 0;
      diameter_group1 <= 0;
      diameter_group2 <= 0;
      best_result <= 0;
      i <= 0;
      j <= 0;
      partition_counter <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_PARTITION;
      end
      INIT_PARTITION: begin
        next_state = COMPUTE_DIAMETER_1;
      end
      COMPUTE_DIAMETER_1: begin
        if (i == num_customers - 1 && j == num_customers - 1) begin
          next_state = COMPUTE_DIAMETER_2;
        end
      end
      COMPUTE_DIAMETER_2: begin
        if (i == num_customers - 1 && j == num_customers - 1) begin
          next_state = UPDATE_MIN;
        end
      end
      UPDATE_MIN: begin
        next_state = NEXT_PARTITION;
      end
      NEXT_PARTITION: begin
        if (partition_counter == (1 << num_customers) - 1) begin
          next_state = DONE;
        end else begin
          next_state = INIT_PARTITION;
        end
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
      // Reset all registers
      partition <= 0;
      current_max_diameter <= 0;
      diameter_group1 <= 0;
      diameter_group2 <= 0;
      best_result <= 0;
      i <= 0;
      j <= 0;
      partition_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          // No operation in IDLE
        end
        INIT_PARTITION: begin
          partition <= partition_counter;
          diameter_group1 <= 0;
          diameter_group2 <= 0;
          i <= 0;
          j <= 0;
        end
        COMPUTE_DIAMETER_1: begin
          // Compute diameter for group 1 (partition bit = 1)
          if (partition[i] && partition[j] && i != j) begin
            x1 <= customer_x[i];
            y1 <= customer_y[i];
            x2 <= customer_x[j];
            y2 <= customer_y[j];
            distance <= (x1 > x2) ? (x1 - x2) : (x2 - x1);
            distance <= distance + ((y1 > y2) ? (y1 - y2) : (y2 - y1));
            if (distance > diameter_group1) begin
              diameter_group1 <= distance;
            end
          end
          // Update counters
          if (j == num_customers - 1) begin
            j <= 0;
            if (i == num_customers - 1) begin
              i <= 0;
            end else begin
              i <= i + 1;
            end
          end else begin
            j <= j + 1;
          end
        end
        COMPUTE_DIAMETER_2: begin
          // Compute diameter for group 2 (partition bit = 0)
          if (!partition[i] && !partition[j] && i != j) begin
            x1 <= customer_x[i];
            y1 <= customer_y[i];
            x2 <= customer_x[j];
            y2 <= customer_y[j];
            distance <= (x1 > x2) ? (x1 - x2) : (x2 - x1);
            distance <= distance + ((y1 > y2) ? (y1 - y2) : (y2 - y1));
            if (distance > diameter_group2) begin
              diameter_group2 <= distance;
            end
          end
          // Update counters
          if (j == num_customers - 1) begin
            j <= 0;
            if (i == num_customers - 1) begin
              i <= 0;
            end else begin
              i <= i + 1;
            end
          end else begin
            j <= j + 1;
          end
        end
        UPDATE_MIN: begin
          // Determine the maximum diameter for this partition
          current_max_diameter <= (diameter_group1 > diameter_group2) ? diameter_group1 : diameter_group2;
          // Update best result if current is better
          if (best_result == 0 || current_max_diameter < best_result) begin
            best_result <= current_max_diameter;
          end
        end
        NEXT_PARTITION: begin
          partition_counter <= partition_counter + 1;
        end
        DONE: begin
          min_max_diameter <= best_result;
          done <= 1;
        end
        default: ;
      endcase
    end
  end

endmodule