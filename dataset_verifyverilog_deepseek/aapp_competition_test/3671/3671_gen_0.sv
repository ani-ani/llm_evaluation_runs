module job_scheduler(
  input clk,
  input rst_n,
  input start,
  input [2:0] job_count,
  input [31:0] job_times [0:7],
  output reg [5:0] total_cookies,
  output reg done
);

  reg [31:0] sorted_times [0:7];
  reg [5:0] max_cookies [0:7];
  reg [6:0] cycle_counter;
  reg [2:0] stored_job_count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      total_cookies <= 0;
      cycle_counter <= 7'd79;
      stored_job_count <= 0;
      for (int i=0; i<8; i++) begin
        sorted_times[i] <= 32'd0;
        max_cookies[i] <= 6'd0;
      end
    end else begin
      if (start) begin
        cycle_counter <= 0;
        done <= 0;
        stored_job_count <= job_count;
        for (int i=0; i<8; i++) begin
          sorted_times[i] <= job_times[i];
        end
      end else if (cycle_counter < 79) begin
        cycle_counter <= cycle_counter + 1;
     amb>
      if (cycle_counter == 79) done <= 1;

      // Sorting phase (cycles 0-9)
      if (cycle_counter < 10) begin
        case(cycle_counter)
          0: begin for (int i=0; i<4; i++) if (i*2+1 < stored_job_count && sorted_times[i*2] > sorted_times[i*2+1]) {sorted_times[i*2], sorted_times[i*2+1]} = {sorted_times[i*2+1], sorted_times[i*2]}; end
          1: begin for (int i=0; i<4; i++) if (i*2+1 < stored_job_count && sorted_times[i*2] > sorted_times[i*2+1]) {sorted_times[i*2], sorted_times[i*2+1]} = {sorted_times[i*2+1], sorted_times[i*2]}; end
          2: begin for (int i=0; i<4; i++) if (i*2+2 < stored_job_count && sorted_times[i*2] > sorted_times[i*2+2]) {sorted_times[i*2], sorted_times[i*2+2]} = {sorted_times[i*2+2], sorted_times[i*2]}; end
          3: begin for (int i=0; i<4; i++) if (i*2+3 < stored_job_count && sorted_times[i*2+1] > sorted_times[i*2+3]) {sorted_times[i*2+1], sorted_times[i*2+3]} = {sorted_times[i*2+3], sorted_times[i*2+1]}; end
          4: begin for (int i=0; i<4; i++) if (i*2+1 < stored_job_count && sorted_times[i*2] > sorted_times[i*2+1]) {sorted_times[i*2], sorted_times[i*2+1]} = {sorted_times[i*2+1], sorted_times[i*2]}; end
          5: begin for (int i=0; i<4; i++) if (i*2+2 < stored_job_count && sorted_times[i*2] > sorted_times[i*2+2]) {sorted_times[i*2], sorted_times[i*2+2]} = {sorted_times[i*2+2], sorted_times[i*2]}; end
          6: begin for (int i=0; i<4; i++) if (i*2+3 < stored_job_count && sorted_times[i*2+1] > sorted_times[i*2+3]) {sorted_times[i*2+1], sorted_times[i*2+3]} = {sorted_times[i*2+3], sorted_times[i*2+1]}; end
          7: begin for (int i=0; i<4; i++) if (i*2+1 < stored_job_count && sorted_times[i*2] > sorted_times[i*2+1]) {sorted_times[i*2], sorted_times[i*2+1]} = {sorted_times[i*2+1], sorted_times[i*2]}; end
          8: begin for (int i=0; i<4; i++) if (i*2+1 < stored_job_count && sorted_times[i*2] > sorted_times[i*2+1]) {sorted_times[i*2], sorted_times[i*2+1]} = {sorted_times[i*2+1], sorted_times[i*2]}; end
          9: begin for (int i=0; i<4; i++) if (i*2+1 < stored_job_count && sorted_times[i*2] > sorted_times[i*2+1]) {sorted_times[i*2], sorted_times[i*2+1]} = {sorted_times[i*2+1], sorted_times[i*2]}; end
        endcase
      end

      // Scheduling phase (cycles 10-73)
      if (cycle_counter >= 10 && cycle_counter < 74) begin
        automatic int current_job = (cycle_counter - 10) / 8;
        automatic int sub_cycle = (cycle_counter - 10) % 8;
        if (sub_cycle == 0 && current_job < stored_job_count) begin
          automatic logic [7:0] cond_vector;
          automatic int found_j;
          automatic logic found;
          automatic logic [5:0] prev_max = (current_job > 0) ? max_cookies[current_job-1] : 0;
          automatic logic [5:0] candidate;

          for (int j=0; j<current_job; j++) begin
            cond_vector[j] = (sorted_times[j] <= (sorted_times[current_job] - 32'd400000));
          end
          found = 1'b0;
          found_j = -1;
          for (int j=7; j>=0; j--) begin
            if (cond_vector[j] && j < current_job) begin
              found_j = j;
              found = 1'b1;
              break;
            end
          end
          candidate = (found) ? 6'd4 + max_cookies[found_j] : 6'd4;
          max_cookies[current_job] <= (candidate > prev_max) ? candidate : prev_max;
        end
      end

      // Final result assignment
      if (cycle_counter == 73 && stored_job_count > 0) begin
        total_cookies <= max_cookies[stored_job_count-1];
      end
    end
  end

endmodule