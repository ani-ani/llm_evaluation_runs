module bug_fix_scheduler (
  input clk,
  input rst_n,
  input start,
  input [7:0] bug_complexity [0:7],
  input [7:0] student_ability [0:7],
  input [15:0] student_cost [0:7],
  input [15:0] budget,
  output reg [3:0] min_days,
  output reg [2:0] assignment [0:7],
  output reg done,
  output reg feasible
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    SORT_BUGS,
    BINARY_SEARCH,
    CHECK_SCHEDULE,
    DONE
  } state_t;
  state_t state;

  // Internal registers
  reg [3:0] days_low, days_high, days_mid;
  reg [3:0] best_days;
  reg [2:0] temp_assignment [0:7];
  reg [15:0] total_cost;
  reg [3:0] group_size;
  reg [3:0] group_idx, bug_idx, student_idx;
  reg [7:0] max_bug_in_group;
  reg [7:0] sorted_bugs [0:7];
  reg [7:0] temp_bugs [0:7];
  reg [15:0] min_cost;
  reg [2:0] best_student;
  reg valid_assignment;

  // Sorting logic (combinational)
  wire [7:0] sorted_bugs_comb [0:7];
  integer i, j;
  always_comb begin
    for (i = 0; i < 8; i = i + 1) begin
      sorted_bugs_comb[i] = bug_complexity[i];
    end
    // Simple bubble sort
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 7 - i; j = j + 1) begin
        if (sorted_bugs_comb[j] < sorted_bugs_comb[j + 1]) begin
          sorted_bugs_comb[j] = sorted_bugs_comb[j + 1];
          sorted_bugs_comb[j + 1] = bug_complexity[j];
        end
      end
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_days <= 0;
      feasible <= 0;
      done <= 0;
      days_low <= 1;
      days_high <= 16;
      best_days <= 16;
      group_idx <= 0;
      bug_idx <= 0;
      student_idx <= 0;
      total_cost <= 0;
      valid_assignment <= 0;
      for (i = 0; i < 8; i = i + 1) begin
        assignment[i] <= 0;
        temp_assignment[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SORT_BUGS;
            for (i = 0; i < 8; i = i + 1) begin
              sorted_bugs[i] <= sorted_bugs_comb[i];
            end
          end
        end

        SORT_BUGS: begin
          state <= BINARY_SEARCH;
          days_low <= 1;
          days_high <= 16;
          best_days <= 16;
          valid_assignment <= 0;
        end

        BINARY_SEARCH: begin
          if (days_low <= days_high) begin
            days_mid <= (days_low + days_high) / 2;
            group_size <= (8 + days_mid - 1) / days_mid;
            group_idx <= 0;
            bug_idx <= 0;
            total_cost <= 0;
            state <= CHECK_SCHEDULE;
          end else begin
            if (best_days == 16) begin
              min_days <= 0;
              feasible <= 0;
            end else begin
              min_days <= best_days;
              feasible <= 1;
            end
            state <= DONE;
          end
        end

        CHECK_SCHEDULE: begin
          if (group_idx < days_mid) begin
            if (bug_idx < group_size) begin
              max_bug_in_group <= (bug_idx == 0) ? sorted_bugs[group_idx * group_size + bug_idx] : 
                                 (sorted_bugs[group_idx * group_size + bug_idx] > max_bug_in_group) ? 
                                 sorted_bugs[group_idx * group_size + bug_idx] : max_bug_in_group;
              bug_idx <= bug_idx + 1;
            end else begin
              // Find cheapest qualified student
              min_cost <= 16'hFFFF;
              best_student <= 0;
              student_idx <= 0;
              state <= CHECK_SCHEDULE;
            end
          end else begin
            if (total_cost <= budget && valid_assignment) begin
              best_days <= days_mid;
              for (i = 0; i < 8; i = i + 1) begin
                assignment[i] <= temp_assignment[i];
              end
              days_high <= days_mid - 1;
            end else begin
              days_low <= days_mid + 1;
            end
            state <= BINARY_SEARCH;
          end
        end

        DONE: begin
          done <= 1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Combinational logic for student selection
  always_comb begin
    if (state == CHECK_SCHEDULE && bug_idx == group_size) begin
      if (student_idx < 8) begin
        if (student_ability[student_idx] >= max_bug_in_group && student_cost[student_idx] < min_cost) begin
          min_cost = student_cost[student_idx];
          best_student = student_idx;
        end
      end
    end
  end

  // Update assignment and cost
  always @(posedge clk) begin
    if (state == CHECK_SCHEDULE && bug_idx == group_size && student_idx == 7) begin
      if (min_cost != 16'hFFFF) begin
        for (i = 0; i < group_size; i = i + 1) begin
          temp_assignment[group_idx * group_size + i] = best_student;
        end
        total_cost = total_cost + min_cost;
        valid_assignment = 1;
      end else begin
        valid_assignment = 0;
      end
      group_idx <= group_idx + 1;
      bug_idx <= 0;
    end else if (state == CHECK_SCHEDULE && bug_idx == group_size) begin
      student_idx <= student_idx + 1;
    end
  end

endmodule