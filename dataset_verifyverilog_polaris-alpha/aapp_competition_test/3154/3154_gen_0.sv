module toy_assignment(
  input clk,
  input rst_n,
  input start,
  input [3:0] in_kid_id,
  input [3:0] in_toy_id,
  input [15:0] in_event_time,
  input [2:0] in_event_count,
  output reg [7:0] assignments,
  output reg impossible_flag,
  output reg done
);

  // Internal parameters
  localparam KIDS = 4;
  localparam TOYS = 4;
  localparam MAX_EVENTS = 8;

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_READ_EVT  = 3'd2,
    S_BUILD     = 3'd3,
    S_ENUM      = 3'd4,
    S_DONE      = 3'd5
  } state_t;

  state_t state, next_state;

  // Storage for events (up to 8)
  reg [1:0] ev_kid   [0:MAX_EVENTS-1];
  reg [1:0] ev_toy   [0:MAX_EVENTS-1];
  reg [15:0] ev_time [0:MAX_EVENTS-1];

  reg [2:0] total_events;        // latched in_event_count at start
  reg [2:0] ev_wr_idx;           // write index during READ_EVT

  // Kid-Toy total time matrix
  reg [19:0] play_time [0:KIDS-1][0:TOYS-1]; // 20 bits for margin

  // First-play preference matrix: preferred_toy[k] is toy index (0-3)
  reg [1:0] preferred_toy [0:KIDS-1];
  reg       pref_set      [0:KIDS-1];

  // Enumeration registers
  reg [3:0] perm;           // current permutation of toys for kids 0..3
  reg       found_valid;

  integer i, j;

  // Helper: next lexicographic permutation for 4-element vector of 2-bit toy IDs
  // We treat perm as 4 entries (each 2 bits) but stored as [3:0] assuming value uniqueness 0..3.
  // So perm[0] = perm[1:0], perm[1] = perm[3:2]? Instead store directly as 4x2? For simplicity,
  // keep perm as 4-bit with distinct values 0..3, representing assignment[kid] = perm[kid].
  // next_perm computes next permutation in-place; sets no_more=1 if wrapped.

  function automatic void decode_perm(
    input  [3:0] p,
    output [1:0] a0,
    output [1:0] a1,
    output [1:0] a2,
    output [1:0] a3
  );
    begin
      a0 = p[1:0];
      a1 = p[3:2];
      // For 4 distinct values 0..3, encode as 2 bits each; we'll reconstruct others when enumerating.
      // But to avoid complexity, we'll not use this function in final design.
      a2 = 2'd0;
      a3 = 2'd0;
    end
  endfunction

  // Instead of tricky packing, we explicitly store 4x2 permutation entries.
  reg [1:0] assign_toy [0:KIDS-1];

  // Enumeration control
  reg [4:0] enum_idx; // up to 24 permutations (<32)

  // Predefined list of all permutations of 0,1,2,3 (24 total)
  // Each 8-bit entry: {kid3_toy[1:0], kid2_toy[1:0], kid1_toy[1:0], kid0_toy[1:0]}
  localparam [7:0] PERM_LUT [0:23] = '{
    8'b11_10_01_00, // 0 1 2 3 -> kid0:0,kid1:1,kid2:2,kid3:3 (LSB first)
    8'b11_10_00_01,
    8'b11_01_10_00,
    8'b11_01_00_10,
    8'b11_00_10_01,
    8'b11_00_01_10,
    8'b10_11_01_00,
    8'b10_11_00_01,
    8'b10_01_11_00,
    8'b10_01_00_11,
    8'b10_00_11_01,
    8'b10_00_01_11,
    8'b01_11_10_00,
    8'b01_11_00_10,
    8'b01_10_11_00,
    8'b01_10_00_11,
    8'b01_00_11_10,
    8'b01_00_10_11,
    8'b00_11_10_01,
    8'b00_11_01_10,
    8'b00_10_11_01,
    8'b00_10_01_11,
    8'b00_01_11_10,
    8'b00_01_10_11
  };

  // Sequential state and main FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      impossible_flag <= 1'b0;
      assignments <= 8'd0;
      total_events <= 3'd0;
      ev_wr_idx <= 3'd0;
      found_valid <= 1'b0;
      enum_idx <= 5'd0;
      for (i = 0; i < KIDS; i = i + 1) begin
        pref_set[i] <= 1'b0;
        preferred_toy[i] <= 2'd0;
        for (j = 0; j < TOYS; j = j + 1) begin
          play_time[i][j] <= 20'd0;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          impossible_flag <= 1'b0;
          found_valid <= 1'b0;
          if (start) begin
            // Latch intended number of events at start
            total_events <= in_event_count;
            ev_wr_idx <= 3'd0;
            // Clear matrices
            for (i = 0; i < KIDS; i = i + 1) begin
              pref_set[i] <= 1'b0;
              preferred_toy[i] <= 2'd0;
              for (j = 0; j < TOYS; j = j + 1) begin
                play_time[i][j] <= 20'd0;
              end
            end
          end
        end

        S_INIT: begin
          // Nothing extra; actual clears performed on entering from IDLE
        end

        S_READ_EVT: begin
          // Capture one event per cycle until total_events reached
          if (ev_wr_idx < total_events) begin
            // Store event
            ev_kid[ev_wr_idx] <= in_kid_id[1:0];
            ev_toy[ev_wr_idx] <= in_toy_id[1:0];
            ev_time[ev_wr_idx] <= in_event_time;
            ev_wr_idx <= ev_wr_idx + 3'd1;
          end
        end

        S_BUILD: begin
          // Build play_time and first-play preference from stored events
          // Do one event per cycle indexed by enum_idx
          if (enum_idx < total_events) begin
            reg [1:0] k;
            reg [1:0] t;
            k = ev_kid[enum_idx];
            t = ev_toy[enum_idx];
            // accumulate playtime
            play_time[k][t] <= play_time[k][t] + ev_time[enum_idx];
            // set first play preference if not set for this kid
            if (!pref_set[k]) begin
              pref_set[k] <= 1'b1;
              preferred_toy[k] <= t;
            end
            enum_idx <= enum_idx + 5'd1;
          end
        end

        S_ENUM: begin
          done <= 1'b0;
          if (!found_valid) begin
            if (enum_idx < 24) begin
              // Decode permutation from LUT for this enum_idx
              reg [7:0] p;
              reg [1:0] k0_t, k1_t, k2_t, k3_t;
              integer kk, aa, bb;
              reg valid;

              p = PERM_LUT[enum_idx];
              k0_t = p[1:0];
              k1_t = p[3:2];
              k2_t = p[5:4];
              k3_t = p[7:6];

              assign_toy[0] = k0_t;
              assign_toy[1] = k1_t;
              assign_toy[2] = k2_t;
              assign_toy[3] = k3_t;

              // Check envy constraints using play_time matrix
              valid = 1'b1;
              for (aa = 0; aa < KIDS; aa = aa + 1) begin
                reg [1:0] toyB;
                toyB = assign_toy[aa];
                for (bb = 0; bb < KIDS; bb = bb + 1) begin
                  if (bb != aa) begin
                    if (play_time[bb][toyB] > play_time[aa][toyB]) begin
                      valid = 1'b0;
                    end
                  end
                end
              end

              if (valid) begin
                found_valid <= 1'b1;
                assignments <= {assign_toy[3], assign_toy[2], assign_toy[1], assign_toy[0]};
                impossible_flag <= 1'b0;
              end else begin
                enum_idx <= enum_idx + 5'd1;
              end
            end else begin
              // Exhausted all permutations without success
              found_valid <= 1'b0;
              impossible_flag <= 1'b1;
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        // Move to event read if there are events; if zero, skip to ENUM with empty stats
        if (in_event_count != 3'd0)
          next_state = S_READ_EVT;
        else begin
          // No events: play_time all zero; we will enumerate directly
          next_state = S_ENUM;
        end
      end

      S_READ_EVT: begin
        if (ev_wr_idx >= total_events) begin
          // prepare for BUILD
          next_state = S_BUILD;
        end
      end

      S_BUILD: begin
        if (enum_idx >= total_events) begin
          // finished building matrices; prepare enumeration
          next_state = S_ENUM;
        end
      end

      S_ENUM: begin
        if (found_valid || impossible_flag) begin
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        // Stay one cycle with done=1, then go idle next cycle
        next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule