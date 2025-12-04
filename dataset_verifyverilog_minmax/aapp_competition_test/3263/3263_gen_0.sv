module fluttershy_scheduler(
  input clk,
  input rst_n,
  input start,
  output reg [2:0] max_customers,
  output reg done
);
  // States
  typedef enum logic [2:0] {
    IDLE         = 3'b000,
    CHECK        = 3'b001,
    REMOVE_START = 3'b010,
    REMOVE_WAIT  = 3'b011,
    PUT_START    = 3'b100,
    PUT_WAIT     = 3'b101,
    DONE         = 3'b110
  } state_t;

  state_t state, next_state;

  // Hardcoded parameters (N=4 customers, M=2 clothing types)
  localparam CUST_N = 4;
  localparam CLOTH_M = 2;
  localparam [7:0] P_TIME [0:CLOTH_M-1] = '{8'h0A, 8'h14}; // put times: 10, 20
  localparam [7:0] R_TIME [0:CLOTH_M-1] = '{8'h05, 8'h05}; // remove times: 5, 5
  localparam [1:0] CUST_TYPE [0:CUST_N-1] = '{2'b10, 2'b01, 2'b01, 2'b10};
  localparam [15:0] CUST_TIME [0:CUST_N-1] = '{16'h0014, 16'h001E, 16'h0020, 16'h0078};

  // Sequencer state
  reg [1:0] curr_cloth;   // 2'b00 = none, 2'b01, 2'b10 valid
  reg [15:0] curr_time;
  reg [2:0] count;
  reg [2:0] idx;          // 0..3
  reg [15:0] next_time;   // time to next arrival
  reg [7:0] time_to_next; // <= 255, enough for scaled times

  // Timers for remove/put
  reg [7:0] remove_cnt;
  reg [7:0] put_cnt;
  reg [1:0] target_cloth;
  reg [7:0] time_budget; // time left in current interval

  // Next-arrival combinatorial values
  wire [15:0] arr_time = CUST_TIME[idx];
  wire [15:0] next_arr_time = (idx + 1 < CUST_N) ? CUST_TIME[idx + 1] : 16'h0000;
  wire [15:0] time_left = (idx + 1 < CUST_N) ? (next_arr_time - curr_time) : 16'h0000;

  // Compute time required to change clothing from curr_cloth to required
  function [7:0] compute_change_time(input [1:0] from, input [1:0] to);
    if (from == to || from == 2'b00) begin
      // No current clothing, only put time (scaled)
      return P_TIME[to];
    end else begin
      return (R_TIME[from] + P_TIME[to]);
    end
  endfunction

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_customers <= 3'b000;
      curr_cloth <= 2'b00;
      curr_time <= 16'h0000;
      count <= 3'b000;
      idx <= 3'b000;
      next_time <= 16'h0000;
      time_to_next <= 8'h00;
      remove_cnt <= 8'h00;
      put_cnt <= 8'h00;
      target_cloth <= 2'b00;
      time_budget <= 8'h00;
    end else begin
      state <= next_state;

      // default keep values; updated in specific states
      curr_cloth <= curr_cloth;
      curr_time <= curr_time;
      count <= count;
      idx <= idx;
      next_time <= next_time;
      time_to_next <= time_to_next;
      remove_cnt <= remove_cnt;
      put_cnt <= put_cnt;
      target_cloth <= target_cloth;
      time_budget <= time_budget;
      done <= done; // default until DONE state

      case (next_state)
        IDLE: begin
          curr_cloth <= 2'b00;
          curr_time <= 16'h0000;
          count <= 3'b000;
          idx <= 3'b000;
          next_time <= CUST_TIME[0];
          time_to_next <= 8'h14; // 20
          remove_cnt <= 8'h00;
          put_cnt <= 8'h00;
          target_cloth <= 2'b00;
          time_budget <= 8'h00;
          done <= 1'b0;
        end

        CHECK: begin
          // On entry, curr_time, idx are set; time_to_next already computed at boundary
          // Advance time if needed
          if (time_to_next != 8'h00) begin
            curr_time <= curr_time + 1;
            time_to_next <= time_to_next - 1;
          end
          // If it's time to check this customer (time_to_next was 0 when CHECK started)
          if (time_to_next == 8'h00) begin
            if (CUST_TYPE[idx] == curr_cloth) begin
              // Immediate serve
              count <= count + 1;
            end
            // Determine time to next arrival (for the new curr_time)
            if (idx + 1 < CUST_N) begin
              next_time <= next_arr_time;
              time_to_next <= time_left[7:0]; // safe because differences are small (<= 255)
            end else begin
              next_time <= 16'h0000;
              time_to_next <= 8'h00;
            end
            // Prepare for next customer
            idx <= idx + 1;
          end
        end

        REMOVE_START: begin
          remove_cnt <= R_TIME[curr_cloth]; // start countdown
        end

        REMOVE_WAIT: begin
          if (remove_cnt > 0) begin
            remove_cnt <= remove_cnt - 1;
          end else begin
            curr_cloth <= 2'b00; // removed current clothing
            curr_time <= curr_time + 1;
            if (time_budget > 0) time_budget <= time_budget - 1;
          end
        end

        PUT_START: begin
          put_cnt <= P_TIME[target_cloth];
        end

        PUT_WAIT: begin
          if (put_cnt > 0) begin
            put_cnt <= put_cnt - 1;
          end else begin
            curr_cloth <= target_cloth; // dressed
            curr_time <= curr_time + 1;
            if (time_budget > 0) time_budget <= time_budget - 1;
          end
        end

        DONE: begin
          max_customers <= count;
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic and outputs
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CHECK;
      end

      CHECK: begin
        // Wait until arrival to decide
        if (time_to_next == 8'h00) begin
          if (idx < CUST_N) begin
            if (CUST_TYPE[idx] == curr_cloth) begin
              // Served immediately; go to next customer
              if (idx + 1 < CUST_N) begin
                next_state = CHECK; // continue with next
              end else begin
                next_state = DONE;
              end
            end else begin
              // Not matching clothing: consider changing if time permits
              target_cloth = CUST_TYPE[idx];
              time_budget = time_left[7:0];
              if (compute_change_time(curr_cloth, target_cloth) <= time_budget) begin
                // Enough time to remove and put before next arrival
                next_state = REMOVE_START;
              end else begin
                // Not enough time: skip serving this customer
                if (idx + 1 < CUST_N) begin
                  next_state = CHECK; // move to next
                end else begin
                  next_state = DONE;
                end
              end
            end
          end else begin
            next_state = DONE;
          end
        end else begin
          // Still waiting for arrival
          next_state = CHECK;
        end
      end

      REMOVE_START: begin
        next_state = REMOVE_WAIT;
      end

      REMOVE_WAIT: begin
        if (remove_cnt == 8'h00) begin
          next_state = PUT_START;
        end else begin
          next_state = REMOVE_WAIT;
        end
      end

      PUT_START: begin
        next_state = PUT_WAIT;
      end

      PUT_WAIT: begin
        if (put_cnt == 8'h00) begin
          // Now wearing the required clothing; serve immediately (no extra time)
          if (idx < CUST_N) begin
            // We did not advance idx yet in CHECK, so we are still on same customer
            // Serve the current one
            // Proceed to next arrival
            if (idx + 1 < CUST_N) begin
              next_state = CHECK;
            end else begin
              next_state = DONE;
            end
          end else begin
            next_state = DONE;
          end
        end else begin
          next_state = PUT_WAIT;
        end
      end

      DONE: begin
        next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end
endmodule