module priority_scheduler(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  output reg [7:0] task_complete [0:3] // Completion times for 4 tasks (8-bit time values)
);

  // -----------------------------
  // Parameters and constants
  // -----------------------------
  parameter NUM_TASKS = 4;
  parameter NUM_RES   = 4;
  parameter T_NORM    = 2'b00;
  parameter T_LOW     = 2'b01;
  parameter T_MED     = 2'b10;
  parameter T_HIGH    = 2'b11;

  // Instruction opcodes
  localparam NOP  = 3'b000;
  localparam COMP = 3'b001;
  localparam ACQ  = 3'b010;
  localparam REL  = 3'b011;
  localparam YLD  = 3'b100;

  // Control/configuration registers (configurable at init time)
  reg [7:0] cfg_task_start [0:3];    // start time per task
  reg [1:0] cfg_task_pri  [0:3];     // base priority per task
  reg [7:0] cfg_instr_mem [0:15];    // packed program memory [task*4 + 3:0]

  // Per-resource status
  reg [1:0] res_owner  [0:3];        // owner task id (2 bits, 2'b00 means none)
  reg [1:0] res_ceiling[0:3];        // priority ceiling per resource
  reg       res_busy   [0:3];        // busy flag per resource

  // Per-task active state during execution
  reg       task_active   [0:3];     // has the task been started?
  reg       task_complete [0:3];     // has the task finished?
  reg [7:0] task_ip       [0:3];     // instruction pointer (0..3)
  reg [7:0] task_hold_res [0:3];     // currently held resource (0=none, 1..4)

  reg [7:0] curr_time;
  reg       sched_idle;

  // Program decode signals
  wire [2:0] opcode [0:15];
  wire [1:0] arg    [0:15];
  wire [7:0] instr_addr_base;
  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : INSTR_DECODE
      assign opcode[gi] = cfg_instr_mem[gi][2:0];
      assign arg[gi]    = cfg_instr_mem[gi][4:3];
    end
  endgenerate

  // Helper functions
  function [1:0] max2 (input [1:0] a, input [1:0] b);
    if (a >= b) max2 = a; else max2 = b;
  endfunction

  function is_blocked (
    input [1:0] tid,
    input [1:0] tpri
  );
    integer r;
    reg [1:0] highest_ceiling;
    reg found_busy_ceiling;
    begin
      highest_ceiling = 2'b00;
      found_busy_ceiling = 1'b0;
      for (r = 0; r < NUM_RES; r = r + 1) begin
        if (res_busy[r]) begin
          found_busy_ceiling = 1'b1;
          if (res_ceiling[r] > highest_ceiling) highest_ceiling = res_ceiling[r];
        end
      end
      // blocked if there is any busy resource and task's priority is <= system ceiling
      // or if task owns a resource whose ceiling < task's own priority (PCP rule)
      is_blocked = 1'b0;
      if (found_busy_ceiling && (tpri <= highest_ceiling)) is_blocked = 1'b1;
      if (task_hold_res[tid] != 0) begin
        if (res_ceiling[task_hold_res[tid]-1] < tpri) is_blocked = 1'b1;
      end
    end
  endfunction

  task release_task_resources;
    input [1:0] tid;
    integer r;
    begin
      for (r = 0; r < NUM_RES; r = r + 1) begin
        if (res_owner[r] == tid) begin
          res_owner[r]  <= 2'b00;
          res_busy[r]   <= 1'b0;
        end
      end
      task_hold_res[tid] <= 8'b0;
    end
  endtask

  task load_default_config;
    integer i;
    begin
      // Defaults: start times and base priorities
      cfg_task_start[0] = 8'd0;  cfg_task_pri[0] = T_LOW;
      cfg_task_start[1] = 8'd2;  cfg_task_pri[1] = T_MED;
      cfg_task_start[2] = 8'd4;  cfg_task_pri[2] = T_HIGH;
      cfg_task_start[3] = 8'd6;  cfg_task_pri[3] = T_NORM;

      // Resource ceilings (2-bit priorities)
      res_ceiling[0] <= T_LOW;
      res_ceiling[1] <= T_MED;
      res_ceiling[2] <= T_HIGH;
      res_ceiling[3] <= T_HIGH;

      // Program memory default: task 0..3, each 4-byte program
      // T0: NOP, ACQ R0, COMP, REL R0
      cfg_instr_mem[0] <= {2'b00, 1'b0, NOP};          // 0x00
      cfg_instr_mem[1] <= {2'b00, 1'b1, ACQ};          // 0x02
      cfg_instr_mem[2] <= {2'b00, 1'b0, COMP};         // 0x01
      cfg_instr_mem[3] <= {2'b00, 1'b1, REL};          // 0x03
      // T1: NOP, ACQ R1, ACQ R0, COMP, REL R0, REL R1
      cfg_instr_mem[4] <= {2'b00, 1'b0, NOP};          // 0x00
      cfg_instr_mem[5] <= {2'b01, 1'b1, ACQ};          // 0x0a
      cfg_instr_mem[6] <= {2'b00, 1'b1, ACQ};          // 0x02
      cfg_instr_mem[7] <= {2'b00, 1'b0, COMP};         // 0x01
      cfg_instr_mem[8] <= {2'b00, 1'b1, REL};          // 0x03
      cfg_instr_mem[9] <= {2'b01, 1'b1, REL};          // 0x0b
      // Fill unused as NOPs (to keep deterministic reads)
      for (i = 10; i < 16; i = i + 1) begin
        cfg_instr_mem[i] <= {2'b00, 1'b0, NOP};
      end
    end
  endtask

  task reset_sched_state;
    integer t;
    begin
      for (t = 0; t < NUM_TASKS; t = t + 1) begin
        task_active[t]   <= 1'b0;
        task_complete[t] <= 1'b0;
        task_ip[t]       <= 8'd0;
        task_hold_res[t] <= 8'd0;
        task_complete[t] <= 1'b0;
        task_complete[t] <= 1'b0; // keep as 0 until set on completion
      end
      for (t = 0; t < NUM_RES; t = t + 1) begin
        res_owner[t] <= 2'b00;
        res_busy[t]  <= 1'b0;
      end
      curr_time  <= 8'd0;
      sched_idle <= 1'b0;
    end
  endtask

  // Output completion time on completion event
  always @(posedge clk) begin
    if (!rst_n) begin
      load_default_config;
      reset_sched_state;
    end else begin
      // Default no change for task_complete outputs; they are set below when a task finishes

      // Scheduler execution block
      begin
        integer t;
        reg [1:0] chosen_task;
        reg [1:0] chosen_pri;
        reg chosen_valid;
        reg [1:0] curr_opcode;
        reg [1:0] curr_arg;
        integer rtmp;

        chosen_valid = 1'b0;
        chosen_task  = 2'b00;
        chosen_pri   = 2'b00;

        // Find highest priority ready and non-blocked task
        for (t = 0; t < NUM_TASKS; t = t + 1) begin
          if (!task_active[t]) begin
            // not started yet
          end else if (task_complete[t]) begin
            // already finished
          end else begin
            // started and not finished
            if (curr_time >= cfg_task_start[t]) begin
              if (!is_blocked(t, cfg_task_pri[t])) begin
                if (!chosen_valid) begin
                  chosen_valid = 1'b1;
                  chosen_task  = t;
                  chosen_pri   = cfg_task_pri[t];
                end else begin
                  if (cfg_task_pri[t] > chosen_pri) begin
                    chosen_task = t;
                    chosen_pri  = cfg_task_pri[t];
                  end
                end
              end
            end
          end
        end

        // Schedule idle if no valid task to run
        if (!chosen_valid) begin
          sched_idle <= 1'b1;
          curr_time  <= curr_time + 1;
        end else begin
          sched_idle <= 1'b0;

          // Decode current instruction for the chosen task
          instr_addr_base = chosen_task * 4 + task_ip[chosen_task];
          curr_opcode = opcode[instr_addr_base];
          curr_arg    = arg[instr_addr_base];

          // Execute chosen task's instruction
          case (curr_opcode)
            NOP: begin
              // No-op: advance IP
              task_ip[chosen_task] <= task_ip[chosen_task] + 1;
            end
            COMP: begin
              // Complete this task
              task_complete[chosen_task] <= 1'b1;
              // Write completion time output
              task_complete[chosen_task] <= 1'b1;
              // Release any resources held by this task
              release_task_resources(chosen_task);
            end
            ACQ: begin
              // Try to acquire resource curr_arg (0..3)
              if (res_busy[curr_arg]) begin
                // Resource busy: do not advance time nor IP; retry next cycle
              end else if (res_owner[curr_arg] != 2'b00) begin
                // Already owned by someone (shouldn't happen if res_busy is consistent)
                // Stay here
              end else begin
                // Acquire
                res_busy[curr_arg]  <= 1'b1;
                res_owner[curr_arg] <= chosen_task;
                task_hold_res[chosen_task] <= curr_arg + 1; // store 1-based for clarity
                task_ip[chosen_task] <= task_ip[chosen_task] + 1;
              end
            end
            REL: begin
              // Release resource curr_arg (0..3)
              if ((res_owner[curr_arg] == chosen_task) && res_busy[curr_arg]) begin
                res_busy[curr_arg]  <= 1'b0;
                res_owner[curr_arg] <= 2'b00;
                if (task_hold_res[chosen_task] == (curr_arg + 1)) begin
                  task_hold_res[chosen_task] <= 8'd0;
                end
              end
              task_ip[chosen_task] <= task_ip[chosen_task] + 1;
            end
            YLD: begin
              // Yield: simply advance IP (useful for future extension)
              task_ip[chosen_task] <= task_ip[chosen_task] + 1;
            end
            default: begin
              // Unknown opcode: treat as NOP to avoid stalling
              task_ip[chosen_task] <= task_ip[chosen_task] + 1;
            end
          endcase

          // Time advances only when an instruction is actually executed (not on blocked or busy ACQ)
          if (curr_opcode == ACQ) begin
            if (res_busy[curr_arg]) begin
              // blocked on busy resource; do not advance time
            end else if (res_owner[curr_arg] != 2'b00) begin
              // inconsistent owner; do not advance time
            end else begin
              curr_time <= curr_time + 1;
            end
          end else begin
            // For NOP/COMP/REL/YLD/default, time advances
            curr_time <= curr_time + 1;
          end
        end

        // Start tasks when their start time arrives
        for (t = 0; t < NUM_TASKS; t = t + 1) begin
          if (!task_active[t] && (curr_time >= cfg_task_start[t])) begin
            task_active[t] <= 1'b1;
          end
        end
      end
    end
  end

  // Drive output completion times
  integer ti;
  always @(*) begin
    for (ti = 0; ti < NUM_TASKS; ti = ti + 1) begin
      if (task_complete[ti]) task_complete[ti] = curr_time;
    end
  end

endmodule