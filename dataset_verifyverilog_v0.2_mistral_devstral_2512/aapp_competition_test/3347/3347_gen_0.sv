module gold_stores (
  input clk,
  input rst_n,
  input start,
  input [7:0] valid_count,
  input [7:0][15:0] time_array,
  input [7:0][15:0] altitude_array,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SORT_PHASE,
    PROCESS_PHASE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers for sorting
  reg [15:0] sorted_time [0:7];
  reg [15:0] sorted_altitude [0:7];
  reg [2:0] sort_counter;
  reg [2:0] bubble_counter;
  reg [2:0] process_counter;
  reg [15:0] cumulative_time;
  reg [3:0] store_count;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      result <= 4'b0;
      sort_counter <= 3'b0;
      bubble_counter <= 3'b0;
      process_counter <= 3'b0;
      cumulative_time <= 16'b0;
      store_count <= 4'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SORT_PHASE;
          // Initialize sorted arrays
          for (int i = 0; i < 8; i++) begin
            sorted_time[i] = time_array[i];
            sorted_altitude[i] = altitude_array[i];
          end
          sort_counter = 3'b0;
          bubble_counter = 3'b0;
        end
      end

      SORT_PHASE: begin
        if (sort_counter < 7) begin
          if (bubble_counter < 7 - sort_counter) begin
            // Bubble sort comparison
            if (sorted_altitude[bubble_counter] > sorted_altitude[bubble_counter + 1]) begin
              // Swap elements
              reg [15:0] temp_time, temp_altitude;
              temp_time = sorted_time[bubble_counter];
              temp_altitude = sorted_altitude[bubble_counter];
              sorted_time[bubble_counter] = sorted_time[bubble_counter + 1];
              sorted_altitude[bubble_counter] = sorted_altitude[bubble_counter + 1];
              sorted_time[bubble_counter + 1] = temp_time;
              sorted_altitude[bubble_counter + 1] = temp_altitude;
            end
            bubble_counter = bubble_counter + 1;
          end else begin
            sort_counter = sort_counter + 1;
            bubble_counter = 3'b0;
          end
        end else begin
          next_state = PROCESS_PHASE;
        end
      end

      PROCESS_PHASE: begin
        if (process_counter < 8) begin
          cumulative_time = cumulative_time + sorted_time[process_counter];
          process_counter = process_counter + 1;
        end else begin
          result = store_count;
          done = 1'b1;
          next_state = DONE;
        end
      end

      DONE: begin
        // Do nothing
      end
    endcase
  end
endmodule