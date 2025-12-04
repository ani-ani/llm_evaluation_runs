module room_equivalence_detector(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] room_count,
  input  [2:0] rooms [0:7][0:3],
  output reg [2:0] set_count,
  output reg [2:0] equivalent_sets [0:7][0:7],
  output reg done
);

  // ------------------------------------------------------------
  // Internal registers
  // ------------------------------------------------------------

  // Latched inputs (Stage 1)
  reg [2:0] room_count_reg;
  reg [2:0] rooms_reg [0:7][0:3];

  // Degrees of rooms (0..4)
  reg [2:0] degree [0:7];

  // Signature storage: each room has 1 (self degree) + 4 neighbor degrees = 5 entries
  // Each degree fits in 3 bits (0..4)
  reg [2:0] signature [0:7][0:4];

  // Stage / cycle control
  reg [4:0] cycle_cnt;       // counts from 0 upward
  reg       busy;            // indicates processing active

  // ------------------------------------------------------------
  // Helper functions
  // ------------------------------------------------------------

  // Get degree for a given room index from rooms_reg
  function automatic [2:0] calc_degree;
    input [2:0] ridx;
    integer j;
    reg [2:0] d;
    begin
      d = 3'd0;
      for (j = 0; j < 4; j = j + 1) begin
        if (rooms_reg[ridx][j][2] == 1'b1)
          d = d + 3'd1;
      end
      calc_degree = d;
    end
  endfunction

  // Check room index validity (1..room_count_reg), 0 is invalid sentinel
  function automatic bit valid_room_idx;
    input [2:0] idx;
    begin
      valid_room_idx = (idx != 3'd0) && (idx <= room_count_reg);
    end
  endfunction

  // Safely fetch neighbor degree by encoded idx; returns 0 if invalid
  function automatic [2:0] get_neighbor_degree;
    input [2:0] idx;
    begin
      if (valid_room_idx(idx))
        get_neighbor_degree = degree[idx-1];
      else
        get_neighbor_degree = 3'd0;
    end
  endfunction

  // Compare two signatures for equality
  function automatic bit same_signature;
    input [2:0] sig_a [0:4];
    input [2:0] sig_b [0:4];
    integer k;
    begin
      same_signature = 1'b1;
      for (k = 0; k < 5; k = k + 1) begin
        if (sig_a[k] != sig_b[k]) begin
          same_signature = 1'b0;
        end
      end
    end
  endfunction

  // ------------------------------------------------------------
  // Sequential control and datapath
  // ------------------------------------------------------------

  integer i, j, k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      cycle_cnt   <= 5'd0;
      busy        <= 1'b0;
      done        <= 1'b0;
      set_count   <= 3'd0;
      // Clear equivalent_sets
      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          equivalent_sets[i][j] <= 3'd0;
        end
      end
      // Clear latched inputs and internals
      room_count_reg <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          rooms_reg[i][j] <= 3'd0;
        end
        degree[i] <= 3'd0;
        for (k = 0; k < 5; k = k + 1) begin
          signature[i][k] <= 3'd0;
        end
      end
    end else begin
      // Default: hold done low unless finishing
      if (!busy)
        done <= 1'b0;

      // Start pulse: begin new operation only if not busy
      if (start && !busy) begin
        busy      <= 1'b1;
        cycle_cnt <= 5'd0;

        // Stage 1 (capture inputs) happens in this cycle
        room_count_reg <= room_count;
        for (i = 0; i < 8; i = i + 1) begin
          for (j = 0; j < 4; j = j + 1) begin
            rooms_reg[i][j] <= rooms[i][j];
          end
        end

        // Clear previous outputs and internals
        set_count <= 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
          for (j = 0; j < 8; j = j + 1) begin
            equivalent_sets[i][j] <= 3'd0;
          end
          degree[i] <= 3'd0;
          for (k = 0; k < 5; k = k + 1) begin
            signature[i][k] <= 3'd0;
          end
        end

      end else if (busy) begin
        cycle_cnt <= cycle_cnt + 5'd1;

        // -----------------------------
        // Stage 2: cycles 1-8
        // Compute degree and 2-hop signature per room (one per cycle)
        // -----------------------------
        if (cycle_cnt >= 5'd0 && cycle_cnt < 5'd8) begin
          // Target room index for this cycle
          i = cycle_cnt[2:0]; // 0..7

          if (i < room_count_reg) begin
            // Compute own degree
            degree[i] <= calc_degree(i);
          end else begin
            degree[i] <= 3'd0;
          end
        end

        // After degrees are filled (next 8 cycles), compute full signatures
        // cycles 8-15: build signatures using stable 'degree'
        if (cycle_cnt >= 5'd8 && cycle_cnt < 5'd16) begin
          i = cycle_cnt[2:0]; // 0..7

          if (i < room_count_reg) begin
            // Self degree
            signature[i][0] <= degree[i];

            // Neighbor degrees (2-hop via neighbor degree)
            signature[i][1] <= get_neighbor_degree(rooms_reg[i][0][2] ? {1'b0,rooms_reg[i][0][1:0]} : 3'd0); // will be masked by valid_room_idx
            signature[i][2] <= get_neighbor_degree(rooms_reg[i][1][2] ? {1'b0,rooms_reg[i][1][1:0]} : 3'd0);
            signature[i][3] <= get_neighbor_degree(rooms_reg[i][2][2] ? {1'b0,rooms_reg[i][2][1:0]} : 3'd0);
            signature[i][4] <= get_neighbor_degree(rooms_reg[i][3][2] ? {1'b0,rooms_reg[i][3][1:0]} : 3'd0);
          end else begin
            // Pad with zeros for out-of-range rooms
            signature[i][0] <= 3'd0;
            signature[i][1] <= 3'd0;
            signature[i][2] <= 3'd0;
            signature[i][3] <= 3'd0;
            signature[i][4] <= 3'd0;
          end
        end

        // -----------------------------
        // Stage 3: cycles 16-23
        // Build equivalence sets based on signatures
        // Only use first 8 cycles of this stage per spec (16-23),
        // but we assert done at cycle 17 (18 cycles from start, counting start as cycle 0).
        // We'll complete grouping within that window.
        // -----------------------------
        if (cycle_cnt == 5'd16) begin
          // Build sets once using finalized signatures
          // visited flags
          reg visited [0:7];
          for (i = 0; i < 8; i = i + 1) begin
            visited[i] = 1'b0;
          end

          set_count <= 3'd0;

          // Temporary local to construct sets; commit to outputs
          // as we go to keep logic simple.
          for (i = 0; i < 8; i = i + 1) begin
            if (i < room_count_reg && !visited[i]) begin
              // Start a new potential set with room (i+1)
              reg [2:0] tmp_rooms [0:7];
              integer cnt;
              cnt = 0;

              tmp_rooms[cnt] = i[2:0] + 3'd1; // store 1-based room index
              cnt = cnt + 1;
              visited[i] = 1'b1;

              // Find all rooms j > i with same signature
              for (j = i + 1; j < 8; j = j + 1) begin
                if (j < room_count_reg && !visited[j]) begin
                  if (same_signature(signature[i], signature[j])) begin
                    tmp_rooms[cnt] = j[2:0] + 3'd1;
                    cnt = cnt + 1;
                    visited[j] = 1'b1;
                  end
                end
              end

              // If more than one room in this set, record as non-singleton set
              if (cnt > 1) begin
                // Insert in increasing order of smallest room index.
                // Since we scan i from 0..7, sets naturally appear sorted,
                // so we can append sequentially.
                integer sidx;
                sidx = set_count;

                // Clear row first
                for (k = 0; k < 8; k = k + 1) begin
                  equivalent_sets[sidx][k] <= 3'd0;
                end

                for (k = 0; k < cnt; k = k + 1) begin
                  equivalent_sets[sidx][k] <= tmp_rooms[k];
                end

                set_count <= set_count + 3'd1;
              end
            end
          end
        end

        // -----------------------------
        // Done assertion and hold behavior
        // -----------------------------
        // Per spec: assert done after 18 clock cycles from start.
        // With cycle_cnt starting at 0 on start, we assert at 17.
        if (cycle_cnt == 5'd17) begin
          done <= 1'b1;
          busy <= 1'b0; // free to accept next start; outputs held stable
        end
      end
    end
  end

endmodule