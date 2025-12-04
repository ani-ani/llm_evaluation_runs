module t_return_day_finder(
  input clk,      // clock signal
  input rst_n,    // active-low reset
  input start,    // pulse high to start computation
  input [4:0] L,  // 5-bit window start (L <= 16)
  input [15:0] adj_matrix_row0, // 4 entries (j0-3) for node1, 4 bits each [3:0][3:0]
  input [15:0] adj_matrix_row1, // node2 connections
  input [15:0] adj_matrix_row2, // node3 connections
  output reg signed [5:0] T_out,  // -1 to 31 range (6-bit signed)
  output reg done           // high when result ready
);

// Fixed-point: Q10.10, 20-bit
localparam FP_W = 20;
localparam FRAC_W = 10;
localparam ONE = 1 << FRAC_W;         // 1024 = 1.0 in Q10.10
localparam TGT  = 20'h3e800;          // 0.95 * 1024 = 0x3e800
localparam TOL  = 2;                  // +/-1 in scaled units ~= +/-0.001

// States
localparam ST_IDLE         = 3'd0;
localparam ST_INIT         = 3'd1;
localparam ST_COMPUTE_DAY  = 3'd2;
localparam ST_DONE         = 3'd3;

// Internal signals
reg [2:0] state, next_state;
reg signed [5:0] T_curr;           // current day T in [L..L+9]
reg signed [5:0] last_valid_day;   // -1 default if none found
reg [FP_W-1:0] p_node1, p_node2, p_node3, p_node4;  // current-day probabilities
reg [FP_W-1:0] np_node1, np_node2, np_node3, np_node4; // next-day probabilities
reg [3:0] nbrs1, nbrs2, nbrs3, nbrs4; // neighbor bitmasks for each node (bits [0..3] for nodes [1..4])
reg [1:0] nbr_cnt1, nbr_cnt2, nbr_cnt3, nbr_cnt4; // number of outgoing neighbors (0..4)
reg tmp_match; // 1 if a match was found on current day

function [1:0] popcount4;
  input [3:0] x;
  integer i;
  begin
    popcount4 = 2'b0;
    for (i = 0; i < 4; i = i + 1) begin
      if (x[i]) popcount4 = popcount4 + 1'b1;
    end
  end
endfunction

function [5:0] abs_sub20;
  input [19:0] a, b;
  abs_sub20 = (a >= b) ? (a - b) : (b - a);
endfunction

function is_target;
  input [19:0] x;
  begin
    is_target = (abs_sub20(x, TGT) <= TOL);
  end
endfunction

