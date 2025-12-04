module garbage_bags(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [15:0] k, // bag capacity (16-bit)
  input [15:0] days_data [0:15], // garbage per day (16 entries*16b)
  input [3:0] n, // actual number of days (1-16, 4-bit)
  output reg [31:0] total_bags, // 32-bit bag count
  output reg done // high when computation complete
);

  // State definitions
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  // FSM and datapath registers
  reg [1:0] state, next_state;
  reg [31:0] next_total_bags;
  reg [15:0] current_leftover, next_leftover;
  reg [3:0] day_counter, next_day_counter;
  reg [15:0] next_day_data; // snapshot of current day's garbage

  // Combinational next-state logic
  always_comb begin
    next_state       = state;
    next_total_bags  = total_bags;
    next_leftover    = current_leftover;
    next_day_counter = day_counter;
    next_day_data    = 16'h0;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize for a new computation
          next_state       = PROCESSING;
          next_total_bags  = 32'h0;
          next_leftover    = 16'h0;
          next_day_counter = 4'h0;
          next_day_data    = days_data[0];
        end else begin
          // Hold outputs stable in IDLE
          next_total_bags  = total_bags;
          next_leftover    = current_leftover;
          next_day_counter = day_counter;
        end
      end

      PROCESSING: begin
        // Snapshot data for the current day
        next_day_data = days_data[day_counter];

        // Compute today's totals
        {next_total_bags, next_leftover} = {16'h0, current_leftover} + {16'h0, next_day_data};

        // Integer division and remainder by k
        if (k != 16'h0) begin
          next_total_bags = next_total_bags / k;
          next_leftover   = next_leftover % k;
        end else begin
          // Defensive: avoid division-by-zero; treat as 0 bags used, keep leftovers unchanged
          next_total_bags = 32'h0;
          next_leftover   = {16'h0, current_leftover} + {16'h0, next_day_data};
        end

        // If there is leftover on the last day, we need one more bag
        if ((day_counter == (n - 1)) && (next_leftover != 16'h0)) begin
          next_total_bags = next_total_bags + 1;
          next_leftover   = 16'h0; // reset leftover after using extra bag
        end

        // Prepare for next day or finish
        if (day_counter < (n - 1)) begin
          next_day_counter = day_counter + 1;
          next_state       = PROCESSING;
        end else begin
          next_day_counter = 4'h0;
          next_state       = DONE;
        end
      end

      DONE: begin
        // After n+1 cycles from start, assert done and hold total_bags
        next_state      = IDLE;
        next_total_bags = total_bags;
        next_leftover   = current_leftover;
        next_day_counter= day_counter;
      end

      default: begin
        next_state       = IDLE;
        next_total_bags  = 32'h0;
        next_leftover    = 16'h0;
        next_day_counter = 4'h0;
      end
    endcase
  end

  // Sequential state and datapath update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      total_bags    <= 32'h0;
      current_leftover <= 16'h0;
      day_counter   <= 4'h0;
      done          <= 1'b0;
    end else begin
      state         <= next_state;
      total_bags    <= next_total_bags;
      current_leftover <= next_leftover;
      day_counter   <= next_day_counter;
      done          <= (next_state == DONE); // pulse high for one cycle
    end
  end

endmodule