module lights_controller (
  input clk,
  input rst_n,
  input start,
  input [15:0] initial_states,
  input [4:0] a [15:0],
  input [4:0] b [15:0],
  output reg [4:0] max_lights,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Counters
  reg [5:0] time_counter;
  reg [3:0] light_index;

  // Temporary registers
  reg [15:0] current_light_states;
  reg [4:0] current_count;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      time_counter <= 0;
      light_index <= 0;
      current_light_states <= 0;
      current_count <= 0;
      max_lights <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            time_counter <= 0;
            light_index <= 0;
            current_light_states <= initial_states;
            current_count <= 0;
            max_lights <= 0;
            done <= 0;
          end
        end

        CALCULATING: begin
          if (light_index == 15) begin
            // All lights processed for current time
            if (current_count > max_lights) begin
              max_lights <= current_count;
            end

            if (time_counter == 63) begin
              // All times processed
              next_state <= DONE;
            end else begin
              // Move to next time
              time_counter <= time_counter + 1;
              light_index <= 0;
              current_count <= 0;
            end
          end else begin
            // Process current light
            reg light_toggle;
            reg [4:0] diff;

            // Check if light should toggle
            diff = time_counter - b[light_index];
            light_toggle = (time_counter >= b[light_index]) && (diff % a[light_index] == 0);

            if (light_toggle) begin
              current_light_states[light_index] <= ~current_light_states[light_index];
            end

            // Update count if light is on
            if (current_light_states[light_index]) begin
              current_count <= current_count + 1;
            end

            // Move to next light
            light_index <= light_index + 1;
          end
        end

        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CALCULATING;
        end
      end

      CALCULATING: begin
        if (time_counter == 63 && light_index == 15) begin
          next_state = DONE;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule