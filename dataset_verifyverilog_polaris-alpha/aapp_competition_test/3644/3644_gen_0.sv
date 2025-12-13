module hr_scheduler(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] fi [0:7],
  input [7:0] hi [0:7],
  output reg [3:0] min_hr_count,
  output reg [3:0] hr_assign [0:7],
  output reg done
);

  // Internal worker stack: stores HR ID (0-15) for each worker (max 256)
  reg [3:0] worker_hr_stack [0:255];
  reg [7:0] sp;                // stack pointer: number of active workers

  // Day processing
  reg [2:0] day_cnt;           // current day index (0..7)
  reg processing;              // active processing flag

  // HR usage tracking
  reg [7:0] hr_usage [0:15];   // per-HR assigned worker counts (0..255)

  // Internal signals
  integer i;
  integer j;

  // Priority encoder function to select HR ID based on usage and forbidden mask
  function automatic [3:0] pick_hr_id;
    input [15:0] forbidden_mask;      // 1: HR ID not allowed
    integer k;
    reg [7:0] best_usage;
    reg [3:0] best_id;
  begin
    best_usage = 8'hFF;
    best_id = 4'd0;
    for (k = 0; k < 16; k = k + 1) begin
      if (!forbidden_mask[k]) begin
        if (hr_usage[k] < best_usage) begin
          best_usage = hr_usage[k];
          best_id = k[3:0];
        end
      end
    end
    pick_hr_id = best_id;
  end
  endfunction

  // Compute minimal HR count from hr_usage
  function automatic [3:0] compute_min_hr_count;
    integer k;
    reg [3:0] max_id;
  begin
    max_id = 4'd0;
    for (k = 0; k < 16; k = k + 1) begin
      if (hr_usage[k] != 8'd0 && k[3:0] > max_id)
        max_id = k[3:0];
    end
    if (max_id == 4'd0 && hr_usage[0] == 8'd0)
      compute_min_hr_count = 4'd0;
    else
      compute_min_hr_count = max_id + 4'd1;
  end
  endfunction

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sp <= 8'd0;
      day_cnt <= 3'd0;
      processing <= 1'b0;
      done <= 1'b0;
      min_hr_count <= 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        hr_assign[i] <= 4'd0;
      end
      for (i = 0; i < 16; i = i + 1) begin
        hr_usage[i] <= 8'd0;
      end
    end else begin
      done <= 1'b0;

      // Start signal: initialize
      if (start && !processing) begin
        sp <= 8'd0;
        day_cnt <= 3'd0;
        processing <= 1'b1;
        min_hr_count <= 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
          hr_assign[i] <= 4'd0;
        end
        for (i = 0; i < 16; i = i + 1) begin
          hr_usage[i] <= 8'd0;
        end
      end else if (processing) begin
        // Process one day per cycle
        if (day_cnt < n) begin
          reg [15:0] forbidden_mask;
          reg [7:0] fire_cnt;
          reg [7:0] hire_cnt;
          reg [3:0] fired_hr_id;
          reg [3:0] chosen_hr;

          fire_cnt = fi[day_cnt];
          hire_cnt = hi[day_cnt];

          // 1) Pop fi workers with LIFO and build forbidden set
          forbidden_mask = 16'd0;
          for (i = 0; i < fire_cnt; i = i + 1) begin
            if (sp > 0) begin
              sp = sp - 1'b1;
              fired_hr_id = worker_hr_stack[sp];
              forbidden_mask[fired_hr_id] = 1'b1;
              if (hr_usage[fired_hr_id] > 0)
                hr_usage[fired_hr_id] = hr_usage[fired_hr_id] - 1'b1;
            end
          end

          // 2) Assign HR for hi new hires, avoiding forbidden and balancing usage
          for (i = 0; i < hire_cnt; i = i + 1) begin
            chosen_hr = pick_hr_id(forbidden_mask);
            hr_assign[day_cnt] = chosen_hr;
            worker_hr_stack[sp] = chosen_hr;
            sp = sp + 1'b1;
            hr_usage[chosen_hr] = hr_usage[chosen_hr] + 1'b1;
          end

          // Next day
          day_cnt <= day_cnt + 3'd1;
        end else begin
          // All requested days processed
          processing <= 1'b0;
          min_hr_count <= compute_min_hr_count();
          done <= 1'b1;
        end
      end
    end
  end

endmodule