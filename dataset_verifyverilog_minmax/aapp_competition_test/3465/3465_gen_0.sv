module road_assignment(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [2:0] num_cities, // number of cities/roads (2-8)
  input [7:0][5:0] roads, // 8 roads, each represented as {city_a[2:0], city_b[2:0]}
  output reg [7:0][5:0] assignments, // output roads in random order
  output reg done // high when computation complete
);

  // Number of roads is always 8, but we only use the first num_cities entries
  parameter NUM_ROADS = 8;

  // Break each 6-bit road into two 3-bit city endpoints
  logic [2:0] ep [NUM_ROADS][2]; // endpoints[road][0] and [1]
  // Keep a copy of inputs to avoid synthesizing latches in the FSM
  logic [2:0] num_cities_q;
  logic [7:0][5:0] roads_q;

  // Random index selection (Fisher-Yates like)
  logic [2:0] idx_pool [NUM_ROADS];
  logic [2:0] pool_sz;              // current pool size
  logic [2:0] rand_idx;             // selected random index [0..pool_sz-1]
  logic [7:0] pool_mask;            // bitmask of remaining items in the pool
  logic [2:0] selected_road;        // resulting road index (0..7)

  // LFSR for randomness (16-bit, taps for x^16 + x^14 + x^13 + x^11 + 1)
  logic [15:0] lfsr, lfsr_next;
  wire lfsr_feedback = ^lfsr[15:2] ^ lfsr[0];

  // Build state machine
  typedef enum logic [2:0] {
    S_IDLE   = 3'b000,
    S_SAMPLE = 3'b001,
    S_PICK   = 3'b010,
    S_APPEND = 3'b011,
    S_DONE   = 3'b100
  } state_t;
  state_t state, state_next;

  // Internal control
  logic start_q;
  logic start_detected;
  logic pool_not_empty;
  logic [2:0] i, i_next; // position in output (0..7)

  // Combinational LFSR update
  assign lfsr_next = {lfsr[14:0], lfsr_feedback};

  // Edge-detect start pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_q <= 1'b0;
    else        start_q <= start;
  end
  assign start_detected = start && ~start_q;

  // Unpack roads into endpoints (always keep original connections)
  genvar r;
  generate
    for (r = 0; r < NUM_ROADS; r = r + 1) begin : unpack_eps
      assign ep[r][0] = roads_q[5:3]; // city_a
      assign ep[r][1] = roads_q[2:0]; // city_b
    end
  endgenerate

  // Random index from the current pool using combinatorial lfsr and bitmask
  // rand_idx in [0..pool_sz-1]
  function [2:0] get_rand_idx;
    input [2:0] pool_size;
    input [15:0] lfsr_val;
    begin
      // Avoid division by zero; caller ensures pool_size > 0
      get_rand_idx = lfsr_val % pool_size; // pool_size in [1..8]
    end
  endfunction

  // Map rand_idx [0..pool_sz-1] to the corresponding road index using pool_mask
  function [2:0] map_rand_to_road;
    input [7:0] mask;
    input [2:0] rindex;
    integer i, found, cnt;
    begin
      cnt = 0;
      found = -1;
      for (i = 0; i < NUM_ROADS; i = i + 1) begin
        if (mask[i]) begin
          if (cnt == rindex) begin
            found = i;
            break;
          end
          cnt = cnt + 1;
        end
      end
      // Should never happen if mask matches pool_sz
      map_rand_to_road = (found == -1) ? 3'b000 : found[2:0];
    end
  endfunction

  // Compute pool_not_empty = |pool_mask|
  function [2:0] popcount8;
    input [7:0] x;
    integer i, c;
    begin
      c = 0;
      for (i = 0; i < 8; i = i + 1) c = c + x[i];
      popcount8 = c[2:0];
    end
  endfunction
  assign pool_not_empty = (popcount8(pool_mask) > 0);

  // State register with async reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      i <= 3'b0;
      pool_mask <= 8'b0;
      pool_sz <= 3'b0;
      rand_idx <= 3'b0;
      selected_road <= 3'b0;
      assignments <= 8'b0;
      done <= 1'b0;
      lfsr <= 16'hACE1; // seed
      num_cities_q <= 3'b0;
      roads_q <= 8'b0;
    end else begin
      // Default values
      state <= state_next;
      i <= i_next;
      pool_sz <= pool_sz; // keep unless overridden below
      pool_mask <= pool_mask; // keep unless overridden below
      rand_idx <= rand_idx; // keep unless overridden below
      selected_road <= selected_road; // keep unless overridden below
      assignments <= assignments; // keep unless overridden below
      done <= done; // keep unless overridden below
      lfsr <= lfsr_next;
      num_cities_q <= num_cities; // capture inputs when available
      roads_q <= roads;           // capture inputs when available

      // State machine behavior
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          assignments <= 8'b0;
          i <= 3'b0;
          if (start_detected) begin
            // Initialize LFSR for each run for better randomness
            lfsr <= lfsr_next;
            // Start pool with all valid road indices (0..num_cities-1)
            pool_mask <= (1 << num_cities) - 1; // bits [0..num_cities-1] set
            pool_sz <= num_cities[2:0];
            state_next <= S_SAMPLE;
          end else begin
            state_next <= S_IDLE;
          end
        end

        S_SAMPLE: begin
          // combinatorial: choose random index from current pool
          // Use new lfsr for better distribution
          lfsr <= lfsr_next;
          rand_idx <= get_rand_idx(pool_sz, lfsr_next);
          state_next <= S_PICK;
        end

        S_PICK: begin
          // Map rand_idx to actual road id using bitmask
          selected_road <= map_rand_to_road(pool_mask, rand_idx);
          state_next <= S_APPEND;
        end

        S_APPEND: begin
          // Append the selected road to output in current order
          // Keep original road representation; only change ordering across outputs
          assignments[i] <= roads_q[selected_road];
          // Remove selected road from pool
          pool_mask[selected_road] <= 1'b0;
          pool_sz <= popcount8({pool_mask[7:1], 1'b0}); // recompute without the selected bit (combinatorial)
          i <= i + 1;
          // Decide next state: fill until pool is empty or we produced up to 8
          if (popcount8({pool_mask[7:1], 1'b0}) > 0) begin
            state_next <= S_SAMPLE;
          end else begin
            state_next <= S_DONE;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Latch done until next start pulse
          if (!start) state_next <= S_DONE;
          else        state_next <= S_SAMPLE; // allow immediate new run on start
        end

        default: begin
          state_next <= S_IDLE;
        end
      endcase
    end
  end

  // Explicit next-state for i (0..7)
  always_comb begin
    case (state)
      S_IDLE:   i_next = 3'b0;
      S_SAMPLE: i_next = i;
      S_PICK:   i_next = i;
      S_APPEND: i_next = i + 1;
      S_DONE:   i_next = i; // hold
      default:  i_next = i;
    endcase
  end

endmodule