// Parse adjacency rows into neighbor bitmasks
// adj_matrix_rowX: 4 entries (nibbles), each 4 bits => neighbor presence to nodes [1..4]
// node1 has implicit self-edge, others do not.
always_comb begin
  nbrs1 = 4'b0000;
  nbrs2 = 4'b0000;
  nbrs3 = 4'b0000;
  nbrs4 = 4'b0000;

  nbrs1[0] = 1'b1; // self
  nbrs1[1] = (adj_matrix_row0[3:0]   != 4'h0);
  nbrs1[2] = (adj_matrix_row0[7:4]   != 4'h0);
  nbrs1[3] = (adj_matrix_row0[11:8]  != 4'h0);

  nbrs2[0] = (adj_matrix_row1[3:0]   != 4'h0);
  nbrs2[1] = 1'b1; // self
  nbrs2[2] = (adj_matrix_row1[7:4]   != 4'h0);
  nbrs2[3] = (adj_matrix_row1[11:8]  != 4'h0);

  nbrs3[0] = (adj_matrix_row2[3:0]   != 4'h0);
  nbrs3[1] = (adj_matrix_row2[7:4]   != 4'h0);
  nbrs3[2] = 1'b1; // self
  nbrs3[3] = (adj_matrix_row2[11:8]  != 4'h0);

  // node4 has no outgoing row in input; it can still have a self-loop if needed (leave 0 here)
  nbrs4 = 4'b0000;

  nbr_cnt1 = popcount4(nbrs1);
  nbr_cnt2 = popcount4(nbrs2);
  nbr_cnt3 = popcount4(nbrs3);
  nbr_cnt4 = popcount4(nbrs4);
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= ST_IDLE;
    T_curr <= 6'sd0;
    last_valid_day <= 6'sd-1;
    p_node1 <= 20'd0;
    p_node2 <= 20'd0;
    p_node3 <= 20'd0;
    p_node4 <= 20'd0;
    np_node1 <= 20'd0;
    np_node2 <= 20'd0;
    np_node3 <= 20'd0;
    np_node4 <= 20'd0;
    T_out <= 6'sd-1;
    done <= 1'b0;
    tmp_match <= 1'b0;
  end else begin
    state <= next_state;

    case (state)
      ST_IDLE: begin
        T_out <= 6'sd-1;
        done <= 1'b0;
      end

      ST_INIT: begin
        // Day 1 initialization: node1 prob = 1.0 in Q10.10
        T_curr <= $signed(L); // T starts at L
        last_valid_day <= 6'sd-1;
        p_node1 <= ONE; // 1.0
        p_node2 <= 20'd0;
        p_node3 <= 20'd0;
        p_node4 <= 20'd0;
        np_node1 <= 20'd0;
        np_node2 <= 20'd0;
        np_node3 <= 20'd0;
        np_node4 <= 20'd0;
        T_out <= 6'sd-1;
        done <= 1'b0;
        tmp_match <= 1'b0;
      end

      ST_COMPUTE_DAY: begin
        // Propagate current day's probabilities to next day (uniform distribution over outgoing neighbors)
        np_node1 <= 20'd0;
        np_node2 <= 20'd0;
        np_node3 <= 20'd0;
        np_node4 <= 20'd0;

        if (nbr_cnt1 > 0) begin
          if (nbrs1[0]) np_node1 <= np_node1 + (p_node1 / nbr_cnt1);
          if (nbrs1[1]) np_node2 <= np_node2 + (p_node1 / nbr_cnt1);
          if (nbrs1[2]) np_node3 <= np_node3 + (p_node1 / nbr_cnt1);
          if (nbrs1[3]) np_node4 <= np_node4 + (p_node1 / nbr_cnt1);
        end

        if (nbr_cnt2 > 0) begin
          if (nbrs2[0]) np_node1 <= np_node1 + (p_node2 / nbr_cnt2);
          if (nbrs2[1]) np_node2 <= np_node2 + (p_node2 / nbr_cnt2);
          if (nbrs2[2]) np_node3 <= np_node3 + (p_node2 / nbr_cnt2);
          if (nbrs2[3]) np_node4 <= np_node4 + (p_node2 / nbr_cnt2);
        end

        if (nbr_cnt3 > 0) begin
          if (nbrs3[0]) np_node1 <= np_node1 + (p_node3 / nbr_cnt3);
          if (nbrs3[1]) np_node2 <= np_node2 + (p_node3 / nbr_cnt3);
          if (nbrs3[2]) np_node3 <= np_node3 + (p_node3 / nbr_cnt3);
          if (nbrs3[3]) np_node4 <= np_node4 + (p_node3 / nbr_cnt3);
        end

        if (nbr_cnt4 > 0) begin
          if (nbrs4[0]) np_node1 <= np_node1 + (p_node4 / nbr_cnt4);
          if (nbrs4[1]) np_node2 <= np_node2 + (p_node4 / nbr_cnt4);
          if (nbrs4[2]) np_node3 <= np_node3 + (p_node4 / nbr_cnt4);
          if (nbrs4[3]) np_node4 <= np_node4 + (p_node4 / nbr_cnt4);
        end

        // After propagation, check for match with target on node 4
        tmp_match <= is_target(np_node4) && (T_curr <= 6'sd31);
        if (tmp_match && (T_curr <= 6'sd31)) begin
          last_valid_day <= T_curr;
        end

        // Advance to next day, commit next-day state as current
        p_node1 <= np_node1;
        p_node2 <= np_node2;
        p_node3 <= np_node3;
        p_node4 <= np_node4;
        T_curr <= T_curr + 1;
      end

      ST_DONE: begin
        T_out <= last_valid_day;
        done <= 1'b1;
      end
    endcase
  end
end

// Next-state logic
always @(*) begin
  next_state = state;
  case (state)
    ST_IDLE: begin
      next_state = start ? ST_INIT : ST_IDLE;
    end
    ST_INIT: begin
      next_state = ST_COMPUTE_DAY;
    end
    ST_COMPUTE_DAY: begin
      if (T_curr >= (L + 9)) begin
        next_state = ST_DONE;
      end else begin
        next_state = ST_COMPUTE_DAY;
      end
    end
    ST_DONE: begin
      next_state = start ? ST_INIT : ST_DONE;
    end
    default: next_state = ST_IDLE;
  endcase
end

endmodule
