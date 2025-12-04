module teacher_rotation_tracker(
  input clk,
  input rst_n,
  input [1:0] cmd_type, // 0=add rotation, 1=query
  input [2:0] week,      // Week number (0-7)
  input [1:0] K,         // Rotation size (2-4) for cmd_type=0
  input [1:0] teacher_id_in, // Teacher list or teacher to query
  input wr_en,           // Pulse high for 1 cycle to write command
  output reg [1:0] class_out, // Query result (class ID)
  output reg query_valid      // High when result is valid
);

  // Internal storage
  reg [1:0] teacher_class [0:3]; // current assignments: index=teacher_id -> class
  reg [2:0] rot_weeks  [0:5];    // week for each rotation record
  reg [1:0] rot_lists  [0:5][0:3]; // teacher sequence per record (4 entries each)
  reg [1:0] rot_sizes  [0:5];    // K per record (2-4)
  reg        rot_valid [0:5];    // record valid flag

  // Write state (for building rotations across multiple cycles)
  reg [2:0] write_head;          // next record to write
  reg [2:0] write_count;         // pulses consumed for current record (0..K)
  reg [1:0] write_K;             // K for current record (captured on first pulse)
  reg [2:0] write_week_capture;  // week for current record (captured on first pulse)
  reg       write_active;        // building a rotation record
  reg       write_rot_part [0:3]; // 1-bit per slot to mark slots written in current record

  // Query/apply state machine
  reg [2:0] state_q, state_d;
  reg [2:0] query_week_q, query_week_d;
  reg [1:0] query_teacher_q, query_teacher_d;
  reg [2:0] pop_ptr;             // points to record to apply next (by week)
  reg [2:0] processed_cnt;       // how many records applied for this query

  localparam S_IDLE      = 3'b000;
  localparam S_Q_START   = 3'b001;
  localparam S_Q_APPLY   = 3'b010;
  localparam S_Q_DONE    = 3'b011;
  localparam S_Q_OUT     = 3'b100;

  integer i, j;

  // Sequential logic (async reset)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize: teacher i -> class i
      for (i = 0; i < 4; i = i + 1) teacher_class[i] <= i[1:0];

      for (i = 0; i < 6; i = i + 1) begin
        rot_valid[i] <= 1'b0;
        rot_sizes[i] <= 2'b0;
        rot_weeks[i] <= 3'b0;
        for (j = 0; j < 4; j = j + 1) rot_lists[i][j] <= 2'b0;
      end

      write_head      <= 3'b0;
      write_count     <= 3'b0;
      write_K         <= 2'b0;
      write_week_capture <= 3'b0;
      write_active    <= 1'b0;
      for (i = 0; i < 4; i = i + 1) write_rot_part[i] <= 1'b0;

      state_q         <= S_IDLE;
      query_week_q    <= 3'b0;
      query_teacher_q <= 2'b0;
      pop_ptr         <= 3'b0;
      processed_cnt   <= 3'b0;
      class_out       <= 2'b0;
      query_valid     <= 1'b0;
    end else begin
      // Defaults
      class_out    <= class_out;
      query_valid  <= 1'b0;
      state_q      <= state_d;
      query_week_q <= query_week_d;
      query_teacher_q <= query_teacher_d;

      // Rotation buffer write (multi-cycle capture for cmd_type==0)
      if (!write_active && cmd_type == 2'b00 && wr_en) begin
        // Start new rotation record
        write_active    <= 1'b1;
        write_K         <= K;            // 2..4
        write_week_capture <= week;      // capture week for this record
        write_count     <= 3'b1;         // first teacher received now
        write_rot_part[0] <= 1'b1;       // slot 0 filled
        rot_lists[write_head][0] <= teacher_id_in;
        // Note: rot_sizes and rot_weeks will be written when record completes
      end else if (write_active && cmd_type == 2'b00 && wr_en) begin
        // Continue capturing teachers for current record
        if (write_count < write_K) begin
          // write into next slot
          rot_lists[write_head][write_count[1:0]] <= teacher_id_in;
          write_rot_part[write_count[1:0]] <= 1'b1;
          write_count <= write_count + 1;
          // Complete when last teacher written
          if (write_count == (write_K - 1)) begin
            // Commit record
            rot_valid[write_head]  <= 1'b1;
            rot_sizes[write_head]  <= write_K;
            rot_weeks[write_head]  <= write_week_capture;
            // Advance head (circular)
            write_head <= (write_head == 3'd5) ? 3'b0 : (write_head + 1);
            // Reset write state
            write_active <= 1'b0;
            write_count  <= 3'b0;
            for (j = 0; j < 4; j = j + 1) write_rot_part[j] <= 1'b0;
          end
        end
      end

      // Query/apply state machine
      casez (state_q)
        S_IDLE: begin
          pop_ptr       <= 3'b0;
          processed_cnt <= 3'b0;
          if (cmd_type == 2'b01 && wr_en) begin
            state_q         <= S_Q_START;
            query_week_d    <= week;
            query_teacher_d <= teacher_id_in;
          end
        end

        S_Q_START: begin
          // Begin application phase
          state_q       <= S_Q_APPLY;
          pop_ptr       <= 3'b0;
          processed_cnt <= 3'b0;
        end

        S_Q_APPLY: begin
          // Apply up to 3 rotations per cycle that are valid and <= query_week
          // Track remaining count
          if (processed_cnt < 3'b110) begin
            // Attempt to apply rotations
            // Example apply logic is implemented in combinational block below
            // which updates teacher_class and pop_ptr atomically.
            // Here we only increment processed_cnt to count how many were applied.
            // The actual application is done in the combinational block that
            // writes teacher_class and manages pop_ptr.
            processed_cnt <= processed_cnt + 1;
            if (processed_cnt >= 3'b101) begin
              state_q <= S_Q_DONE;
            end
          end else begin
            state_q <= S_Q_DONE;
          end
        end

        S_Q_DONE: begin
          // Output result in this cycle
          class_out    <= teacher_class[query_teacher_q];
          query_valid  <= 1'b1;
          state_q      <= S_Q_OUT;
        end

        S_Q_OUT: begin
          // Return to idle; query_valid remains high for 1 cycle
          query_valid  <= 1'b0;
          state_q      <= S_IDLE;
        end

        default: state_q <= S_IDLE;
      endcase
    end
  end

  // Combinational application logic: process up to 3 rotations per cycle
  always_comb begin
    // Defaults: don't change these in comb block unless we apply
    // The actual state transitions and outputs are handled in seq block.
  end

  // Apply logic: done in an always block that runs every cycle so it updates
  // within the same cycle as the state transitions.
  // We do a single pass that can apply up to 3 records per cycle.
  reg [2:0] pop_ptr_next;
  reg [1:0] tmp_class [0:3];
  reg [2:0] apply_count;
  reg [2:0] weeks_q_int; // to make linter happy

  always @(*) begin
    weeks_q_int = query_week_q;
    // Initialize temporary assignment as current
    for (i = 0; i < 4; i = i + 1) tmp_class[i] = teacher_class[i];

    pop_ptr_next = pop_ptr;
    apply_count  = 3'b0;

    // We attempt to apply up to 3 records this cycle (if state_q == S_Q_APPLY)
    if (state_q == S_Q_APPLY) begin
      // Loop up to 6 records in order, trying to apply those that match criteria
      // and are not already processed in this query (we ensure by popping).
      for (i = 0; i < 6; i = i + 1) begin
        if (apply_count < 3) begin
          pop_ptr_next = (pop_ptr_next + 1) % 6;
          if (rot_valid[pop_ptr_next] && (rot_weeks[pop_ptr_next] <= weeks_q_int)) begin
            // Apply this rotation as a cyclic shift among the listed teachers
            // Format: [p0, p1, ..., pK-1]
            // Effect: class(pK-1) <- class(pK-2) <- ... <- class(p0) <- class(pK-1) (rotate right)
            // We implement as a local rotation on tmp_class
            for (j = 0; j < 4; j = j + 1) begin
              // NOP: keep original values; the rotation below will overwrite some
            end
            // Perform rotation using a small buffer
            reg [1:0] saved;
            if (rot_sizes[pop_ptr_next] >= 2) begin
              saved = tmp_class[ rot_lists[pop_ptr_next][rot_sizes[pop_ptr_next]-1] ];
              for (j = rot_sizes[pop_ptr_next]-1; j > 0; j = j - 1) begin
                tmp_class[ rot_lists[pop_ptr_next][j] ] =
                  tmp_class[ rot_lists[pop_ptr_next][j-1] ];
              end
              tmp_class[ rot_lists[pop_ptr_next][0] ] = saved;
            end
            // "Pop" the record: make it invalid and decrement count
            // We emulate pop by invalidating the current record and using pop pointer wrap.
            // Since we process strictly in increasing pointer order and we don't keep a count
            // of remaining here, we can just mark it invalid.
            // However, to keep head consistent for later writes, we will advance pop_ptr
            // in the sequential block below; we already moved pop_ptr_next here.
            apply_count = apply_count + 1;
          end
        end
      end
    end

    // Write back the updated assignments if any rotation was applied
    // Only update in the same cycle if we are applying (S_Q_APPLY)
    if (state_q == S_Q_APPLY) begin
      for (i = 0; i < 4; i = i + 1) teacher_class[i] = tmp_class[i];
    end
  end

  // Update pop_ptr and "pop" applied records (invalidate them) in seq block
  always @(posedge clk) begin
    if (!rst_n) begin
      // Already reset in main seq block; keep in sync
    end else begin
      if (state_q == S_Q_APPLY) begin
        // We need to propagate the pop pointer computed in comb block.
        // To avoid extra variables, we replicate a simple algorithm here:
        // Try to find and pop the next valid record with week <= query_week.
        // This is kept small so it fits in 1 cycle.
        // Because the comb block already rotated tmp_class and we have the same
        // conditions, we can just advance pop_ptr and invalidate the matched record here.
        // The exact record is the one that is the next valid and qualifying.
        // We implement a small loop to match the record that was applied in comb block.
        // Note: This design processes at most 3 records per S_Q_APPLY cycle.
        reg [2:0] local_ptr;
        reg [2:0] matches;
        local_ptr = pop_ptr;
        matches   = 3'b0;
        for (i = 0; i < 6; i = i + 1) begin
          local_ptr = (local_ptr + 1) % 6;
          if (rot_valid[local_ptr] && (rot_weeks[local_ptr] <= query_week_q)) begin
            // Invalidate this record (simulate pop)
            rot_valid[local_ptr] <= 1'b0;
            matches = matches + 1;
            if (matches >= 3) break;
          end
        end
        pop_ptr <= local_ptr; // update pointer to last matched
      end else if (state_q == S_IDLE) begin
        // Reset pop pointer when idle to keep future queries deterministic
        pop_ptr <= 3'b0;
      end
    end
  end

endmodule
