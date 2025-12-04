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

typedef enum {IDLE, PROCESSING, CALCULATING, DONE} fsm_state_t;
fsm_state_t current_state;

reg [2:0] sorted_idx [0:7];
reg [2:0] presc_counter;
reg [1:0] tech_counter[0:3];
reg [15:0] start_time [0:7];
reg [7:0] processed;
reg [2:0] sort_idx;
reg [2:0] sort_step;
reg [31:0] total_s_time;
reg [31:0] total_r_time;
reg [3:0] count_s;
reg [3:0] count_r;
reg [31:0] timer;
reg [7:0] presc_valid;
reg [15:0] presc_drop_time_sorted [0:7];
reg [7:0] presc_type_sorted [0:7];
reg [8:0] presc_fill_time_sorted [0:7];

wire [3:0] num_techs_plus_one = num_techs + 1;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    done <= 0;
    avg_s <= 0;
    avg_r <= 0;
    timer <= 0;
    processed <= 0;
    presc_counter <= 0;
    sort_idx <= 0;
    sort_step <= 0;
    total_s_time <= 0;
    total_r_time <= 0;
    count_s <= 0;
    count_r <= 0;
    for (integer i=0; i<8; i=i+1) begin
      sorted_idx[i] <= i;
      presc_valid[i] <= 0;
      start_time[i] <= 0;
    end
    for (integer j=0; j<4; j=j+1) begin
      tech_counter[j] <= 0;
    end
  end else begin
    case (current_state)
      IDLE: begin
        done <= 0;
        if (start) begin
          current_state <= PROCESSING;
          timer <= 0;
          presc_counter <= 0;
          processed <= 0;
          sort_idx <= 0;
          sort_step <= 0;
          total_s_time <= 0;
          total_r_time <= 0;
          count_s <= 0;
          count_r <= 0;
          
          // Load input data
          for (integer i=0; i<8; i=i+1) begin
            sorted_idx[i] <= i;
            presc_drop_time_sorted[i] <= presc_drop_time[i];
            presc_type_sorted[i] <= presc_type[i];
            presc_fill_time_sorted[i] <= presc_fill_time[i];
            presc_valid[i] <= (i <= num_prescriptions) ? 1 : 0;
          end
          
          for (integer j=0; j<4; j=j+1) begin
            tech_counter[j] <= (j < num_techs) ? 0 : 4;
          end
        end
      end
      
      PROCESSING: begin
        timer <= timer + 1;
        
        // Sort prescriptions
        if (sort_step < num_prescriptions) begin
          if (sort_idx < num_prescriptions - sort_step - 1) begin
            if (presc_drop_time_sorted[sorted_idx[sort_idx]] > presc_drop_time_sorted[sorted_idx[sort_idx+1]] ||
                (presc_drop_time_sorted[sorted_idx[sort_idx]] == presc_drop_time_sorted[sorted_idx[sort_idx+1]] && presc_type_sorted[sorted_idx[sort_idx]] < presc_type_sorted[sorted_idx[sort_idx+1]]) ||
                (presc_drop_time_sorted[sorted_idx[sort_idx]] == presc_drop_time_sorted[sorted_idx[sort_idx+1]] && presc_type_sorted[sorted_idx[sort_idx]] == presc_type_sorted[sorted_idx[sort_idx+1]] && presc_fill_time_sorted[sorted_idx[sort_idx]] > presc_fill_time_sorted[sorted_idx[sort_idx+1]])) begin
              
              sorted_idx[sort_idx] <= sorted_idx[sort_idx+1];
              sorted_idx[sort_idx+1] <= sorted_idx[sort_idx];
            end
            sort_idx <= sort_idx + 1;
          end else begin
            sort_idx <= 0;
            sort_step <= sort_step + 1;
          end
        end else begin
          // Assign prescriptions to free technicians
          for (integer i=0; i<num_techs_plus_one; i=i+1) begin
            if (tech_counter[i] == 0 && presc_counter <= num_prescriptions && presc_valid[presc_counter]) begin
              tech_counter[i] <= presc_fill_time_sorted[sorted_idx[presc_counter]];
              start_time[sorted_idx[presc_counter]] <= timer;
              presc_counter <= presc_counter + 1;
            end
          end
          
          // Process technician timers
          for (integer j=0; j<num_techs_plus_one; j=j+1) begin
            if (tech_counter[j] > 0) begin
              tech_counter[j] <= tech_counter[j] - 1;
              if (tech_counter[j] == 1) begin
                processed <= processed + 1;
                
                if (presc_type_sorted[sorted_idx[presc_counter-1]] == 1) begin // 'S'
                  total_s_time <= total_s_time + ((start_time[sorted_idx[presc_counter-1]] + presc_fill_time_sorted[sorted_idx[presc_counter-1]]) - presc_drop_time_sorted[sorted_idx[presc_counter-1]]);
                  count_s <= count_s + 1;
                end else begin // 'R'
                  total_r_time <= total_r_time + ((start_time[sorted_idx[presc_counter-1]] + presc_fill_time_sorted[sorted_idx[presc_counter-1]]) - presc_drop_time_sorted[sorted_idx[presc_counter-1]]);
                  count_r <= count_r + 1;
                end
              end
            end
          end
          
          if (processed == num_prescriptions + 1) begin
            current_state <= CALCULATING;
          end
        end
      end
      
      CALCULATING: begin
        // Calculate averages in Q16.16 format
        if (count_s != 0) begin
          avg_s <= (total_s_time << 16) / count_s;
        end else begin
          avg_s <= 0;
        end
        
        if (count_r != 0) begin
          avg_r <= (total_r_time << 16) / count_r;
        end else begin
          avg_r <= 0;
        end
        
        current_state <= DONE;
      end
      
      DONE: begin
        done <= 1;
        if (start) begin
          current_state <= IDLE;
        end
      end
    endcase
  end
end

endmodule