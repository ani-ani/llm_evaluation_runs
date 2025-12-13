module priority_scheduler(
  input  clk,
  input  rst_n,
  output reg [7:0] task_complete [0:3]
);

  // ---------------------------------------------------------------------------
  // Local parameters / encodings
  // ---------------------------------------------------------------------------
  localparam NUM_TASKS    = 4;
  localparam NUM_RES      = 4;
  localparam IP_WIDTH     = 3;       // supports up to 8 instructions per task
  localparam PRIORITY_W   = 2;       // 2-bit base priority
  localparam RES_W        = 2;       // 2-bit resource ID (0..3)
  localparam TIME_W       = 8;       // time counter width

  // Instruction opcodes
  localparam OP_NOP       = 2'b00;
  localparam OP_LOCK      = 2'b01;
  localparam OP_UNLOCK    = 2'b10;
  localparam OP_COMPUTE   = 2'b11;

  // Special value for "no owner"
  localparam [1:0] NO_OWNER = 2'b11; // owner field when resource is free

  // ---------------------------------------------------------------------------
  // Hardcoded task configuration
  // ---------------------------------------------------------------------------
  // For each task: base priority, start time, instruction memory and lengths.

  // Base priorities (0 = lowest, 3 = highest)
  // Task 0 highest, then 1,2,3 (example)
  wire [PRIORITY_W-1:0] base_prio   [0:NUM_TASKS-1];
  assign base_prio[0] = 2'd3;
  assign base_prio[1] = 2'd2;
  assign base_prio[2] = 2'd1;
  assign base_prio[3] = 2'd0;

  // Start times
  wire [TIME_W-1:0] start_time [0:NUM_TASKS-1];
  assign start_time[0] = 8'd0;
  assign start_time[1] = 8'd0;
  assign start_time[2] = 8'd0;
  assign start_time[3] = 8'd0;

  // Instruction memory: simple example programs.
  // Each instruction is 4 bits: [3:2]=OP, [1:0]=RES_ID/ignored
  // Task 0
  wire [3:0] t0_instr [0:7];
  assign t0_instr[0] = {OP_LOCK  , 2'd0}; // lock R0
  assign t0_instr[1] = {OP_COMPUTE, 2'd0};
  assign t0_instr[2] = {OP_COMPUTE, 2'd0};
  assign t0_instr[3] = {OP_UNLOCK, 2'd0}; // unlock R0
  assign t0_instr[4] = {OP_COMPUTE, 2'd0};
  assign t0_instr[5] = {OP_NOP    , 2'd0};
  assign t0_instr[6] = {OP_NOP    , 2'd0};
  assign t0_instr[7] = {OP_NOP    , 2'd0};

  // Task 1
  wire [3:0] t1_instr [0:7];
  assign t1_instr[0] = {OP_LOCK  , 2'd1};
  assign t1_instr[1] = {OP_COMPUTE, 2'd0};
  assign t1_instr[2] = {OP_UNLOCK, 2'd1};
  assign t1_instr[3] = {OP_COMPUTE, 2'd0};
  assign t1_instr[4] = {OP_NOP    , 2'd0};
  assign t1_instr[5] = {OP_NOP    , 2'd0};
  assign t1_instr[6] = {OP_NOP    , 2'd0};
  assign t1_instr[7] = {OP_NOP    , 2'd0};

  // Task 2
  wire [3:0] t2_instr [0:7];
  assign t2_instr[0] = {OP_COMPUTE, 2'd0};
  assign t2_instr[1] = {OP_LOCK  , 2'd2};
  assign t2_instr[2] = {OP_COMPUTE, 2'd0};
  assign t2_instr[3] = {OP_UNLOCK, 2'd2};
  assign t2_instr[4] = {OP_COMPUTE, 2'd0};
  assign t2_instr[5] = {OP_NOP    , 2'd0};
  assign t2_instr[6] = {OP_NOP    , 2'd0};
  assign t2_instr[7] = {OP_NOP    , 2'd0};

  // Task 3
  wire [3:0] t3_instr [0:7];
  assign t3_instr[0] = {OP_COMPUTE, 2'd0};
  assign t3_instr[1] = {OP_COMPUTE, 2'd0};
  assign t3_instr[2] = {OP_COMPUTE, 2'd0};
  assign t3_instr[3] = {OP_NOP    , 2'd0};
  assign t3_instr[4] = {OP_NOP    , 2'd0};
  assign t3_instr[5] = {OP_NOP    , 2'd0};
  assign t3_instr[6] = {OP_NOP    , 2'd0};
  assign t3_instr[7] = {OP_NOP    , 2'd0};

  // Instruction lengths
  wire [IP_WIDTH-1:0] task_len [0:NUM_TASKS-1];
  assign task_len[0] = 3'd5; // 0..4
  assign task_len[1] = 3'd4; // 0..3
  assign task_len[2] = 3'd5; // 0..4
  assign task_len[3] = 3'd3; // 0..2

  // Priority ceiling per resource (max base priority of tasks that may lock it)
  // Example static assignment
  wire [PRIORITY_W-1:0] res_ceiling [0:NUM_RES-1];
  assign res_ceiling[0] = 2'd3; // used by high-priority task 0
  assign res_ceiling[1] = 2'd2; // used by task 1
  assign res_ceiling[2] = 2'd1; // used by task 2
  assign res_ceiling[3] = 2'd0; // unused / lowest

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  // Global time
  reg [TIME_W-1:0] cur_time;

  // Per-task state
  reg [IP_WIDTH-1:0] ip          [0:NUM_TASKS-1]; // instruction pointer
  reg                done        [0:NUM_TASKS-1]; // completion flag
  reg [PRIORITY_W-1:0] eff_prio  [0:NUM_TASKS-1]; // effective priority
  reg [NUM_RES-1:0]  own_mask    [0:NUM_TASKS-1]; // bitmask of owned resources

  // Per-resource state
  reg [1:0] res_owner [0:NUM_RES-1]; // 2-bit owner index or NO_OWNER

  // All tasks finished flag
  reg all_done;

  // ---------------------------------------------------------------------------
  // Helper: combinational scheduling logic
  // ---------------------------------------------------------------------------

  integer i, r;

  // decode current instruction helper
  function automatic [3:0] get_instr;
    input [1:0] tid;
    input [IP_WIDTH-1:0] f_ip;
    begin
      case (tid)
        2'd0: get_instr = t0_instr[f_ip];
        2'd1: get_instr = t1_instr[f_ip];
        2'd2: get_instr = t2_instr[f_ip];
        2'd3: get_instr = t3_instr[f_ip];
        default: get_instr = {OP_NOP,2'b00};
      endcase
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Sequential process: compute priorities, select task, execute 1 instruction
  // ---------------------------------------------------------------------------

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_time <= {TIME_W{1'b0}};
      all_done <= 1'b0;

      for (i = 0; i < NUM_TASKS; i = i + 1) begin
        ip[i]         <= {IP_WIDTH{1'b0}};
        done[i]       <= 1'b0;
        own_mask[i]   <= {NUM_RES{1'b0}};
        eff_prio[i]   <= {PRIORITY_W{1'b0}};
        task_complete[i] <= {TIME_W{1'b0}};
      end

      for (r = 0; r < NUM_RES; r = r + 1) begin
        res_owner[r] <= NO_OWNER;
      end
    end else begin
      // If already all done, hold state
      if (all_done) begin
        cur_time <= cur_time; // hold
      end else begin
        // ---------------------------------------------------------------------
        // 1) Check completion, maintain done flags and completion times
        // ---------------------------------------------------------------------
        for (i = 0; i < NUM_TASKS; i = i + 1) begin
          if (!done[i] && (ip[i] >= task_len[i])) begin
            done[i] <= 1'b1;
            task_complete[i] <= cur_time; // mark completion time
          end
        end

        // ---------------------------------------------------------------------
        // 2) Compute effective priorities based on Priority Ceiling Protocol
        //    (Immediate Ceiling Priority Protocol style)
        // ---------------------------------------------------------------------
        for (i = 0; i < NUM_TASKS; i = i + 1) begin
          eff_prio[i] = base_prio[i];
        end

        // Priority inheritance via resource ceilings: owning task gets at
        // least the ceiling of any resource it holds.
        for (r = 0; r < NUM_RES; r = r + 1) begin
          if (res_owner[r] != NO_OWNER) begin
            if (eff_prio[res_owner[r]] < res_ceiling[r]) begin
              eff_prio[res_owner[r]] = res_ceiling[r];
            end
          end
        end

        // ---------------------------------------------------------------------
        // 3) Determine schedulable (ready and not blocked) task
        // ---------------------------------------------------------------------
        reg [1:0]  sel_task;
        reg        sel_valid;
        reg [PRIORITY_W-1:0] best_prio;

        sel_valid = 1'b0;
        sel_task  = 2'd0;
        best_prio = {PRIORITY_W{1'b0}};

        for (i = 0; i < NUM_TASKS; i = i + 1) begin
          if (!done[i] && (start_time[i] <= cur_time) && (ip[i] < task_len[i])) begin
            // Candidate task i: check if blocked by PCP
            // Blocked if exists a resource k, held by another task j, with
            // ceiling >= eff_prio[i], and i does not own that resource.
            reg blocked;
            blocked = 1'b0;
            for (r = 0; r < NUM_RES; r = r + 1) begin
              if (!blocked && (res_owner[r] != NO_OWNER) && (res_owner[r] != i[1:0])) begin
                if (res_ceiling[r] >= eff_prio[i]) begin
                  blocked = 1'b1;
                end
              end
            end

            if (!blocked) begin
              if (!sel_valid || (eff_prio[i] > best_prio) ||
                  ((eff_prio[i] == best_prio) && (i < sel_task))) begin
                sel_valid = 1'b1;
                sel_task  = i[1:0];
                best_prio = eff_prio[i];
              end
            end
          end
        end

        // ---------------------------------------------------------------------
        // 4) Execute one instruction of selected task (if any)
        // ---------------------------------------------------------------------
        if (sel_valid) begin
          reg [3:0] instr;
          reg [1:0] op;
          reg [1:0] rid;

          instr = get_instr(sel_task, ip[sel_task]);
          op    = instr[3:2];
          rid   = instr[1:0];

          case (op)
            OP_NOP: begin
              ip[sel_task] <= ip[sel_task] + 1'b1;
            end

            OP_COMPUTE: begin
              ip[sel_task] <= ip[sel_task] + 1'b1;
            end

            OP_LOCK: begin
              // Lock if free; PCP guarantees we only try when allowed.
              if (res_owner[rid] == NO_OWNER) begin
                res_owner[rid]       <= sel_task;
                own_mask[sel_task][rid] <= 1'b1;
                ip[sel_task]        <= ip[sel_task] + 1'b1;
              end
              else begin
                // Should not occur under correct PCP conditions; if it does,
                // treat as stall (do not advance IP).
                ip[sel_task] <= ip[sel_task];
              end
            end

            OP_UNLOCK: begin
              // Release resource if currently owned
              if (res_owner[rid] == sel_task) begin
                res_owner[rid]           <= NO_OWNER;
                own_mask[sel_task][rid]  <= 1'b0;
              end
              ip[sel_task] <= ip[sel_task] + 1'b1;
            end

            default: begin
              ip[sel_task] <= ip[sel_task] + 1'b1;
            end
          endcase

          // One unit of time per executed instruction
          cur_time <= cur_time + 1'b1;
        end else begin
          // No valid task to run in this cycle: time still progresses
          cur_time <= cur_time + 1'b1;
        end

        // ---------------------------------------------------------------------
        // 5) Update done flags again after IP moves and check for global done
        // ---------------------------------------------------------------------
        for (i = 0; i < NUM_TASKS; i = i + 1) begin
          if (!done[i] && (ip[i] >= task_len[i])) begin
            done[i] <= 1'b1;
            task_complete[i] <= cur_time; // completion time (end of last cycle)
          end
        end

        if (done[0] && done[1] && done[2] && done[3]) begin
          all_done <= 1'b1;
        end
      end
    end
  end

endmodule