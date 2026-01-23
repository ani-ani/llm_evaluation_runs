module vacation_scheduler(
  input clk,
  input rst_n,
  input start,
  input [1:0] day_data,
  input [6:0] day_index,
  input data_valid,
  output reg [7:0] min_rest_days,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [6:0] day_count;
  reg [6:0] total_days;
  reg [1:0] day_buffer [0:99];
  reg [7:0] state_rest, state_contest, state_sport;
  reg [7:0] next_rest, next_contest, next_sport;
  reg [7:0] max_active;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      day_count <= 0;
      total_days <= 0;
      state_rest <= 0;
      state_contest <= 0;
      state_sport <= 0;
      min_rest_days <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            day_count <= 0;
            total_days <= 0;
            state_rest <= 0;
            state_contest <= 0;
            state_sport <= 0;
          end
        end

        LOAD: begin
          if (data_valid) begin
            day_buffer[day_index] <= day_data;
            if (day_index == 99) begin
              total_days <= 100;
            end else begin
              total_days <= day_index + 1;
            end
          end
        end

        COMPUTE: begin
          case (day_buffer[day_count])
            2'b00: begin
              next_rest <= 0;
              next_contest <= 0;
              next_sport <= 0;
            end

            2'b01: begin
              next_rest <= state_rest + 1;
              next_contest <= (state_rest > state_sport) ? state_rest + 1 : state_sport + 1;
              next_sport <= 0;
            end

            2'b02: begin
              next_rest <= state_rest + 1;
              next_contest <= 0;
              next_sport <= (state_rest > state_contest) ? state_rest + 1 : state_contest + 1;
            end

            2'b03: begin
              next_rest <= state_rest + 1;
              next_contest <= (state_rest > state_sport) ? state_rest + 1 : state_sport + 1;
              next_sport <= (state_rest > state_contest) ? state_rest + 1 : state_contest + 1;
            end
          endcase

          state_rest <= next_rest;
          state_contest <= next_contest;
          state_sport <= next_sport;

          if (day_count == total_days - 1) begin
            max_active <= (state_rest > state_contest) ? state_rest : state_contest;
            max_active <= (max_active > state_sport) ? max_active : state_sport;
            min_rest_days <= total_days - max_active;
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
        if (start) next_state = LOAD;
      end

      LOAD: begin
        if (data_valid && day_index == 99) next_state = COMPUTE;
      end

      COMPUTE: begin
        if (day_count == total_days - 1) next_state = DONE;
        else next_state = COMPUTE;
      end

      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Day count increment
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      day_count <= 0;
    end else begin
      case (current_state)
        LOAD: begin
          if (data_valid) day_count <= day_index + 1;
        end

        COMPUTE: begin
          if (day_count < total_days - 1) day_count <= day_count + 1;
        end
      endcase
    end
  end

endmodule