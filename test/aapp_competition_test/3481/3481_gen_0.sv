module maximum_gig_earnings(
  input clk,
  input rst_n,
  input start,
  input [7:0] road_a,
  input [7:0] road_b,
  input [63:0] road_t,
  input [7:0] gig_v,
  input [63:0] gig_s,
  input [63:0] gig_e,
  input [63:0] gig_m,
  output reg [15:0] max_earnings,
  output reg done
);

  // Distance matrix (4x4), 16-bit each
  reg [15:0] dist [0:3][0:3];
  reg [15:0] dist_next [0:3][0:3];

  // Gigs data unpacked
  reg [1:0] gig_venue [0:3];
  reg [15:0] gig_start [0:3];
  reg [15:0] gig_end   [0:3];
  reg [15:0] gig_money [0:3];
  reg        gig_active[0:3];

  // Permutation ROM for 24 permutations of 4 indices (0..3)
  // Each entry: 8 bits = 4x2-bit indices.
  reg [7:0] perm_rom [0:23];
  initial begin
    perm_rom[0]  = {2'd0,2'd1,2'd2,2'd3};
    perm_rom[1]  = {2'd0,2'd1,2'd3,2'd2};
    perm_rom[2]  = {2'd0,2'd2,2'd1,2'd3};
    perm_rom[3]  = {2'd0,2'd2,2'd3,2'd1};
    perm_rom[4]  = {2'd0,2'd3,2'd1,2'd2};
    perm_rom[5]  = {2'd0,2'd3,2'd2,2'd1};
    perm_rom[6]  = {2'd1,2'd0,2'd2,2'd3};
    perm_rom[7]  = {2'd1,2'd0,2'd3,2'd2};
    perm_rom[8]  = {2'd1,2'd2,2'd0,2'd3};
    perm_rom[9]  = {2'd1,2'd2,2'd3,2'd0};
    perm_rom[10] = {2'd1,2'd3,2'd0,2'd2};
    perm_rom[11] = {2'd1,2'd3,2'd2,2'd0};
    perm_rom[12] = {2'd2,2'd0,2'd1,2'd3};
    perm_rom[13] = {2'd2,2'd0,2'd3,2'd1};
    perm_rom[14] = {2'd2,2'd1,2'd0,2'd3};
    perm_rom[15] = {2'd2,2'd1,2'd3,2'd0};
    perm_rom[16] = {2'd2,2'd3,2'd0,2'd1};
    perm_rom[17] = {2'd2,2'd3,2'd1,2'd0};
    perm_rom[18] = {2'd3,2'd0,2'd1,2'd2};
    perm_rom[19] = {2'd3,2'd0,2'd2,2'd1};
    perm_rom[20] = {2'd3,2'd1,2'd0,2'd2};
    perm_rom[21] = {2'd3,2'd1,2'd2,2'd0};
    perm_rom[22] = {2'd3,2'd2,2'd0,2'd1};
    perm_rom[23] = {2'd3,2'd2,2'd1,2'd0};
  end

  // FSM states
  typedef enum logic [4:0] {
    S_IDLE          = 5'd0,
    S_INIT_DIST0    = 5'd1,
    S_INIT_DIST1    = 5'd2,
    S_INIT_DIST2    = 5'd3,
    S_LOAD_ROADS    = 5'd4,
    S_FW_K0         = 5'd5,
    S_FW_K1         = 5'd6,
    S_FW_K2         = 5'd7,
    S_FW_K3         = 5'd8,
    S_PREP_GIGS     = 5'd9,
    S_PERM_EVAL     = 5'd10,
    S_DONE          = 5'd11
  } state_t;

  state_t state, next_state;

  // Counters and indices
  reg [3:0] i_cnt;
  reg [3:0] j_cnt;
  reg [4:0] perm_idx;      // 0..23

  // Internal registers for evaluation
  reg [7:0] curr_perm_packed;
  reg [1:0] p_idx0, p_idx1, p_idx2, p_idx3;

  reg [15:0] best_earnings;

  // 65535 constant
  localparam [15:0] INF = 16'hFFFF;

  // Helper wires for road unpacking
  wire [1:0] rA0 = road_a[1:0];
  wire [1:0] rA1 = road_a[3:2];
  wire [1:0] rA2 = road_a[5:4];
  wire [1:0] rA3 = road_a[7:6];

  wire [1:0] rB0 = road_b[1:0];
  wire [1:0] rB1 = road_b[3:2];
  wire [1:0] rB2 = road_b[5:4];
  wire [1:0] rB3 = road_b[7:6];

  wire [15:0] rT0 = road_t[15:0];
  wire [15:0] rT1 = road_t[31:16];
  wire [15:0] rT2 = road_t[47:32];
  wire [15:0] rT3 = road_t[63:48];

  // Gig unpacking wires
  wire [1:0] gV0 = gig_v[1:0];
  wire [1:0] gV1 = gig_v[3:2];
  wire [1:0] gV2 = gig_v[5:4];
  wire [1:0] gV3 = gig_v[7:6];

  wire [15:0] gS0 = gig_s[15:0];
  wire [15:0] gS1 = gig_s[31:16];
  wire [15:0] gS2 = gig_s[47:32];
  wire [15:0] gS3 = gig_s[63:48];

  wire [15:0] gE0 = gig_e[15:0];
  wire [15:0] gE1 = gig_e[31:16];
  wire [15:0] gE2 = gig_e[47:32];
  wire [15:0] gE3 = gig_e[63:48];

  wire [15:0] gM0 = gig_m[15:0];
  wire [15:0] gM1 = gig_m[31:16];
  wire [15:0] gM2 = gig_m[47:32];
  wire [15:0] gM3 = gig_m[63:48];

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  integer x, y, k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      max_earnings <= 16'd0;
      best_earnings <= 16'd0;
      i_cnt <= 4'd0;
      j_cnt <= 4'd0;
      perm_idx <= 5'd0;
      // Initialize dist to INF and 0 on diagonal
      for (x = 0; x < 4; x = x + 1) begin
        for (y = 0; y < 4; y = y + 1) begin
          if (x == y) dist[x][y] <= 16'd0;
          else        dist[x][y] <= INF;
        end
      end
      // Initialize gig arrays
      for (x = 0; x < 4; x = x + 1) begin
        gig_venue[x]  <= 2'd0;
        gig_start[x]  <= 16'd0;
        gig_end[x]    <= 16'd0;
        gig_money[x]  <= 16'd0;
        gig_active[x] <= 1'b0;
      end
    end else begin
      done <= 1'b0;
      case (state)
        S_IDLE: begin
          if (start) begin
            best_earnings <= 16'd0;
            max_earnings <= 16'd0;
            perm_idx <= 5'd0;
            // Initialize dist to INF and 0 diagonal
            for (x = 0; x < 4; x = x + 1) begin
              for (y = 0; y < 4; y = y + 1) begin
                if (x == y) dist[x][y] <= 16'd0;
                else        dist[x][y] <= INF;
              end
            end
          end
        end

        // Load direct roads (symmetric, min for duplicates)
        S_LOAD_ROADS: begin
          // Road 0
          if (rT0 < dist[rA0][rB0]) begin
            dist[rA0][rB0] <= rT0;
            dist[rB0][rA0] <= rT0;
          end
          // Road 1
          if (rT1 < dist[rA1][rB1]) begin
            dist[rA1][rB1] <= rT1;
            dist[rB1][rA1] <= rT1;
          end
          // Road 2
          if (rT2 < dist[rA2][rB2]) begin
            dist[rA2][rB2] <= rT2;
            dist[rB2][rA2] <= rT2;
          end
          // Road 3
          if (rT3 < dist[rA3][rB3]) begin
            dist[rA3][rB3] <= rT3;
            dist[rB3][rA3] <= rT3;
          end
        end

        // Floyd-Warshall k=0
        S_FW_K0: begin
          k = 0;
          for (x = 0; x < 4; x = x + 1) begin
            for (y = 0; y < 4; y = y + 1) begin
              if (dist[x][k] != INF && dist[k][y] != INF &&
                  dist[x][k] + dist[k][y] < dist[x][y]) begin
                dist[x][y] <= dist[x][k] + dist[k][y];
              end
            end
          end
        end

        // Floyd-Warshall k=1
        S_FW_K1: begin
          k = 1;
          for (x = 0; x < 4; x = x + 1) begin
            for (y = 0; y < 4; y = y + 1) begin
              if (dist[x][k] != INF && dist[k][y] != INF &&
                  dist[x][k] + dist[k][y] < dist[x][y]) begin
                dist[x][y] <= dist[x][k] + dist[k][y];
              end
            end
          end
        end

        // Floyd-Warshall k=2
        S_FW_K2: begin
          k = 2;
          for (x = 0; x < 4; x = x + 1) begin
            for (y = 0; y < 4; y = y + 1) begin
              if (dist[x][k] != INF && dist[k][y] != INF &&
                  dist[x][k] + dist[k][y] < dist[x][y]) begin
                dist[x][y] <= dist[x][k] + dist[k][y];
              end
            end
          end
        end

        // Floyd-Warshall k=3
        S_FW_K3: begin
          k = 3;
          for (x = 0; x < 4; x = x + 1) begin
            for (y = 0; y < 4; y = y + 1) begin
              if (dist[x][k] != INF && dist[k][y] != INF &&
                  dist[x][k] + dist[k][y] < dist[x][y]) begin
                dist[x][y] <= dist[x][k] + dist[k][y];
              end
            end
          end
        end

        // Prepare gigs (unpack and mark active)
        S_PREP_GIGS: begin
          gig_venue[0]  <= gV0;
          gig_venue[1]  <= gV1;
          gig_venue[2]  <= gV2;
          gig_venue[3]  <= gV3;

          gig_start[0]  <= gS0;
          gig_start[1]  <= gS1;
          gig_start[2]  <= gS2;
          gig_start[3]  <= gS3;

          gig_end[0]    <= gE0;
          gig_end[1]    <= gE1;
          gig_end[2]    <= gE2;
          gig_end[3]    <= gE3;

          gig_money[0]  <= gM0;
          gig_money[1]  <= gM1;
          gig_money[2]  <= gM2;
          gig_money[3]  <= gM3;

          gig_active[0] <= (gV0 != 2'd0);
          gig_active[1] <= (gV1 != 2'd0);
          gig_active[2] <= (gV2 != 2'd0);
          gig_active[3] <= (gV3 != 2'd0);

          perm_idx <= 5'd0;
          best_earnings <= 16'd0;
        end

        // Evaluate permutations sequentially
        S_PERM_EVAL: begin
          // Get current permutation
          curr_perm_packed = perm_rom[perm_idx];
          p_idx0 = curr_perm_packed[7:6];
          p_idx1 = curr_perm_packed[5:4];
          p_idx2 = curr_perm_packed[3:2];
          p_idx3 = curr_perm_packed[1:0];

          // Evaluate this permutation path combinationally inside this clock
          // respecting active gigs, time windows, and travel constraints.

          // Local temporaries
          reg [15:0] total;
          reg [15:0] cur_time;
          reg [1:0]  prev_venue;
          reg        valid;

          total = 16'd0;
          valid = 1'b1;

          // Start at venue of first active gig; if inactive, skip to next.
          // Step 0
          if (gig_active[p_idx0]) begin
            // Assume starting at gig_venue[p_idx0] with no travel time
            if (cur_time <= gig_start[p_idx0]) begin
              cur_time = gig_start[p_idx0];
              cur_time = gig_end[p_idx0];
              total = total + gig_money[p_idx0];
              prev_venue = gig_venue[p_idx0];
            end else begin
              valid = 1'b0;
            end
          end else begin
            // No gig, set a neutral starting point
            cur_time = 16'd0;
            prev_venue = 2'd0;
          end

          // Step 1
          if (valid && gig_active[p_idx1]) begin
            if (dist[prev_venue][gig_venue[p_idx1]] == INF) begin
              valid = 1'b0;
            end else begin
              if (cur_time + dist[prev_venue][gig_venue[p_idx1]] <= gig_start[p_idx1]) begin
                cur_time = gig_end[p_idx1];
                total = total + gig_money[p_idx1];
                prev_venue = gig_venue[p_idx1];
              end else begin
                valid = 1'b0;
              end
            end
          end

          // Step 2
          if (valid && gig_active[p_idx2]) begin
            if (dist[prev_venue][gig_venue[p_idx2]] == INF) begin
              valid = 1'b0;
            end else begin
              if (cur_time + dist[prev_venue][gig_venue[p_idx2]] <= gig_start[p_idx2]) begin
                cur_time = gig_end[p_idx2];
                total = total + gig_money[p_idx2];
                prev_venue = gig_venue[p_idx2];
              end else begin
                valid = 1'b0;
              end
            end
          end

          // Step 3
          if (valid && gig_active[p_idx3]) begin
            if (dist[prev_venue][gig_venue[p_idx3]] == INF) begin
              valid = 1'b0;
            end else begin
              if (cur_time + dist[prev_venue][gig_venue[p_idx3]] <= gig_start[p_idx3]) begin
                cur_time = gig_end[p_idx3];
                total = total + gig_money[p_idx3];
                prev_venue = gig_venue[p_idx3];
              end else begin
                valid = 1'b0;
              end
            end
          end

          // Update best earnings
          if (valid && (total > best_earnings)) begin
            best_earnings <= total;
          end

          // Next permutation index
          if (perm_idx < 5'd23) begin
            perm_idx <= perm_idx + 5'd1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          max_earnings <= best_earnings;
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
          next_state = S_LOAD_ROADS;
      end
      S_LOAD_ROADS: begin
        next_state = S_FW_K0;
      end
      S_FW_K0: begin
        next_state = S_FW_K1;
      end
      S_FW_K1: begin
        next_state = S_FW_K2;
      end
      S_FW_K2: begin
        next_state = S_FW_K3;
      end
      S_FW_K3: begin
        next_state = S_PREP_GIGS;
      end
      S_PREP_GIGS: begin
        next_state = S_PERM_EVAL;
      end
      S_PERM_EVAL: begin
        if (perm_idx == 5'd23)
          next_state = S_DONE;
        else
          next_state = S_PERM_EVAL;
      end
      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
        else
          next_state = S_DONE;
      end
      default: next_state = S_IDLE;
    endcase
  end

endmodule