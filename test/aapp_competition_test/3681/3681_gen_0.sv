module teacher_rotation_tracker(
  input clk, // System clock
  input rst_n, // Active-low reset (async)
  input [1:0] cmd_type, // 0=add rotation, 1=query
  input [2:0] week, // Week number (0-7)
  input [1:0] K, // Rotation size (2-4) for cmd_type=0
  input [1:0] teacher_id_in, // Teacher ID (cmd_type=0: rotation list; cmd_type=1: teacher to query)
  input wr_en, // Pulse high for 1 cycle to write command
  output reg [1:0] class_out, // Query result (class ID)
  output reg query_valid // High when result is valid
);

  // Teacher-class assignment (index = teacher ID)
  reg [1:0] teacher_class [0:3];

  // Rotation storage (up to 6 records)
  reg [2:0] rot_weeks [0:5];
  reg [1:0] rot_lists [0:5][0:3];
  reg [1:0] rot_sizes [0:5];

  // Write tracking for rotation command assembly
  reg [2:0] rot_count;               // number of stored rotations (0..6)
  reg [2:0] rot_wr_idx;              // write index for new rotation record
  reg [1:0] rot_entry_idx;           // index within current rotation list (0..3)
  reg [1:0] pending_K;               // latched K for current rotation being written
  reg [2:0] pending_week;            // latched week for current rotation being written
  reg in_rotation_write;             // currently collecting rotation list

  // Query handling
  reg [1:0] query_teacher;           // requested teacher for current query
  reg [2:0] query_week;              // requested week for current query
  reg [1:0] query_pipe_valid;        // 2-stage pipeline for query_valid
  reg [1:0] class_pipe [1:2];        // pipeline for class_out (stages 1 and 2)

  // Temporary arrays for applying rotations during query
  reg [1:0] tmp_class [0:3];
  integer i, j;

  // Asynchronous reset and main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize teacher assignments: teacher i -> class i
      teacher_class[0] <= 2'd0;
      teacher_class[1] <= 2'd1;
      teacher_class[2] <= 2'd2;
      teacher_class[3] <= 2'd3;

      // Clear rotation storage
      for (i = 0; i < 6; i = i + 1) begin
        rot_weeks[i] <= 3'd0;
        rot_sizes[i] <= 2'd0;
        for (j = 0; j < 4; j = j + 1) begin
          rot_lists[i][j] <= 2'd0;
        end
      end

      rot_count         <= 3'd0;
      rot_wr_idx        <= 3'd0;
      rot_entry_idx     <= 2'd0;
      pending_K         <= 2'd0;
      pending_week      <= 3'd0;
      in_rotation_write <= 1'b0;

      query_teacher     <= 2'd0;
      query_week        <= 3'd0;
      query_pipe_valid  <= 2'b00;
      class_pipe[1]     <= 2'd0;
      class_pipe[2]     <= 2'd0;

      class_out         <= 2'd0;
      query_valid       <= 1'b0;
    end else begin
      // Default pipeline shift for query response
      query_valid      <= query_pipe_valid[1];
      query_pipe_valid <= {query_pipe_valid[0], 1'b0};
      class_out        <= class_pipe[2];
      class_pipe[2]    <= class_pipe[1];

      // ================= Command Handling =================
      if (wr_en) begin
        casez ({cmd_type, in_rotation_write})
          // Start a new rotation command (cmd_type=0, not currently writing)
          3'b00_0: begin
            in_rotation_write <= 1'b1;
            pending_K         <= K;
            pending_week      <= week;

            // Determine write index with capacity handling
            if (rot_count < 3'd6) begin
              rot_wr_idx <= rot_count;
              rot_count  <= rot_count + 3'd1;
            end else begin
              // Buffer full: overwrite last entry (index 5)
              rot_wr_idx <= 3'd5;
            end

            rot_entry_idx <= 2'd0;
            // Store first teacher in list
            rot_weeks[rot_wr_idx]        <= week;
            rot_sizes[rot_wr_idx]        <= K;
            rot_lists[rot_wr_idx][0]     <= teacher_id_in;
          end

          // Continue writing rotation list entries (still cmd_type=0, in_rotation_write=1)
          3'b00_1: begin
            if (rot_entry_idx + 1 < pending_K) begin
              rot_entry_idx <= rot_entry_idx + 2'd1;
              rot_lists[rot_wr_idx][rot_entry_idx + 1] <= teacher_id_in;
            end
            // When last entry written, close rotation write mode
            if (rot_entry_idx + 1 == pending_K - 1) begin
              in_rotation_write <= 1'b0;
            end
          end

          // If cmd_type=1 (query) while in_rotation_write, ignore query until rotation complete
          // Normal query command (cmd_type=1) when not writing rotation
          3'b01_0: begin
            // Latch query parameters
            query_teacher <= teacher_id_in;
            query_week    <= week;

            // Reconstruct assignments by applying all rotations <= query_week
            // Start from initial mapping
            tmp_class[0] <= 2'd0;
            tmp_class[1] <= 2'd1;
            tmp_class[2] <= 2'd2;
            tmp_class[3] <= 2'd3;

            // Apply each stored rotation in order of storage
            for (i = 0; i < 6; i = i + 1) begin
              if (i < rot_count && rot_sizes[i] >= 2 && rot_sizes[i] <= 4 && rot_weeks[i] <= week) begin
                // Build current classes for teachers in rotation
                reg [1:0] cur_class [0:3];
                integer k;
                for (k = 0; k < rot_sizes[i]; k = k + 1) begin
                  cur_class[k] = tmp_class[rot_lists[i][k]];
                end
                // Cyclic shift: teacher j gets class of previous teacher in list
                for (k = 0; k < rot_sizes[i]; k = k + 1) begin
                  integer prev_idx;
                  prev_idx = (k == 0) ? (rot_sizes[i] - 1) : (k - 1);
                  tmp_class[rot_lists[i][k]] <= cur_class[prev_idx];
                end
              end
            end

            // After applying all relevant rotations, capture result into pipeline stage 1
            class_pipe[1]    <= tmp_class[query_teacher];
            query_pipe_valid <= {query_pipe_valid[0], 1'b1};
          end

          default: begin
            // Ignore unsupported combinations / safe default
          end
        endcase
      end
    end
  end

endmodule