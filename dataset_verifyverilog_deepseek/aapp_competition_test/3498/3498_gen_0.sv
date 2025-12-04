module priority_scheduler(
  input clk,
  input rst_n,
  output reg [7:0] task_complete [0:3]
);

typedef enum {IDLE, RUNNING, COMPLETED} task_state_t;
typedef enum {ACQUIRE, RELEASE, COMPUTE} instruction_t;

// Task definition
reg [7:0] processor_time;
struct packed {
  task_state_t state;
  reg [1:0]   priority;
  reg [3:0]   resources;
  reg [7:0]   start_time;
  reg [2:0]   ip;             // Instruction pointer (max 8 instructions)
  instruction_t instructions[0:7];  // Instruction memory per task
} tasks[0:3];

// Resource definition
struct packed {
  reg [1:0] owner;
  reg [1:0] ceiling_priority;
} resources[0:3];

// Internal signals
reg all_tasks_complete;
reg [1:0] current_task;

// Initialize hardcoded configuration
initial begin
  // Initialize task instructions (sample compute-only tasks)
  foreach (tasks[i]) begin
    tasks[i].state = IDLE;
    tasks[i].start_time = i * 20;  // Staggered start times
    tasks[i].priority = 3 - i;     // Lower index = higher priority
    tasks[i].resources = 0;
    tasks[i].ip = 0;
    for (int j=0; j<8; j++)
      tasks[i].instructions[j] = COMPUTE;  // All compute ops
  end

  // Initialize resources
  foreach (resources[i]) begin
    resources[i].owner = 2'b11;  // 11 = unowned
    resources[i].ceiling_priority = i;  // Sample ceiling priorities
  end

  processor_time = 0;
  all_tasks_complete = 0;
  task_complete = '{default:0};
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    processor_time <= 0;
    all_tasks_complete <= 0;
    foreach (tasks[i]) begin
      tasks[i].state <= IDLE;
      tasks[i].ip <= 0;
      tasks[i].resources <= 0;
    end
    foreach (resources[i]) resources[i].owner <= 2'b11;
    task_complete <= '{default:0};
  end else if (!all_tasks_complete) begin
    // Check for running tasks
    reg [3:0] active_tasks;
    reg [3:0] blocked_tasks;
    reg [1:0] highest_priority = 2'b00;
    current_task = 2'b11;  // Invalid marker
    
    // Stage 1: Identify executable tasks
    foreach (tasks[i]) begin
      active_tasks[i] = (tasks[i].state == RUNNING) && (tasks[i].start_time <= processor_time);
      blocked_tasks[i] = 0;

      // Simple blocking check (would expand for actual protocol)
      if (tasks[i].resources != 0) 
        foreach (resources[j]) 
          if (resources[j].owner == i && resources[j].ceiling_priority < highest_priority)
            blocked_tasks[i] = 1;

      // Find highest priority non-blocked task
      if (active_tasks[i] && !blocked_tasks[i] && 
          (tasks[i].priority > highest_priority || current_task == 2'b11)) begin
        highest_priority = tasks[i].priority;
        current_task = i;
      end
    end

    // Stage 2: Execute task or advance time
    if (current_task != 2'b11) begin
      // Execute instruction
      case (tasks[current_task].instructions[tasks[current_task].ip])
        COMPUTE: begin
          if (tasks[current_task].ip == 7) begin  // Last instruction
            tasks[current_task].state <= COMPLETED;
            task_complete[current_task] <= processor_time;
          end else
            tasks[current_task].ip <= tasks[current_task].ip + 1;
        end
        // Placeholder for ACQUIRE/RELEASE implementation
        default: tasks[current_task].ip <= tasks[current_task].ip + 1;
      endcase
    end
    
    // Stage 3: Update processor time
    processor_time <= processor_time + 1;

    // Check completion status
    all_tasks_complete <= (tasks[0].state == COMPLETED) &&
                          (tasks[1].state == COMPLETED) &&
                          (tasks[2].state == COMPLETED) &&
                          (tasks[3].state == COMPLETED);
  end
end

endmodule