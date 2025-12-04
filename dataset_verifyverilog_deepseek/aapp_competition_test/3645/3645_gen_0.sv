module number_guesser(
  input clk, 
  input rst_n, 
  input start, 
  input [3:0] n, 
  input [7:0] array [0:7], 
  output reg [7:0] valid_numbers [0:7], 
  output reg [3:0] count, 
  output reg done
);
  
  typedef enum logic [2:0] {
    IDLE, 
    COUNT_SAMPLES, 
    CHECK_CONDITION, 
    SORT_OUTPUT, 
    DONE
  } state_t;
  
  state_t state, next_state;
  
  reg [3:0] input_index;
  reg [3:0] unique_count;
  reg [7:0] unique_array [0:7];
  reg [3:0] freq_counts [0:7];
  reg [7:0] valid_temp [0:7];
  reg [3:0] count_temp;
  reg sort_done;
  reg [3:0] sort_i;
  reg [3:0] sort_j;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      count <= 4'b0;
      for (int i = 0; i < 8; i++) valid_numbers[i] <= 8'b0;
      unique_count <= 4'b0;
      input_index <= 4'b0;
      sort_i <= 4'b0;
      sort_j <= 4'b0;
      sort_done <= 1'b0;
      for (int i = 0; i < 8; i++) begin
        unique_array[i] <= 8'b0;
        freq_counts[i] <= 4'b0;
        valid_temp[i] <= 8'b0;
      end
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            unique_count <= 4'b0;
            input_index <= 4'b0;
            for (int i = 0; i < 8; i++) begin
              unique_array[i] <= 8'b0;
              freq_counts[i] <= 4'b0;
            end
          end
        end
        
        COUNT_SAMPLES: begin
          if (input_index < n) begin
            automatic bit found = 1'b0;
            for (int j = 1; j <= unique_count; j++) begin
              if (unique_array[j-1] == array[input_index]) begin
                freq_counts[j-1] <= freq_counts[j-1] + 1;
                found = 1'b1;
              end
            end
            if (!found) begin
              if (unique_count < 8) begin
                unique_array[unique_count] <= array[input_index];
                freq_counts[unique_count] <= 4'd1;
                unique_count <= unique_count + 1;
              end
            end
            input_index <= input_index + 1;
          end
        end
        
        CHECK_CONDITION: begin
          count_temp <= 4'b0;
          for (int i = 0; i < 8; i++) begin
            if (i < unique_count && freq_counts[i] == 1) begin
              valid_temp[count_temp] <= unique_array[i];
              count_temp <= count_temp + 1;
            end
          end
        end
        
        SORT_OUTPUT: begin
          if (!sort_done) begin
            if (sort_i < count_temp) begin
              if (sort_j < count_temp - sort_i - 1) begin
                if (valid_temp[sort_j] > valid_temp[sort_j + 1]) begin
                  automatic reg [7:0] temp = valid_temp[sort_j];
                  valid_temp[sort_j] <= valid_temp[sort_j + 1];
                  valid_temp[sort_j + 1] <= temp;
                end
                sort_j <= sort_j + 1;
              end else begin
                sort_i <= sort_i + 1;
                sort_j <= 0;
              end
            end else begin
              sort_done <= 1'b1;
            end
          end
        end
        
        DONE: begin
          for (int i = 0; i < count_temp; i++)
            valid_numbers[i] <= valid_temp[i];
          count <= count_temp;
          done <= 1'b1;
          sort_done <= 1'b0;
          sort_i <= 0;
          sort_j <= 0;
        end
      endcase
    end
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = start ? COUNT_SAMPLES : IDLE;
      COUNT_SAMPLES: next_state = (input_index == n) ? CHECK_CONDITION : COUNT_SAMPLES;
      CHECK_CONDITION: next_state = SORT_OUTPUT;
      SORT_OUTPUT: next_state = sort_done ? DONE : SORT_OUTPUT;
      DONE: next_state = (start) ? IDLE : DONE;
      default: next_state = IDLE;
    endcase
  end
endmodule