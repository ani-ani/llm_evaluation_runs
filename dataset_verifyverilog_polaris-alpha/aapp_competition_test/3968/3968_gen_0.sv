module virus_spread_tracker(
  input clk,
  input rst_n,
  input start,
  input [1:0] days,
  input [7:0] initial_infected,
  input [15:0] s [0:7],
  input [15:0] t [0:7],
  output reg [7:0] infected_mask,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    INIT  = 2'b01,
    RUN   = 2'b10,
    FINAL = 2'b11
  } state_t;

  state_t state, next_state;

  reg [7:0] current_infected;
  reg [7:0] next_infected;

  reg [1:0] day_cnt;
  reg [1:0] days_latched;

  integer i, j;

  // Combinational: next_state and next_infected
  always @* begin
    // Default assignments
    next_state     = state;
    next_infected  = current_infected;

    case (state)
      IDLE: begin
        // Wait for start
        if (start) begin
          next_state = INIT;
        end
      end

      INIT: begin
        // Move to RUN to start day iterations
        next_state = RUN;
      end

      RUN: begin
        // Compute infections for this day based on current_infected
        next_infected = current_infected;
        for (i = 0; i < 8; i = i + 1) begin
          if (!current_infected[i]) begin
            // Check overlap with any infected person j
            for (j = 0; j < 8; j = j + 1) begin
              if (current_infected[j]) begin
                if (((s[i] <= t[j]) && (t[i] >= s[j])) ||
                    ((s[i] == t[i]) && (s[i] == s[j]))) begin
                  next_infected[i] = 1'b1;
                end
              end
            end
          end
        end

        // Decide next state based on day counter vs days_latched
        if (day_cnt == days_latched) begin
          // Completed required days; go to FINAL to present result
          next_state = FINAL;
        end else begin
          next_state = RUN;
        end
      end

      FINAL: begin
        // Hold result until a new start pulse
        if (start) begin
          next_state = INIT;
        end else begin
          next_state = FINAL;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential: state, counters, registers, outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      current_infected <= 8'b0;
      infected_mask    <= 8'b0;
      done             <= 1'b0;
      day_cnt          <= 2'b0;
      days_latched     <= 2'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch initial conditions on start
            current_infected <= initial_infected;
            day_cnt          <= 2'b0;
            days_latched     <= days;
          end
        end

        INIT: begin
          // Initialization complete; no infections updated here
          done <= 1'b0;
        end

        RUN: begin
          // Update infections and day counter
          current_infected <= next_infected;
          if (day_cnt != days_latched) begin
            day_cnt <= day_cnt + 2'b01;
          end
          done <= 1'b0;
        end

        FINAL: begin
          // Latch final infected mask and assert done
          infected_mask <= current_infected;
          done          <= 1'b1;
          if (start) begin
            // Prepare for a new computation when start is pulsed again
            current_infected <= initial_infected;
            day_cnt          <= 2'b0;
            days_latched     <= days;
            done             <= 1'b0;
          end
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule