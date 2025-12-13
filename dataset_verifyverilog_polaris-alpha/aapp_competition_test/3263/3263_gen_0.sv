module fluttershy_scheduler(
  input clk,
  input rst_n,
  input start,
  output reg [2:0] max_customers,
  output reg done
);

  // State encoding
  localparam IDLE         = 3'd0;
  localparam CHECK        = 3'd1;
  localparam REMOVE_START = 3'd2;
  localparam REMOVE_WAIT  = 3'd3;
  localparam PUT_START    = 3'd4;
  localparam PUT_WAIT     = 3'd5;
  localparam DONE_STATE   = 3'd6;

  // Parameters
  // P_time: put times for clothing types 1 and 2
  localparam [7:0] P_TIME_0 = 8'h0A; // 10
  localparam [7:0] P_TIME_1 = 8'h14; // 20

  // R_time: remove times for clothing types 1 and 2 (both 5)
  localparam [7:0] R_TIME_0 = 8'h05; // 5
  localparam [7:0] R_TIME_1 = 8'h05; // 5

  // Customer clothing types (2 bits each)
  // Customer 0: type 2, time 20
  // Customer 1: type 1, time 30
  // Customer 2: type 1, time 32
  // Customer 3: type 2, time 120
  localparam [1:0] C0_TYPE = 2'b10;
  localparam [1:0] C1_TYPE = 2'b01;
  localparam [1:0] C2_TYPE = 2'b01;
  localparam [1:0] C3_TYPE = 2'b10;

  // Customer arrival times
  localparam [15:0] C0_TIME = 16'h0014; // 20
  localparam [15:0] C1_TIME = 16'h001E; // 30
  localparam [15:0] C2_TIME = 16'h0020; // 32
  localparam [15:0] C3_TIME = 16'h0078; // 120

  // Internal registers
  reg [2:0] state, next_state;
  reg [1:0] current_clothing;     // 0 = none, 1 or 2 = clothing types
  reg [15:0] current_time;
  reg [1:0] customer_idx;         // 0..3
  reg [2:0] count;                // served customers count
  reg [15:0] wait_counter;        // for timing waits

  reg [1:0] needed_clothing;
  reg [15:0] arrival_time;
  reg [7:0] remove_time;
  reg [7:0] put_time;
  reg [15:0] total_change_time;

  // Combinational: select current customer info
  always @(*) begin
    case (customer_idx)
      2'd0: begin
        needed_clothing = C0_TYPE;
        arrival_time    = C0_TIME;
      end
      2'd1: begin
        needed_clothing = C1_TYPE;
        arrival_time    = C1_TIME;
      end
      2'd2: begin
        needed_clothing = C2_TYPE;
        arrival_time    = C2_TIME;
      end
      default: begin
        needed_clothing = C3_TYPE;
        arrival_time    = C3_TIME;
      end
    endcase
  end

  // Combinational: choose remove/put times based on clothing types
  always @(*) begin
    // remove time depends on current clothing (if not 0)
    case (current_clothing)
      2'b01: remove_time = R_TIME_0;
      2'b10: remove_time = R_TIME_1;
      default: remove_time = 8'd0; // none to remove
    endcase

    // put time depends on needed clothing
    case (needed_clothing)
      2'b01: put_time = P_TIME_0;
      2'b10: put_time = P_TIME_1;
      default: put_time = 8'd0; // should not be 0 for valid customers
    endcase

    total_change_time = remove_time + put_time;
  end

  // Sequential state and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      max_customers   <= 3'd0;
      done            <= 1'b0;
      current_clothing<= 2'b00;
      current_time    <= 16'd0;
      customer_idx    <= 2'd0;
      count           <= 3'd0;
      wait_counter    <= 16'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done          <= 1'b0;
          if (start) begin
            // Initialize simulation
            current_clothing <= 2'b00; // none
            current_time     <= 16'd0;
            customer_idx     <= 2'd0;
            count            <= 3'd0;
            max_customers    <= 3'd0;
            wait_counter     <= 16'd0;
          end
        end

        CHECK: begin
          // If all customers processed, move to DONE in next_state logic
          // Align current_time to arrival if we are before arrival
          if (current_time < arrival_time)
            current_time <= arrival_time;
          else
            current_time <= current_time; // hold

          if (customer_idx < 2'd4) begin
            if (needed_clothing == current_clothing) begin
              // Clothing matches, serve immediately
              count        <= count + 3'd1;
              customer_idx <= customer_idx + 2'd1;
              // current_time is arrival_time already or later; serving is immediate
            end else begin
              // Need clothing change; check feasibility
              if (current_time + total_change_time <= arrival_time) begin
                // Start change at (arrival_time - total_change_time)
                // Set up wait for remove
                current_time <= arrival_time - total_change_time;
                wait_counter <= remove_time;
              end
            end
          end
        end

        REMOVE_START: begin
          // wait_counter already loaded in CHECK when feasible
          // Transition handled in next_state; nothing extra here
        end

        REMOVE_WAIT: begin
          if (wait_counter > 0)
            wait_counter <= wait_counter - 16'd1;
          if (wait_counter == 16'd1) begin
            // Next cycle becomes 0 -> removal complete
            current_clothing <= 2'b00;
          end
        end

        PUT_START: begin
          // Load wait for put time
          // wait_counter loaded in next_state logic
        end

        PUT_WAIT: begin
          if (wait_counter > 0)
            wait_counter <= wait_counter - 16'd1;
          if (wait_counter == 16'd1) begin
            // Putting complete next cycle
            current_clothing <= needed_clothing;
            // At completion, time should align with arrival_time
            current_time <= arrival_time;
            // Serve customer immediately
            count        <= count + 3'd1;
            customer_idx <= customer_idx + 2'd1;
          end
        end

        DONE_STATE: begin
          done          <= 1'b1;
          max_customers <= count;
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK;
      end

      CHECK: begin
        if (customer_idx == 2'd4) begin
          next_state = DONE_STATE;
        end else begin
          if (needed_clothing == current_clothing) begin
            // Served immediately; continue checking next customer
            next_state = CHECK;
          end else begin
            // Need to change clothing
            if (current_time + total_change_time <= arrival_time) begin
              // Schedule remove
              next_state = REMOVE_START;
            end else begin
              // Not enough time to change -> skip this customer
              if (customer_idx == 2'd3)
                next_state = DONE_STATE;
              else
                next_state = CHECK;
            end
          end
        end
      end

      REMOVE_START: begin
        // After setup, go to REMOVE_WAIT
        next_state = REMOVE_WAIT;
      end

      REMOVE_WAIT: begin
        if (wait_counter == 16'd0) begin
          // Removal finished; setup put
          next_state = PUT_START;
        end else begin
          next_state = REMOVE_WAIT;
        end
      end

      PUT_START: begin
        // Load wait_counter with put_time, then go to PUT_WAIT
        next_state = PUT_WAIT;
      end

      PUT_WAIT: begin
        if (wait_counter == 16'd0) begin
          // Putting finished, customer served in seq block
          if (customer_idx == 2'd4)
            next_state = DONE_STATE;
          else
            next_state = CHECK;
        end else begin
          next_state = PUT_WAIT;
        end
      end

      DONE_STATE: begin
        // Hold done high until next start
        if (start)
          next_state = CHECK;
        else
          next_state = DONE_STATE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Control loading of wait_counter in specific states
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wait_counter <= 16'd0;
    end else begin
      if (state == REMOVE_START) begin
        wait_counter <= remove_time;
      end else if (state == PUT_START) begin
        wait_counter <= put_time;
      end
    end
  end

endmodule