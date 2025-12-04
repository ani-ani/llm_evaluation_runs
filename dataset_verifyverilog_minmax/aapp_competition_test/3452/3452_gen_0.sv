module room_equivalence_detector(
  input clk,
  input rst_n,
  input start,
  input [2:0] room_count,
  input [7:0][3:0] rooms [0:7], // 8 rooms, 4 exits each: {valid, 3-bit room index}
  output reg [2:0] set_count,
  output reg [7:0][2:0] equivalent_sets,
  output reg done
);

  // Internal pipeline registers
  reg start_r, start_r2, start_r3;
  reg [2:0] rc_r, rc_r2, rc_r3;
  reg [7:0][3:0] rooms_r [0:7];

  // Stage 2: signatures per room
  reg [12:0] sig_r [0:7];
  reg [12:0] sig_next [0:7];

  // Stage 3: comparison masks and results
  reg [7:0] masks_r [0:7];
  reg [7:0] masks_next [0:7];
  reg [7:0] seen_r, seen_next;
  reg [2:0] idx_r, idx_next;
  reg [2:0] set_count_next;
  reg [7:0][2:0] eqsets_r [0:7];
  reg [7:0][2:0] eqsets_next [0:7];

  // Capture inputs (Stage 1) and pipeline enables
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_r <= 1'b0;
      start_r2 <= 1'b0;
      start_r3 <= 1'b0;
      rc_r <= 3'b0;
      rc_r2 <= 3'b0;
      rc_r3 <= 3'b0;
      rooms_r[0] <= 8'h0; rooms_r[1] <= 8'h0; rooms_r[2] <= 8'h0; rooms_r[3] <= 8'h0;
      rooms_r[4] <= 8'h0; rooms_r[5] <= 8'h0; rooms_r[6] <= 8'h0; rooms_r[7] <= 8'h0;
    end else begin
      start_r <= start;
      start_r2 <= start_r;
      start_r3 <= start_r2;
      rc_r <= room_count;
      rc_r2 <= rc_r;
      rc_r3 <= rc_r2;
      rooms_r <= rooms;
    end
  end

  // Stage 2: Compute signatures (8 cycles)
  // Signature format (13 bits): {deg(3), n1(3), n2(3), n3(3), n4(1-bit for deg==4?1:0)}
  always @(*) begin
    for (int i = 0; i < 8; i++) sig_next[i] = 13'b0;

    for (int i = 0; i < 8; i++) begin
      if (i < rc_r2) begin
        // Degree
        int deg; deg = 0;
        for (int e = 0; e < 4; e++) begin
          if (rooms_r[i][e][3]) deg = deg + 1;
        end
        sig_next[i][3:1] = deg[2:0]; // store deg in bits 3:1

        // Neighbor degrees
        int ng; ng = 0;
        for (int e = 0; e < 4; e++) begin
          if (rooms_r[i][e][3]) begin
            int rj; rj = rooms_r[i][e][2:0];
            if (rj < rc_r2) begin
              int d2; d2 = 0;
              for (int ee = 0; ee < 4; ee++) begin
                if (rooms_r[rj][ee][3]) d2 = d2 + 1;
              end
              case (ng)
                0: sig_next[i][6:4] = d2[2:0];
                1: sig_next[i][9:7] = d2[2:0];
                2: sig_next[i][12:10] = d2[2:0];
                default: ;
              endcase
            end
            ng = ng + 1;
            if (ng >= 4) break;
          end
        end

        // High bit set if degree==4 to differentiate padded vs real 4 neighbors
        if (deg == 4) sig_next[i][0] = 1'b1;
        else sig_next[i][0] = 1'b0;
      end else begin
        // Out of range: signature = 0
        sig_next[i] = 13'b0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) sig_r[i] <= 13'b0;
    end else if (start_r2) begin
      for (int i = 0; i < 8; i++) sig_r[i] <= sig_next[i];
    end
  end

  // Stage 3: Compare signatures and build equivalence sets (8 cycles)
  always @(*) begin
    // default: keep state (will be overwritten when start_r3 is asserted)
    for (int i = 0; i < 8; i++) masks_next[i] = masks_r[i];
    seen_next = seen_r;
    idx_next = idx_r;
    set_count_next = set_count;
    for (int i = 0; i < 8; i++) eqsets_next[i] = eqsets_r[i];

    if (start_r3) begin
      // Start of Stage 3: clear everything
      if (idx_r == 3'b0 && seen_r == 8'b0) begin
        for (int i = 0; i < 8; i++) masks_next[i] = 8'b0;
        for (int i = 0; i < 8; i++) eqsets_next[i] = 3'b0;
        seen_next = 8'b0;
        set_count_next = 3'b0;
        idx_next = 3'b0;
      end

      // Compare current idx_r to all others within room count
      if (idx_r < rc_r3) begin
        reg [7:0] mask; mask = 8'b0;
        for (int j = 0; j < 8; j++) begin
          if (j < rc_r3 && !seen_r[j] && (sig_r[j] == sig_r[idx_r])) begin
            mask[j] = 1'b1;
          end
        end
        masks_next[idx_r] = mask;

        // Save set if non-singleton
        if ($countones(mask) > 1) begin
          eqsets_next[set_count_next] = {mask[7], mask[6], mask[5], mask[4], mask[3], mask[2], mask[1], mask[0]};
          set_count_next = set_count_next + 1;
        end

        // Mark processed
        seen_next = seen_r | (1 << idx_r);
      end

      // Advance to next index
      idx_next = idx_r + 1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) masks_r[i] <= 8'b0;
      seen_r <= 8'b0;
      idx_r <= 3'b0;
      set_count <= 3'b0;
      for (int i = 0; i < 8; i++) eqsets_r[i] <= 3'b0;
      done <= 1'b0;
    end else begin
      for (int i = 0; i < 8; i++) masks_r[i] <= masks_next[i];
      seen_r <= seen_next;
      idx_r <= idx_next;
      set_count <= set_count_next;
      for (int i = 0; i < 8; i++) eqsets_r[i] <= eqsets_next[i];

      // done asserted 18 cycles after start; stable thereafter until next start
      if (start) begin
        done <= 1'b0;
      end else if (start_r3 && (idx_next == rc_r3)) begin
        done <= 1'b1;
      end
    end
  end

  // Pack output: 8 sets × 3 bits (3'b0 for unused sets)
  always @(*) begin
    equivalent_sets = 24'b0;
    for (int i = 0; i < 8; i++) begin
      equivalent_sets[i] = eqsets_r[i];
    end
  end

endmodule
