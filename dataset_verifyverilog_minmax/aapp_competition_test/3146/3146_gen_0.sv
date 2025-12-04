module prescription_scheduler(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_prescriptions,
  input [1:0] num_techs,
  input [15:0] presc_drop_time [0:7],
  input [7:0] presc_type [0:7],
  input [8:0] presc_fill_time [0:7],
  output reg [31:0] avg_s,
  output reg [31:0] avg_r,
  output reg done
);

  // Parameters
  localparam MAX_N = 8;

  // State machine states
  typedef enum logic [1:0] {IDLE, PROCESSING, CALCULATING, DONE} state_t;
  state_t state;

  // Internal registers for input capture
  logic [15:0] drop_r [0:7];
  logic [7:0]  type_r [0:7];
  logic [8:0]  fill_r [0:7];

  // Sorted order and start times
  logic [2:0] order [0:7];
  logic [31:0] start_r [0:7]; // start time as 32-bit to avoid overflow

  // Local array for technician availability during scheduling
  logic [31:0] next_free_loc [0:3];

  // Loop indices
  int i, j, t;
  logic [31:0] min_time; // changed to 32-bit
  int min_t;
  int techs;
  int idx;

  // Aggregation
  logic [31:0] sum_s, sum_r;
  logic [31:0] count_s, count_r;

  // Start pulse detection
  logic start_prev;

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      for (i = 0; i < 8; i++) begin
        drop_r[i] <= 16'b0;
        type_r[i]  <= 8'b0;
        fill_r[i]  <= 9'b0;
        start_r[i] <= 32'b0; // start time as 32-bit
        order[i]   <= i;
      end
      sum_s <= 32'b0;
      sum_r <= 32'b0;
      count_s <= 32'b0;
      count_r <= 32'b0;
      start_prev <= 1'b0;
    end else begin
      start_prev <= start;

      case (state)
        IDLE: begin
          if (start && !start_prev) begin // start pulse
            if (num_prescriptions == 3'd0) begin
              // No prescriptions
              avg_s <= 32'b0;
              avg_r <= 32'b0;
              done  <= 1'b1;
              state <= DONE;
            end else begin
              // Capture input data
              for (i = 0; i < 8; i++) begin
                if (i < num_prescriptions) begin
                  drop_r[i] <= presc_drop_time[i];
                  type_r[i]  <= presc_type[i];
                  fill_r[i]  <= presc_fill_time[i];
                end else begin
                  drop_r[i] <= 16'b0;
                  type_r[i]  <= 8'b0;
                  fill_r[i]  <= 9'b0;
                end
                order[i] <= i;
                start_r[i] <= 32'b0; // start time as 32-bit
              end

              // Sort the prescriptions according to priority
              // Bubble sort up to num_prescriptions entries
              for (i = 0; i < 7; i++) begin
                for (j = 0; j < 7 - i; j++) begin
                  if (j < num_prescriptions - 1) begin
                    int idx1 = order[j];
                    int idx2 = order[j+1];
                    if ( (type_r[idx1] < type_r[idx2]) ||
                         (type_r[idx1] == type_r[idx2] && drop_r[idx1] > drop_r[idx2]) ||
                         (type_r[idx1] == type_r[idx2] && drop_r[idx1] == drop_r[idx2] && fill_r[idx1] > fill_r[idx2]) ) begin
                      int tmp = order[j];
                      order[j] = order[j+1];
                      order[j+1] = tmp;
                    end
                  end
                end
              end

              // Initialize technician availability
              for (t = 0; t < 4; t++) next_free_loc[t] <= 32'b0;

              // Schedule prescriptions on technicians
              techs = (num_techs == 2'b00) ? 1 : num_techs;
              for (i = 0; i < num_prescriptions; i++) begin
                idx = order[i];
                // Find the technician with the earliest availability
                min_time = next_free_loc[0];
                min_t = 0;
                for (t = 1; t < techs; t++) begin
                  if (next_free_loc[t] < min_time) begin
                    min_time = next_free_loc[t];
                    min_t = t;
                  end
                end
                // Start time is the later of drop time and earliest availability
                start_r[idx] <= (32'(drop_r[idx]) > min_time) ? 32'(drop_r[idx]) : min_time;
                // Update that technician's next free time (blocking assignment for same-cycle visibility)
                next_free_loc[min_t] = start_r[idx] + fill_r[idx];
              end

              state <= CALCULATING;
              done <= 1'b0;
            end
          end else begin
            // No start pulse
            done <= 1'b0;
          end
        end

        CALCULATING: begin
          // Compute sums and counts using local variables
          logic [31:0] sum_s_loc, sum_r_loc;
          logic [31:0] count_s_loc, count_r_loc;
          logic [31:0] completion;
          sum_s_loc = 0;
          sum_r_loc = 0;
          count_s_loc = 0;
          count_r_loc = 0;
          for (i = 0; i < num_prescriptions; i++) begin
            completion = (start_r[i] + 32'(fill_r[i])) - 32'(drop_r[i]);
            if (type_r[i] == 8'd1) begin // S type
              sum_s_loc += completion;
              count_s_loc++;
            end else begin // R type
              sum_r_loc += completion;
              count_r_loc++;
            end
          end
          // Compute averages in Q16.16 format
          if (count_s_loc > 0) begin
            logic [63:0] tmp;
            tmp = {32'b0, sum_s_loc} << 16;
            avg_s <= tmp / count_s_loc;
          end else begin
            avg_s <= 32'b0;
          end
          if (count_r_loc > 0) begin
            logic [63:0] tmp;
            tmp = {32'b0, sum_r_loc} << 16;
            avg_r <= tmp / count_r_loc;
          end else begin
            avg_r <= 32'b0;
          end
          done <= 1'b1;
          state <= DONE;
        end

        DONE: begin
          // Hold done high and wait for next start pulse
          done <= 1'b1;
          if (start && !start_prev) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule