module job_scheduler (
  input clk,
  input rst_n,
  input start,
  input [2:0] job_count,
  input reg [31:0] job_times [7:0],
  output reg [5:0] total_cookies,
  output reg done
);

// Internal signals and state
reg [2:0] state, next_state;
reg [2:0] n_jobs_r;
reg [31:0] t_r [8][8]; // time register array: stage x job
reg [7:0] idx_r [8];   // index register array to track original positions (optional, unused for DP)
reg [5:0] max_r [7:0]; // DP registers: max cookies up to each job
reg [5:0] best_cookies; // local max during scheduling
wire [5:0] COOKIES_PER_JOB = 4; // all jobs considered humongous

// Parameters
localparam S_IDLE   = 3'b000;
localparam S_SORT   = 3'b001; // 8 cycles (10 declared, but uses 8, margin absorbed later)
localparam S_SCHED0 = 3'b010; // setup scheduling
localparam S_SCHED  = 3'b011; // 8 cycles scheduling (64 cycles total declared; 8 jobs * 8 cycles)
localparam S_DONE   = 3'b100;

// Combinational next state logic
always_comb begin
  next_state = state;
  case (state)
    S_IDLE:   next_state = start ? S_SORT : S_IDLE;
    S_SORT:   next_state = S_SCHED0;
    S_SCHED0: next_state = S_SCHED;
    S_SCHED:  next_state = S_DONE;
    S_DONE:   next_state = start ? S_SORT : S_DONE; // stay done until next start pulse
    default:  next_state = S_IDLE;
  endcase
end

// Sequential state update and control
integer k;
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= S_IDLE;
    n_jobs_r <= 3'b0;
    for (k = 0; k < 8; k = k + 1) begin
      t_r[0][k] <= 32'h0;
      idx_r[0][k] <= k[7:0];
    end
    for (k = 0; k < 8; k = k + 1) begin
      max_r[k] <= 6'b0;
    end
    best_cookies <= 6'b0;
    total_cookies <= 6'b0;
    done <= 1'b0;
  end else begin
    state <= next_state;

    // Latch inputs at the start of a run
    if (state == S_IDLE && start) begin
      n_jobs_r <= job_count;
      for (k = 0; k < 8; k = k + 1) begin
        t_r[0][k] <= job_times[k]; // assumption: inputs are 'reg' (as per constraints)
        idx_r[0][k] <= k[7:0];
      end
      for (k = 0; k < 8; k = k + 1) begin
        max_r[k] <= 6'b0; // max_cookies[0..7]
      end
      best_cookies <= 6'b0;
      total_cookies <= 6'b0;
      done <= 1'b0;
    end

    // Sorting stage: 8-cycle odd-even transposition network on first n_jobs_r elements
    if (state == S_SORT) begin
      // Stage 1 (even-odd swaps)
      for (k = 0; k < 7; k = k + 2) begin
        t_r[1][k]   <= (n_jobs_r > k+1) ? ((t_r[0][k] <= t_r[0][k+1]) ? t_r[0][k]   : t_r[0][k+1]) : t_r[0][k];
        t_r[1][k+1] <= (n_jobs_r > k+1) ? ((t_r[0][k] <= t_r[0][k+1]) ? t_r[0][k+1] : t_r[0][k])   : t_r[0][k+1];
      end
      for (k = ((7/2)*2); k < 8; k = k + 1) begin
        t_r[1][k] <= t_r[0][k];
      end
      // Stage 2 (odd-even swaps)
      for (k = 1; k < 7; k = k + 2) begin
        t_r[2][k]   <= (n_jobs_r > k+1) ? ((t_r[1][k] <= t_r[1][k+1]) ? t_r[1][k]   : t_r[1][k+1]) : t_r[1][k];
        t_r[2][k+1] <= (n_jobs_r > k+1) ? ((t_r[1][k] <= t_r[1][k+1]) ? t_r[1][k+1] : t_r[1][k])   : t_r[1][k+1];
      end
      for (k = 0; k < 1; k = k + 1) begin
        t_r[2][k] <= t_r[1][k];
      end
      // Stage 3 (even-odd swaps)
      for (k = 0; k < 7; k = k + 2) begin
        t_r[3][k]   <= (n_jobs_r > k+1) ? ((t_r[2][k] <= t_r[2][k+1]) ? t_r[2][k]   : t_r[2][k+1]) : t_r[2][k];
        t_r[3][k+1] <= (n_jobs_r > k+1) ? ((t_r[2][k] <= t_r[2][k+1]) ? t_r[2][k+1] : t_r[2][k])   : t_r[2][k+1];
      end
      for (k = ((7/2)*2); k < 8; k = k + 1) begin
        t_r[3][k] <= t_r[2][k];
      end
      // Stage 4 (odd-even swaps)
      for (k = 1; k < 7; k = k + 2) begin
        t_r[4][k]   <= (n_jobs_r > k+1) ? ((t_r[3][k] <= t_r[3][k+1]) ? t_r[3][k]   : t_r[3][k+1]) : t_r[3][k];
        t_r[4][k+1] <= (n_jobs_r > k+1) ? ((t_r[3][k] <= t_r[3][k+1]) ? t_r[3][k+1] : t_r[3][k])   : t_r[3][k+1];
      end
      for (k = 0; k < 1; k = k + 1) begin
        t_r[4][k] <= t_r[3][k];
      end
      // Stage 5 (even-odd swaps)
      for (k = 0; k < 7; k = k + 2) begin
        t_r[5][k]   <= (n_jobs_r > k+1) ? ((t_r[4][k] <= t_r[4][k+1]) ? t_r[4][k]   : t_r[4][k+1]) : t_r[4][k];
        t_r[5][k+1] <= (n_jobs_r > k+1) ? ((t_r[4][k] <= t_r[4][k+1]) ? t_r[4][k+1] : t_r[4][k])   : t_r[4][k+1];
      end
      for (k = ((7/2)*2); k < 8; k = k + 1) begin
        t_r[5][k] <= t_r[4][k];
      end
      // Stage 6 (odd-even swaps)
      for (k = 1; k < 7; k = k + 2) begin
        t_r[6][k]   <= (n_jobs_r > k+1) ? ((t_r[5][k] <= t_r[5][k+1]) ? t_r[5][k]   : t_r[5][k+1]) : t_r[5][k];
        t_r[6][k+1] <= (n_jobs_r > k+1) ? ((t_r[5][k] <= t_r[5][k+1]) ? t_r[5][k+1] : t_r[5][k])   : t_r[5][k+1];
      end
      for (k = 0; k < 1; k = k + 1) begin
        t_r[6][k] <= t_r[5][k];
      end
      // Stage 7 (even-odd swaps)
      for (k = 0; k < 7; k = k + 2) begin
        t_r[7][k]   <= (n_jobs_r > k+1) ? ((t_r[6][k] <= t_r[6][k+1]) ? t_r[6][k]   : t_r[6][k+1]) : t_r[6][k];
        t_r[7][k+1] <= (n_jobs_r > k+1) ? ((t_r[6][k] <= t_r[6][k+1]) ? t_r[6][k+1] : t_r[6][k])   : t_r[6][k+1];
      end
      for (k = ((7/2)*2); k < 8; k = k + 1) begin
        t_r[7][k] <= t_r[6][k];
      end
    end else begin
      // When not sorting, keep the last stage times stable
      for (k = 0; k < 8; k = k + 1) begin
        t_r[7][k] <= t_r[7][k];
      end
    end

    // Scheduling setup
    if (state == S_SCHED0) begin
      // Initialize DP: max_cookies[0] = 0; base for i=0
      max_r[0] <= 6'b0;
      for (k = 1; k < 8; k = k + 1) begin
        max_r[k] <= 6'b0; // will be computed in the next 8 cycles
      end
      best_cookies <= 6'b0;
    end

    // Scheduling (8 cycles to handle up to 8 jobs)
    if (state == S_SCHED) begin
      // Cycle 0: i = 0 (base case)
      max_r[0] <= 6'b0;
      // Cycle 1: i = 1 (find j where t[i] >= t[j] + 400000)
      if (n_jobs_r > 1) begin
        // j index search (parallel comparators across j=0)
        if (t_r[7][1] >= t_r[7][0] + 32'd400000) begin
          max_r[1] <= (COOKIES_PER_JOB + max_r[0]);
        end else begin
          max_r[1] <= (max_r[0] > COOKIES_PER_JOB) ? max_r[0] : COOKIES_PER_JOB;
        end
      end else begin
        max_r[1] <= 6'b0;
      end
      // Cycle 2: i = 2
      if (n_jobs_r > 2) begin
        // j index search across j=0,1
        // j=1
        if (t_r[7][2] >= t_r[7][1] + 32'd400000) begin
          // temp candidate using j=1
          max_r[2] <= COOKIES_PER_JOB + max_r[1];
        end else if (t_r[7][2] >= t_r[7][0] + 32'd400000) begin
          // temp candidate using j=0
          max_r[2] <= COOKIES_PER_JOB + max_r[0];
        end else begin
          // no compatible j
          max_r[2] <= (max_r[1] > COOKIES_PER_JOB) ? max_r[1] : COOKIES_PER_JOB;
        end
      end else begin
        max_r[2] <= 6'b0;
      end
      // Cycle 3: i = 3
      if (n_jobs_r > 3) begin
        // parallel checks across j=0..2
        if (t_r[7][3] >= t_r[7][2] + 32'd400000) begin
          max_r[3] <= COOKIES_PER_JOB + max_r[2];
        end else if (t_r[7][3] >= t_r[7][1] + 32'd400000) begin
          max_r[3] <= COOKIES_PER_JOB + max_r[1];
        end else if (t_r[7][3] >= t_r[7][0] + 32'd400000) begin
          max_r[3] <= COOKIES_PER_JOB + max_r[0];
        end else begin
          max_r[3] <= (max_r[2] > COOKIES_PER_JOB) ? max_r[2] : COOKIES_PER_JOB;
        end
      end else begin
        max_r[3] <= 6'b0;
      end
      // Cycle 4: i = 4
      if (n_jobs_r > 4) begin
        if (t_r[7][4] >= t_r[7][3] + 32'd400000) begin
          max_r[4] <= COOKIES_PER_JOB + max_r[3];
        end else if (t_r[7][4] >= t_r[7][2] + 32'd400000) begin
          max_r[4] <= COOKIES_PER_JOB + max_r[2];
        end else if (t_r[7][4] >= t_r[7][1] + 32'd400000) begin
          max_r[4] <= COOKIES_PER_JOB + max_r[1];
        end else if (t_r[7][4] >= t_r[7][0] + 32'd400000) begin
          max_r[4] <= COOKIES_PER_JOB + max_r[0];
        end else begin
          max_r[4] <= (max_r[3] > COOKIES_PER_JOB) ? max_r[3] : COOKIES_PER_JOB;
        end
      end else begin
        max_r[4] <= 6'b0;
      end
      // Cycle 5: i = 5
      if (n_jobs_r > 5) begin
        if (t_r[7][5] >= t_r[7][4] + 32'd400000) begin
          max_r[5] <= COOKIES_PER_JOB + max_r[4];
        end else if (t_r[7][5] >= t_r[7][3] + 32'd400000) begin
          max_r[5] <= COOKIES_PER_JOB + max_r[3];
        end else if (t_r[7][5] >= t_r[7][2] + 32'd400000) begin
          max_r[5] <= COOKIES_PER_JOB + max_r[2];
        end else if (t_r[7][5] >= t_r[7][1] + 32'd400000) begin
          max_r[5] <= COOKIES_PER_JOB + max_r[1];
        end else if (t_r[7][5] >= t_r[7][0] + 32'd400000) begin
          max_r[5] <= COOKIES_PER_JOB + max_r[0];
        end else begin
          max_r[5] <= (max_r[4] > COOKIES_PER_JOB) ? max_r[4] : COOKIES_PER_JOB;
        end
      end else begin
        max_r[5] <= 6'b0;
      end
      // Cycle 6: i = 6
      if (n_jobs_r > 6) begin
        if (t_r[7][6] >= t_r[7][5] + 32'd400000) begin
          max_r[6] <= COOKIES_PER_JOB + max_r[5];
        end else if (t_r[7][6] >= t_r[7][4] + 32'd400000) begin
          max_r[6] <= COOKIES_PER_JOB + max_r[4];
        end else if (t_r[7][6] >= t_r[7][3] + 32'd400000) begin
          max_r[6] <= COOKIES_PER_JOB + max_r[3];
        end else if (t_r[7][6] >= t_r[7][2] + 32'd400000) begin
          max_r[6] <= COOKIES_PER_JOB + max_r[2];
        end else if (t_r[7][6] >= t_r[7][1] + 32'd400000) begin
          max_r[6] <= COOKIES_PER_JOB + max_r[1];
        end else if (t_r[7][6] >= t_r[7][0] + 32'd400000) begin
          max_r[6] <= COOKIES_PER_JOB + max_r[0];
        end else begin
          max_r[6] <= (max_r[5] > COOKIES_PER_JOB) ? max_r[5] : COOKIES_PER_JOB;
        end
      end else begin
        max_r[6] <= 6'b0;
      end
      // Cycle 7: i = 7 (last job)
      if (n_jobs_r > 7) begin
        if (t_r[7][7] >= t_r[7][6] + 32'd400000) begin
          max_r[7] <= COOKIES_PER_JOB + max_r[6];
        end else if (t_r[7][7] >= t_r[7][5] + 32'd400000) begin
          max_r[7] <= COOKIES_PER_JOB + max_r[5];
        end else if (t_r[7][7] >= t_r[7][4] + 32'd400000) begin
          max_r[7] <= COOKIES_PER_JOB + max_r[4];
        end else if (t_r[7][7] >= t_r[7][3] + 32'd400000) begin
          max_r[7] <= COOKIES_PER_JOB + max_r[3];
        end else if (t_r[7][7] >= t_r[7][2] + 32'd400000) begin
          max_r[7] <= COOKIES_PER_JOB + max_r[2];
        end else if (t_r[7][7] >= t_r[7][1] + 32'd400000) begin
          max_r[7] <= COOKIES_PER_JOB + max_r[1];
        end else if (t_r[7][7] >= t_r[7][0] + 32'd400000) begin
          max_r[7] <= COOKIES_PER_JOB + max_r[0];
        end else begin
          max_r[7] <= (max_r[6] > COOKIES_PER_JOB) ? max_r[6] : COOKIES_PER_JOB;
        end
      end else begin
        max_r[7] <= 6'b0;
      end
    end

    // Final aggregation and output
    if (state == S_DONE) begin
      // Compute the overall max across up to job_count-1
      best_cookies <= 6'b0;
      case (n_jobs_r)
        3'b001: best_cookies <= max_r[0];
        3'b010: best_cookies <= (max_r[1] > max_r[0]) ? max_r[1] : max_r[0];
        3'b011: best_cookies <= max_r[2] > max_r[1] ? (max_r[2] > max_r[0] ? max_r[2] : max_r[0]) : (max_r[1] > max_r[0] ? max_r[1] : max_r[0]);
        3'b100: begin
          best_cookies <= max_r[3];
          best_cookies <= (max_r[2] > best_cookies) ? max_r[2] : best_cookies;
          best_cookies <= (max_r[1] > best_cookies) ? max_r[1] : best_cookies;
          best_cookies <= (max_r[0] > best_cookies) ? max_r[0] : best_cookies;
        end
        3'b101: begin
          best_cookies <= max_r[4];
          best_cookies <= (max_r[3] > best_cookies) ? max_r[3] : best_cookies;
          best_cookies <= (max_r[2] > best_cookies) ? max_r[2] : best_cookies;
          best_cookies <= (max_r[1] > best_cookies) ? max_r[1] : best_cookies;
          best_cookies <= (max_r[0] > best_cookies) ? max_r[0] : best_cookies;
        end
        3'b110: begin
          best_cookies <= max_r[5];
          best_cookies <= (max_r[4] > best_cookies) ? max_r[4] : best_cookies;
          best_cookies <= (max_r[3] > best_cookies) ? max_r[3] : best_cookies;
          best_cookies <= (max_r[2] > best_cookies) ? max_r[2] : best_cookies;
          best_cookies <= (max_r[1] > best_cookies) ? max_r[1] : best_cookies;
          best_cookies <= (max_r[0] > best_cookies) ? max_r[0] : best_cookies;
        end
        3'b111: begin
          best_cookies <= max_r[6];
          best_cookies <= (max_r[7] > best_cookies) ? max_r[7] : best_cookies;
          best_cookies <= (max_r[5] > best_cookies) ? max_r[5] : best_cookies;
          best_cookies <= (max_r[4] > best_cookies) ? max_r[4] : best_cookies;
          best_cookies <= (max_r[3] > best_cookies) ? max_r[3] : best_cookies;
          best_cookies <= (max_r[2] > best_cookies) ? max_r[2] : best_cookies;
          best_cookies <= (max_r[1] > best_cookies) ? max_r[1] : best_cookies;
          best_cookies <= (max_r[0] > best_cookies) ? max_r[0] : best_cookies;
        end
        default: best_cookies <= 6'b0;
      endcase
      total_cookies <= best_cookies;
      done <= 1'b1;
    end else if (state != S_DONE) begin
      done <= 1'b0;
    end
  end
end
endmodule