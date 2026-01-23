module priority_ceiling_scheduler #(
  parameter NUM_TASKS = 4,
  parameter NUM_RESOURCES = 4,
  parameter MAX_INSTRUCTIONS = 8,
  parameter MAX_COMPUTE = 10
)(
  input clk,
  input rst_n,
  input start,
  input config_valid,
  input [15:0] task_start_time [NUM_TASKS-1:0],
  input [3:0] task_priority [NUM_TASKS-1:0],
  input [1:0] task_inst_type [NUM_TASKS-1:0][MAX_INSTRUCTIONS-1:0],
  input [3:0] task_inst_data [NUM_TASKS-1:0][MAX_INSTRUCTIONS-1:0],
  input [3:0] task_inst_count [NUM_TASKS-1:0],
  input [3:0] resource_ceiling [NUM_RESOURCES-1:0],
  output reg result_valid,
  output reg [31:0] task_completion_time [NUM_TASKS-1:0],
  output reg [31:0] current_clock
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_CONFIG,
    UPDATE_RUNNING,
    CALC_PRIORITY,
    CHECK_BLOCKING,
    EXECUTE,
    DONE
  } state_t;

  state_t state, next_state;

  // Task state registers
  reg [3:0] current_priority [NUM_TASKS-1:0];
  reg [3:0] current_inst [NUM_TASKS-1:0];
  reg [3:0] compute_counter [NUM_TASKS-1:0];
  reg running [NUM_TASKS-1:0];
  reg blocked [NUM_TASKS-1:0];
  reg complete [NUM_TASKS-1:0];
  reg [3:0] resource_owner [NUM_RESOURCES-1:0];

  // Internal counters and flags
  reg [1:0] loop_counter;
  reg [3:0] priority_update_counter;
  reg [3:0] selected_task;
  reg task_selected;

  // Initialize all registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_clock <= 0;
      result_valid <= 0;
      for (int i = 0; i < NUM_TASKS; i++) begin
        current_priority[i] <= 0;
        current_inst[i] <= 0;
        compute_counter[i] <= 0;
        running[i] <= 0;
        blocked[i] <= 0;
        complete[i] <= 0;
        task_completion_time[i] <= 0;
      end
      for (int i = 0; i < NUM_RESOURCES; i++) begin
        resource_owner[i] <= 0;
      end
      loop_counter <= 0;
      priority_update_counter <= 0;
      selected_task <= 0;
      task_selected <= 0;
    end else begin
      state <= next_state;
      if (state == EXECUTE && task_selected) begin
        current_clock <= current_clock + 1;
      end
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD_CONFIG;
      end
      LOAD_CONFIG: begin
        if (config_valid) next_state = UPDATE_RUNNING;
      end
      UPDATE_RUNNING: begin
        next_state = CALC_PRIORITY;
      end
      CALC_PRIORITY: begin
        if (priority_update_counter == NUM_TASKS - 1) begin
          next_state = CHECK_BLOCKING;
        end
      end
      CHECK_BLOCKING: begin
        next_state = EXECUTE;
      end
      EXECUTE: begin
        if (result_valid) begin
          next_state = DONE;
        end else if (task_selected) begin
          next_state = UPDATE_RUNNING;
        end else begin
          next_state = UPDATE_RUNNING;
        end
      end
      DONE: begin
        next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Update running tasks
  always @(*) begin
    if (state == UPDATE_RUNNING) begin
      for (int i = 0; i < NUM_TASKS; i++) begin
        running[i] = (current_clock >= task_start_time[i]) && !complete[i];
      end
    end
  end

  // Calculate priorities
  always @(*) begin
    if (state == CALC_PRIORITY) begin
      int i = priority_update_counter;
      if (i < NUM_TASKS) begin
        current_priority[i] = task_priority[i];
        for (int j = 0; j < NUM_TASKS; j++) begin
          if (i != j && running[j] && blocked[j]) begin
            if (task_priority[j] > current_priority[i]) begin
              current_priority[i] = task_priority[j];
            end
          end
        end
      end
    end
  end

  // Check blocking status
  always @(*) begin
    if (state == CHECK_BLOCKING) begin
      for (int i = 0; i < NUM_TASKS; i++) begin
        blocked[i] = 0;
        if (running[i] && !complete[i]) begin
          if (task_inst_type[i][current_inst[i]] == 2'b01) begin // Lock instruction
            int resource = task_inst_data[i][current_inst[i]];
            if (resource_owner[resource] != 0) begin // Resource owned by another task
              blocked[i] = 1;
            end else begin
              for (int r = 0; r < NUM_RESOURCES; r++) begin
                if (resource_owner[r] == i + 1 && resource_ceiling[r] >= current_priority[i]) begin
                  blocked[i] = 1;
                end
              end
            end
          end
        end
      end
    end
  end

  // Execute instruction
  always @(*) begin
    if (state == EXECUTE) begin
      task_selected = 0;
      selected_task = 0;
      for (int i = 0; i < NUM_TASKS; i++) begin
        if (running[i] && !blocked[i] && !complete[i]) begin
          if (!task_selected || current_priority[i] > current_priority[selected_task]) begin
            task_selected = 1;
            selected_task = i;
          end
        end
      end

      if (task_selected) begin
        int task = selected_task;
        int inst = current_inst[task];
        int inst_type = task_inst_type[task][inst];
        int inst_data = task_inst_data[task][inst];

        case (inst_type)
          2'b00: begin // Compute
            if (compute_counter[task] == 0) begin
              compute_counter[task] = inst_data;
            end else begin
              compute_counter[task] = compute_counter[task] - 1;
              if (compute_counter[task] == 0) begin
                current_inst[task] = inst + 1;
              end
            end
          end
          2'b01: begin // Lock
            resource_owner[inst_data] = task + 1;
            current_inst[task] = inst + 1;
          end
          2'b10: begin // Unlock
            resource_owner[inst_data] = 0;
            current_inst[task] = inst + 1;
          end
          default: begin
            current_inst[task] = inst + 1;
          end
        endcase

        if (current_inst[task] >= task_inst_count[task]) begin
          complete[task] = 1;
          task_completion_time[task] = current_clock;
        end
      end

      // Check if all tasks are complete
      result_valid = 1;
      for (int i = 0; i < NUM_TASKS; i++) begin
        if (!complete[i]) begin
          result_valid = 0;
        end
      end
    end
  end

  // Priority update counter
  always @(*) begin
    if (state == CALC_PRIORITY) begin
      if (priority_update_counter == NUM_TASKS - 1) begin
        priority_update_counter = 0;
      end else begin
        priority_update_counter = priority_update_counter + 1;
      end
    end
  end

endmodule