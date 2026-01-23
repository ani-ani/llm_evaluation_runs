module odometer_verifier (
  input clk,
  input rst_n,
  input start,
  input [7:0] num_entries,
  input [7:0] entry_year,
  input [3:0] entry_month,
  input [31:0] entry_odometer,
  input entry_valid,
  output reg [1:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    READ_ENTRY,
    CHECK_INTERVAL,
    VERDICT
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] entry_count;
  reg [7:0] prev_year;
  reg [3:0] prev_month;
  reg [31:0] prev_odometer;
  reg [31:0] total_months_since_service;
  reg [31:0] max_distance_since_service;
  reg service_violation;
  reg tamper_flag;
  reg first_entry;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      entry_count <= 0;
      prev_year <= 0;
      prev_month <= 0;
      prev_odometer <= 0;
      total_months_since_service <= 0;
      max_distance_since_service <= 0;
      service_violation <= 0;
      tamper_flag <= 0;
      first_entry <= 1;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = READ_ENTRY;
          entry_count = 0;
          first_entry = 1;
          service_violation = 0;
          tamper_flag = 0;
        end
      end
      READ_ENTRY: begin
        if (entry_valid) begin
          next_state = CHECK_INTERVAL;
        end
      end
      CHECK_INTERVAL: begin
        next_state = READ_ENTRY;
        if (entry_count == num_entries - 1) begin
          next_state = VERDICT;
        end
      end
      VERDICT: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else begin
      case (current_state)
        READ_ENTRY: begin
          if (entry_valid) begin
            if (!first_entry) begin
              // Calculate month difference
              reg [31:0] year_diff = entry_year - prev_year;
              reg [31:0] month_diff = entry_month - prev_month;
              reg [31:0] total_months = (year_diff * 12) + month_diff;

              // Calculate odometer difference with rollover handling
              reg [31:0] current_odo = entry_odometer;
              reg [31:0] prev_odo = prev_odometer;
              reg [31:0] distance;

              if (current_odo < prev_odo) begin
                distance = current_odo + 100000 - prev_odo;
              end else begin
                distance = current_odo - prev_odo;
              end

              // Check for tampering (distance per month out of range)
              if (total_months > 0) begin
                reg [31:0] distance_per_month = distance / total_months;
                if (distance_per_month < 2000 || distance_per_month > 20000) begin
                  tamper_flag = 1;
                end
              end else begin
                // Same month - odometer must not decrease
                if (current_odo < prev_odo) begin
                  tamper_flag = 1;
                end
              end

              // Check service rules
              if (distance > 30000 || total_months > 12) begin
                service_violation = 1;
              end

              // Update tracking variables
              total_months_since_service = total_months_since_service + total_months;
              if (distance > max_distance_since_service) begin
                max_distance_since_service = distance;
              end
            end

            // Store current entry as previous for next iteration
            prev_year = entry_year;
            prev_month = entry_month;
            prev_odometer = entry_odometer;
            first_entry = 0;
            entry_count = entry_count + 1;
          end
        end
        VERDICT: begin
          // Determine final result
          if (tamper_flag) begin
            result = 2'b10; // Tampered odometer
          end else if (service_violation) begin
            result = 2'b01; // Insufficient service
          end else begin
            result = 2'b00; // Seems legit
          end
          done = 1;
        end
        default: ;
      endcase
    end
  end

  // Done signal reset
  always @(posedge clk) begin
    if (current_state == IDLE && !start) begin
      done <= 0;
    end
  end

endmodule