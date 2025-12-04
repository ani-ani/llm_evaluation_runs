module app_installer (
  input clk,
  input rst_n,
  input start,
  input [9:0] c,
  input [9:0] d1, input [9:0] s1,
  input [9:0] d2, input [9:0] s2,
  input [9:0] d3, input [9:0] s3,
  input [9:0] d4, input [9:0] s4,
  input [9:0] d5, input [9:0] s5,
  input [9:0] d6, input [9:0] s6,
  input [9:0] d7, input [9:0] s7,
  input [9:0] d8, input [9:0] s8,
  output reg [3:0] max_count,
  output reg [3:0] order [0:7],
  output reg done
);

  // Packing app data
  wire [9:0] d [0:7];
  wire [9:0] s [0:7];
  assign d[0] = d1; assign s[0] = s1;
  assign d[1] = d2; assign s[1] = s2;
  assign d[2] = d3; assign s[2] = s3;
  assign d[3] = d4; assign s[3] = s4;
  assign d[4] = d5; assign s[4] = s5;
  assign d[5] = d6; assign s[5] = s6;
  assign d[6] = d7; assign s[6] = s7;
  assign d[7] = d8; assign s[7] = s8;

  // Keys for sorting: k = s - d (minimize immediate space usage)
  wire signed [10:0] k [0:7];
  genvar gi;
  for (gi = 0; gi < 8; gi = gi + 1) begin : KGEN
    assign k[gi] = $signed(s[gi]) - $signed(d[gi]);
  end

  // Sorting network (bubble sort network) - stable and combinational
  function [3:0] idx_of;
    input [3:0] i;
    case (i)
      4'd0: idx_of = 4'd0; 4'd1: idx_of = 4'd1; 4'd2: idx_of = 4'd2; 4'd3: idx_of = 4'd3;
      4'd4: idx_of = 4'd4; 4'd5: idx_of = 4'd5; 4'd6: idx_of = 4'd6; 4'd7: idx_of = 4'd7;
      default: idx_of = 4'd0;
    endcase
  endfunction

  function [10:0] k_of;
    input [3:0] i;
    case (i)
      4'd0: k_of = k[0]; 4'd1: k_of = k[1]; 4'd2: k_of = k[2]; 4'd3: k_of = k[3];
      4'd4: k_of = k[4]; 4'd5: k_of = k[5]; 4'd6: k_of = k[6]; 4'd7: k_of = k[7];
      default: k_of = 11'sd0;
    endcase
  endfunction

  // Swap if out of order (preserve stability: use < for strict increase)
  function [3:0] swap_idx;
    input [3:0] a, b;
    input [10:0] ka, kb;
    if (ka < kb) begin
      swap_idx = b; // keep original order for ties (stable)
    end else begin
      swap_idx = a;
    end
  endfunction

  // 7 bubble iterations over 8 elements
  wire [3:0] idx_stage [0:7][0:7];
  // Stage 0 (input)
  for (gi = 0; gi < 8; gi = gi + 1) begin : IN_STAGE
    assign idx_stage[0][gi] = idx_of(gi[2:0]);
  end

  // Stages 1..7 (7 passes)
  for (gi = 1; gi < 8; gi = gi + 1) begin : SWAP_STAGES
    for (int j = 0; j < 7; j = j + 1) begin : COMP_SLOTS
      if (j == 0) begin
        // compare idx_stage[gi-1][0] and idx_stage[gi-1][1]
        assign idx_stage[gi][j] = swap_idx(
          idx_stage[gi-1][j],
          idx_stage[gi-1][j+1],
          k_of(idx_stage[gi-1][j]),
          k_of(idx_stage[gi-1][j+1])
        );
      end else begin
        // For j >= 1: first position already handled by previous compare at j-1
        // We compare positions (j, j+1) using previous stage outputs
        assign idx_stage[gi][j] = swap_idx(
          idx_stage[gi-1][j],
          idx_stage[gi-1][j+1],
          k_of(idx_stage[gi-1][j]),
          k_of(idx_stage[gi-1][j+1])
        );
      end
    end
    // Last element passes through
    assign idx_stage[gi][7] = idx_stage[gi-1][7];
  end

  // Final sorted indices
  wire [3:0] sorted_idx [0:7];
  for (gi = 0; gi < 8; gi = gi + 1) begin : OUT_IDX
    assign sorted_idx[gi] = idx_stage[7][gi];
  end

  // Installability checks per sorted position: can install if remaining >= max(d,s)
  wire [9:0] req [0:7];
  for (gi = 0; gi < 8; gi = gi + 1) begin : REQ_GEN
    assign req[gi] = (d[sorted_idx[gi]] > s[sorted_idx[gi]]) ? d[sorted_idx[gi]] : s[sorted_idx[gi]];
  end

  // Sequential control FSM
  localparam IDLE = 3'b000;
  localparam WORK = 3'b001;
  localparam DONE = 3'b010;

  reg [3:0] phase;        // 0..12
  reg [3:0] next_phase;
  reg [3:0] state, next_state;
  reg [3:0] installed;    // running count (0..8)
  reg [3:0] curr_idx [0:7];
  reg install_candidate;  // whether current candidate fits
  reg [9:0] remaining_space;

  integer ii, jj;

  // Next-state logic
  always_comb begin
    next_state = state;
    next_phase = phase;
    case (state)
      IDLE: begin
        next_phase = 4'd0;
        if (start) begin
          next_state = WORK;
          next_phase = 4'd1;
        end
      end
      WORK: begin
        if (phase >= 4'd8) begin
          next_state = DONE;
          next_phase = 4'd11;
        end else begin
          next_phase = phase + 1'b1;
        end
      end
      DONE: begin
        next_state = IDLE;
        next_phase = 4'd0;
      end
      default: begin
        next_state = IDLE;
        next_phase = 4'd0;
      end
    endcase
  end

  // State and phase update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      phase <= 4'd0;
    end else begin
      state <= next_state;
      phase <= next_phase;
    end
  end

  // Compute current installability combinatorially from sorted list and phase
  always_comb begin
    install_candidate = 1'b0;
    if (state == WORK && phase >= 4'd1 && phase <= 4'd8) begin
      install_candidate = (remaining_space >= req[phase-1]) ? 1'b1 : 1'b0;
    end
  end

  // Sequential updates during WORK
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      installed <= 4'd0;
      remaining_space <= 10'd0;
      for (ii = 0; ii < 8; ii = ii + 1) curr_idx[ii] <= 4'd0;
    end else begin
      if (state == IDLE) begin
        installed <= 4'd0;
        remaining_space <= 10'd0;
        for (ii = 0; ii < 8; ii = ii + 1) curr_idx[ii] <= 4'd0;
      end else if (state == WORK) begin
        if (phase == 4'd1) begin
          installed <= 4'd0;
          remaining_space <= c;
          for (ii = 0; ii < 8; ii = ii + 1) curr_idx[ii] <= 4'd0;
        end else if (phase >= 4'd2 && phase <= 4'd9) begin
          // Apply decision for position (phase-2) in WORK
          if (install_candidate) begin
            installed <= installed + 1'b1;
            remaining_space <= remaining_space - s[sorted_idx[phase-2]];
            curr_idx[installed] <= sorted_idx[phase-2];
          end
        end
        // phase 10+: no change
      end
    end
  end

  // Output registers and done pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_count <= 4'd0;
      for (ii = 0; ii < 8; ii = ii + 1) order[ii] <= 4'd0;
      done <= 1'b0;
    end else begin
      if (state == IDLE) begin
        max_count <= 4'd0;
        for (ii = 0; ii < 8; ii = ii + 1) order[ii] <= 4'd0;
        done <= 1'b0;
      end else if (state == WORK) begin
        if (phase == 4'd10) begin
          max_count <= installed;
          for (ii = 0; ii < 8; ii = ii + 1) begin
            if (ii < installed) order[ii] <= curr_idx[ii];
            else order[ii] <= 4'd0;
          end
          done <= 1'b0;
        end
      end else if (state == DONE) begin
        // Pulse done for exactly 1 cycle
        done <= 1'b1;
      end
    end
  end

endmodule
