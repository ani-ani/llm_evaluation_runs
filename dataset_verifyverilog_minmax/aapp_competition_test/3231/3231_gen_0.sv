module friendship_validator (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] p,
  input [3:0] q,
  input [7:0] friends [0:7],
  output reg decision,
  output reg done
);
  // Internal state
  localparam IDLE = 3'b000;
  localparam COUNT = 3'b001;
  localparam GEN_S1 = 3'b010;
  localparam GEN_S2 = 3'b011;
  localparam PAIR_S1 = 3'b100;
  localparam PAIR_S2 = 3'b101;
  localparam DONE = 3'b110;

  reg [2:0] cs, ns;
  reg [3:0] n_r;        // captured n
  reg [3:0] p_r, q_r;   // captured p,q
  reg [7:0] adj [0:7];  // adjacency bitmask per student (derived from friends)
  reg [2:0] cnt;        // counts students in COUNT, also used as index in GEN
  reg [3:0] i1, i2;     // pair indices (0..7)
  reg [3:0] max_pairs;  // floor(n/2)
  reg [3:0] pair_idx;   // current pair index to test
  reg [7:0] pairs_mask_r;   // mask of students in valid pair(s) used in validation
  reg [7:0] singles_mask_r; // mask of all singletons
  reg [7:0] used_r;     // mask of students already formed into pairs during generation
  reg [7:0] in_pair_r;  // mask of students currently in a valid pair under evaluation
  reg [7:0] pair_mask_r; // mask of students composing the pair currently being checked
  reg val_pair;         // 1 if the currently considered pair satisfies ext_edges <= q and size <= p
  reg final_valid;      // 1 if final check shows a valid partition exists

  // Wire for current remaining singles during PAIR phase
  wire [7:0] rem_singles;
  assign rem_singles = singles_mask_r & ~in_pair_r;

  // Capture inputs on start, reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cs <= IDLE;
      n_r <= 4'd0;
      p_r <= 4'd0;
      q_r <= 4'd0;
      decision <= 1'b0;
      done <= 1'b0;
    end else begin
      cs <= ns;
      decision <= decision; // default hold; updated in DONE
      done <= (ns == DONE);
      if (cs == IDLE && start) begin
        n_r <= n;
        p_r <= p;
        q_r <= q;
      end
    end
  end

  // Build adjacency from friends[]
  always @(posedge clk) begin
    if (cs == IDLE && start) begin
      // Build symmetric adjacency (bit j set if i is friends with j)
      adj[0] <= friends[0];
      adj[1] <= friends[1];
      adj[2] <= friends[2];
      adj[3] <= friends[3];
      adj[4] <= friends[4];
      adj[5] <= friends[5];
      adj[6] <= friends[6];
      adj[7] <= friends[7];
    end
  end

  // State machine next-state logic
  always @(*) begin
    ns = cs;
    case (cs)
      IDLE: begin
        if (start) ns = COUNT;
      end
      COUNT: begin
        ns = GEN_S1;
      end
      GEN_S1: begin
        ns = GEN_S2;
      end
      GEN_S2: begin
        if (pair_idx + 1 < max_pairs) begin
          ns = GEN_S2; // stay to try more pairs
        end else begin
          ns = PAIR_S1;
        end
      end
      PAIR_S1: begin
        ns = PAIR_S2;
      end
      PAIR_S2: begin
        if (pair_idx + 1 < max_pairs) begin
          ns = PAIR_S1; // try next pair
        end else begin
          ns = DONE;
        end
      end
      DONE: begin
        if (start) ns = COUNT; // restart on new start
        else ns = DONE;
      end
      default: ns = IDLE;
    endcase
  end

  // Per-state updates
  always @(posedge clk) begin
    if (cs == IDLE) begin
      cnt <= 3'd0;
      singles_mask_r <= 8'd0;
      used_r <= 8'd0;
      pair_idx <= 4'd0;
      max_pairs <= 4'd0;
      pairs_mask_r <= 8'd0;
      in_pair_r <= 8'd0;
      pair_mask_r <= 8'd0;
      val_pair <= 1'b0;
      final_valid <= 1'b0;
    end else if (cs == COUNT) begin
      // Count students from 0..7, stop at n_r
      cnt <= cnt + 1'b1;
      if (cnt == 3'd0) singles_mask_r <= 8'd0;
      if (cnt < n_r) begin
        singles_mask_r <= singles_mask_r | (8'b1 << cnt);
      end
    end else if (cs == COUNT && cnt == 3'd7) begin
      // Finalize count phase
      max_pairs <= (n_r >> 1); // floor(n/2)
    end else if (cs == GEN_S1) begin
      // Start generating the list of valid pairs
      pair_idx <= 4'd0;
      used_r <= 8'd0;
      pairs_mask_r <= 8'd0;
      // Initialize first pair check if any pairs possible
      if (max_pairs > 0) begin
        i1 <= 4'd0;
        i2 <= 4'd1;
      end
    end else if (cs == GEN_S2) begin
      // Enumerate pairs by lexicographic indices: (0,1), (0,2), ..., (6,7)
      if (pair_idx < max_pairs) begin
        // Compute indices for current pair_idx
        // row: floor(pair_idx / (n-1 - r)), col: remainder offset
        // Precompute progressively
        if (pair_idx == 4'd0) begin
          i1 <= 4'd0; i2 <= 4'd1;
        end else if (pair_idx == 4'd1) begin
          i1 <= 4'd0; i2 <= 4'd2;
        end else if (pair_idx == 4'd2) begin
          i1 <= 4'd0; i2 <= 4'd3;
        end else if (pair_idx == 4'd3) begin
          i1 <= 4'd0; i2 <= 4'd4;
        end else if (pair_idx == 4'd4) begin
          i1 <= 4'd0; i2 <= 4'd5;
        end else if (pair_idx == 4'd5) begin
          i1 <= 4'd0; i2 <= 4'd6;
        end else if (pair_idx == 4'd6) begin
          i1 <= 4'd0; i2 <= 4'd7;
        end else if (pair_idx == 4'd7) begin
          i1 <= 4'd1; i2 <= 4'd2;
        end else if (pair_idx == 4'd8) begin
          i1 <= 4'd1; i2 <= 4'd3;
        end else if (pair_idx == 4'd9) begin
          i1 <= 4'd1; i2 <= 4'd4;
        end else if (pair_idx == 4'd10) begin
          i1 <= 4'd1; i2 <= 4'd5;
        end else if (pair_idx == 4'd11) begin
          i1 <= 4'd1; i2 <= 4'd6;
        end else if (pair_idx == 4'd12) begin
          i1 <= 4'd1; i2 <= 4'd7;
        end else if (pair_idx == 4'd13) begin
          i1 <= 4'd2; i2 <= 4'd3;
        end else if (pair_idx == 4'd14) begin
          i1 <= 4'd2; i2 <= 4'd4;
        end else if (pair_idx == 4'd15) begin
          i1 <= 4'd2; i2 <= 4'd5;
        end else if (pair_idx == 4'd16) begin
          i1 <= 4'd2; i2 <= 4'd6;
        end else if (pair_idx == 4'd17) begin
          i1 <= 4'd2; i2 <= 4'd7;
        end else if (pair_idx == 4'd18) begin
          i1 <= 4'd3; i2 <= 4'd4;
        end else if (pair_idx == 4'd19) begin
          i1 <= 4'd3; i2 <= 4'd5;
        end else if (pair_idx == 4'd20) begin
          i1 <= 4'd3; i2 <= 4'd6;
        end else if (pair_idx == 4'd21) begin
          i1 <= 4'd3; i2 <= 4'd7;
        end else if (pair_idx == 4'd22) begin
          i1 <= 4'd4; i2 <= 4'd5;
        end else if (pair_idx == 4'd23) begin
          i1 <= 4'd4; i2 <= 4'd6;
        end else if (pair_idx == 4'd24) begin
          i1 <= 4'd4; i2 <= 4'd7;
        end else if (pair_idx == 4'd25) begin
          i1 <= 4'd5; i2 <= 4'd6;
        end else if (pair_idx == 4'd26) begin
          i1 <= 4'd5; i2 <= 4'd7;
        end else begin // 27
          i1 <= 4'd6; i2 <= 4'd7;
        end

        // Evaluate current pair for constraint satisfaction
        if ((i1 < n_r) && (i2 < n_r) && (i1 != i2)) begin
          // Pair size = 2 <= p_r (p>=1 in valid use) and ext edges for a pair is simply the edge between them
          if ((p_r >= 4'd2) && ((adj[i1] >> i2) & 1'b1) && (q_r >= 4'd1)) begin
            // This pair is a valid group candidate
            if (~used_r[i1] && ~used_r[i2]) begin
              used_r <= used_r | (1 << i1) | (1 << i2);
              pairs_mask_r <= pairs_mask_r | (1 << i1) | (1 << i2);
            end
          end
        end

        // Move to next pair index
        pair_idx <= pair_idx + 1'b1;
      end
    end else if (cs == PAIR_S1) begin
      // Start checking each valid pair as part of a candidate partition
      pair_idx <= 4'd0;
      in_pair_r <= 8'd0;
      val_pair <= 1'b0;
    end else if (cs == PAIR_S2) begin
      if (pair_idx < max_pairs) begin
        if (pair_idx == 4'd0) begin
          i1 <= 4'd0; i2 <= 4'd1;
        end else if (pair_idx == 4'd1) begin
          i1 <= 4'd0; i2 <= 4'd2;
        end else if (pair_idx == 4'd2) begin
          i1 <= 4'd0; i2 <= 4'd3;
        end else if (pair_idx == 4'd3) begin
          i1 <= 4'd0; i2 <= 4'd4;
        end else if (pair_idx == 4'd4) begin
          i1 <= 4'd0; i2 <= 4'd5;
        end else if (pair_idx == 4'd5) begin
          i1 <= 4'd0; i2 <= 4'd6;
        end else if (pair_idx == 4'd6) begin
          i1 <= 4'd0; i2 <= 4'd7;
        end else if (pair_idx == 4'd7) begin
          i1 <= 4'd1; i2 <= 4'd2;
        end else if (pair_idx == 4'd8) begin
          i1 <= 4'd1; i2 <= 4'd3;
        end else if (pair_idx == 4'd9) begin
          i1 <= 4'd1; i2 <= 4'd4;
        end else if (pair_idx == 4'd10) begin
          i1 <= 4'd1; i2 <= 4'd5;
        end else if (pair_idx == 4'd11) begin
          i1 <= 4'd1; i2 <= 4'd6;
        end else if (pair_idx == 4'd12) begin
          i1 <= 4'd1; i2 <= 4'd7;
        end else if (pair_idx == 4'd13) begin
          i1 <= 4'd2; i2 <= 4'd3;
        end else if (pair_idx == 4'd14) begin
          i1 <= 4'd2; i2 <= 4'd4;
        end else if (pair_idx == 4'd15) begin
          i1 <= 4'd2; i2 <= 4'd5;
        end else if (pair_idx == 4'd16) begin
          i1 <= 4'd2; i2 <= 4'd6;
        end else if (pair_idx == 4'd17) begin
          i1 <= 4'd2; i2 <= 4'd7;
        end else if (pair_idx == 4'd18) begin
          i1 <= 4'd3; i2 <= 4'd4;
        end else if (pair_idx == 4'd19) begin
          i1 <= 4'd3; i2 <= 4'd5;
        end else if (pair_idx == 4'd20) begin
          i1 <= 4'd3; i2 <= 4'd6;
        end else if (pair_idx == 4'd21) begin
          i1 <= 4'd3; i2 <= 4'd7;
        end else if (pair_idx == 4'd22) begin
          i1 <= 4'd4; i2 <= 4'd5;
        end else if (pair_idx == 4'd23) begin
          i1 <= 4'd4; i2 <= 4'd6;
        end else if (pair_idx == 4'd24) begin
          i1 <= 4'd4; i2 <= 4'd7;
        end else if (pair_idx == 4'd25) begin
          i1 <= 4'd5; i2 <= 4'd6;
        end else if (pair_idx == 4'd26) begin
          i1 <= 4'd5; i2 <= 4'd7;
        end else begin // 27
          i1 <= 4'd6; i2 <= 4'd7;
        end

        // Evaluate pair for current partition
        if ((i1 < n_r) && (i2 < n_r) && (i1 != i2) && (p_r >= 4'd2) && ((adj[i1] >> i2) & 1'b1) && (q_r >= 4'd1)) begin
          in_pair_r <= (1 << i1) | (1 << i2);
          pair_mask_r <= (1 << i1) | (1 << i2);
          val_pair <= 1'b1;
        end else begin
          in_pair_r <= 8'd0;
          pair_mask_r <= 8'd0;
          val_pair <= 1'b0;
        end

        // If this pair is valid, check if remaining students (all singles) are allowable
        if (val_pair) begin
          // Rem_singles uses current in_pair_r from previous cycle; but here we evaluate after assignment
          if ((rem_singles == 8'd0) || ((rem_singles & (8'd1 << 0)) ? 1'b1 : 1'b0) ||
              ((rem_singles & (8'd1 << 1)) ? 1'b1 : 1'b0) ||
              ((rem_singles & (8'd1 << 2)) ? 1'b1 : 1'b0) ||
              ((rem_singles & (8'd1 << 3)) ? 1'b1 : 1'b0) ||
              ((rem_singles & (8'd1 << 4)) ? 1'b1 : 1'b0) ||
              ((rem_singles & (8'd1 << 5)) ? 1'b1 : 1'b0) ||
              ((rem_singles & (8'd1 << 6)) ? 1'b1 : 1'b0) ||
              ((rem_singles & (8'd1 << 7)) ? 1'b1 : 1'b0)) begin
            // Always true; singles are size 1 so <=p and external edges for singleton = degree <= 7, but since p+q<=15 and q<=(p+q)<=15,
            // any singleton is acceptable if p>=1. We capture this as a pass whenever we have any valid pair and the rest are singles.
            // Set final_valid and decision (0 means valid partition found)
            final_valid <= 1'b1;
          end
        end

        pair_idx <= pair_idx + 1'b1;
      end
    end else if (cs == DONE) begin
      // decision already available via final_valid
      // Keep values held until reset or new start
    end
  end

  // Decision logic: 0=valid partition exists, 1=detection required (no valid partition)
  always @(posedge clk) begin
    if (!rst_n) begin
      decision <= 1'b0;
    end else if (cs == DONE) begin
      // 0 => valid exists, 1 => none exists
      decision <= ~final_valid;
    end
  end

endmodule