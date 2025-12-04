module flight_scheduler(
  input clk,
  input rst_n,
  input start,
  input [15:0] k_days,
  input [3:0] num_flights,
  input reg [15:0] flight_days [0:15],
  input reg [2:0] flight_from [0:15],
  input reg [2:0] flight_to [0:15],
  input reg [31:0] flight_cost [0:15],
  output reg [31:0] min_cost,
  output reg done,
  output reg impossible
);

  // FSM states
  localparam IDLE = 2'b00;
  localparam PROCESS = 2'b01;
  localparam DONE = 2'b10;

  // State and control registers
  logic [1:0] state;
  logic [5:0] cycle_cnt;        // 6-bit counter for 32 cycles
  logic [3:0] f_idx;            // flight index (0..15)

  // Data for each city (cities 1..4 mapped to 0..3)
  logic [3:0] inbound_cnt [0:3];
  logic [3:0] outbound_cnt[0:3];
  logic [15:0] inbound_day  [0:3][0:15];
  logic [31:0] inbound_cost [0:3][0:15];
  logic [15:0] outbound_day [0:3][0:15];
  logic [31:0] outbound_cost[0:3][0:15];

  // Combinational result
  logic [31:0] total_min_cost;
  logic total_impossible;
  logic [31:0] city_best [0:3];
  logic [3:0] city_valid;

  // Compute best cost for each city and overall result
  always_comb begin
    // Initialize
    total_impossible = 1'b0;
    total_min_cost   = 32'b0;
    city_valid       = 4'b0;
    for (int c = 0; c < 4; c++) begin
      city_best[c] = 32'hFFFFFFFF;
    end

    for (int c = 0; c < 4; c++) begin
      if (inbound_cnt[c] > 0 && outbound_cnt[c] > 0) begin
        for (int i = 0; i < inbound_cnt[c]; i++) begin
          for (int j = 0; j < outbound_cnt[c]; j++) begin
            if (inbound_day[c][i] + k_days + 1 <= outbound_day[c][j]) begin
              logic [31:0] sum = inbound_cost[c][i] + outbound_cost[c][j];
              if (sum < city_best[c]) city_best[c] = sum;
              city_valid[c] = 1'b1;
            end
          end
        end
      end
      if (!city_valid[c]) total_impossible = 1'b1;
      else total_min_cost = total_min_cost + city_best[c];
    end
  end

  // FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 6'b0;
      f_idx <= 4'b0;
      // Clear counters
      inbound_cnt <= '{default:'0};
      outbound_cnt <= '{default:'0};
      // min_cost, done, impossible are driven by combinational logic based on state
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESS;
            cycle_cnt <= 6'd31;      // will count down to 0 (32 cycles total)
            f_idx <= 4'b0;
            inbound_cnt <= '{default:'0};
            outbound_cnt <= '{default:'0};
          end
        end
        PROCESS: begin
          // Decrement cycle counter
          cycle_cnt <= cycle_cnt - 1;

          // Process one flight per cycle if any remain
          if (f_idx < num_flights) begin
            // inbound to city 0
            if (flight_to[f_idx] == 3'b0) begin
              if (flight_from[f_idx] >= 3'b001 && flight_from[f_idx] <= 3'b100) begin
                int c = flight_from[f_idx] - 1;
                inbound_day[c][inbound_cnt[c]] <= flight_days[f_idx];
                inbound_cost[c][inbound_cnt[c]] <= flight_cost[f_idx];
                inbound_cnt[c] <= inbound_cnt[c] + 1;
              end
            // outbound from city 0
            end else if (flight_from[f_idx] == 3'b0) begin
              if (flight_to[f_idx] >= 3'b001 && flight_to[f_idx] <= 3'b100) begin
                int d = flight_to[f_idx] - 1;
                outbound_day[d][outbound_cnt[d]] <= flight_days[f_idx];
                outbound_cost[d][outbound_cnt[d]] <= flight_cost[f_idx];
                outbound_cnt[d] <= outbound_cnt[d] + 1;
              end
            end
            f_idx <= f_idx + 1;
          end

          // After 32 cycles, move to DONE
          if (cycle_cnt == 6'd0) begin
            state <= DONE;
          end
        end
        DONE: begin
          // Wait for next start pulse to go back to IDLE
          if (start) state <= IDLE;
        end
      endcase
    end
  end

  // Outputs
  assign done      = (state == DONE);
  assign min_cost  = (state == DONE) ? total_min_cost : 32'b0;
  assign impossible= (state == DONE) ? total_impossible : 1'b0;

endmodule