module shortest_subarray_solver (
  input clk,
  input rst_n,
  input start,
  input query_type,
  input [4:0] pos,
  input [1:0] new_value,
  output reg result_valid,
  output reg [5:0] shortest_length,
  output reg processing_done
);

  // Internal array storage (16 elements, 2 bits each)
  reg [1:0] array [0:15];
  
  // State machine states
  typedef enum logic [2:0] {
    IDLE,
    INIT_SCAN,
    OUTER_LOOP,
    INNER_LOOP,
    UPDATE_BEST,
    DONE
  } state_t;
  
  state_t current_state, next_state;
  
  // Control signals
  reg [3:0] outer_idx;  // i in outer loop
  reg [3:0] inner_idx;  // j in inner loop
  reg [3:0] best_length; // Current best length
  reg [3:0] window_start; // Start of current window
  reg [3:0] window_end;   // End of current window
  reg [3:0] value_counts [0:3]; // Counts for values 1-4 (index 0 unused)
  reg [3:0] temp_counts [0:3]; // Temporary counts during scan
  reg all_values_found;
  reg query_in_progress;
  
  // Initialize array to all 1s on reset
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1) begin
        array[i] <= 2'd1;
      end
      current_state <= IDLE;
      result_valid <= 1'b0;
      shortest_length <= 6'd63;
      processing_done <= 1'b0;
      query_in_progress <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end
  
  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled above
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            query_in_progress <= 1'b1;
            if (query_type == 1'b0) begin  // UPDATE
              next_state <= DONE;
              array[pos] <= new_value;
            end else begin  // QUERY
              next_state <= INIT_SCAN;
              // Initialize scan variables
              outer_idx <= 4'd0;
              inner_idx <= 4'd0;
              best_length <= 4'd63; // Initialize to max (63)
              result_valid <= 1'b0;
              processing_done <= 1'b0;
            end
          end else begin
            next_state <= IDLE;
          end
        end
        
        INIT_SCAN: begin
          // Initialize counts
          value_counts[1] <= 4'd0;
          value_counts[2] <= 4'd0;
          value_counts[3] <= 4'd0;
          value_counts[4] <= 4'd0;
          next_state <= OUTER_LOOP;
        end
        
        OUTER_LOOP: begin
          if (outer_idx == 4'd16) begin
            next_state <= DONE;
          end else begin
            // Reset temporary counts for new outer loop
            temp_counts[1] <= 4'd0;
            temp_counts[2] <= 4'd0;
            temp_counts[3] <= 4'd0;
            temp_counts[4] <= 4'd0;
            inner_idx <= outer_idx;
            window_start <= outer_idx;
            next_state <= INNER_LOOP;
          end
        end
        
        INNER_LOOP: begin
          if (inner_idx == 4'd16) begin
            next_state <= OUTER_LOOP;
            outer_idx <= outer_idx + 4'd1;
          end else begin
            // Update counts for current element
            reg [1:0] current_val = array[inner_idx];
            if (current_val == 2'd1) temp_counts[1] <= temp_counts[1] + 4'd1;
            else if (current_val == 2'd2) temp_counts[2] <= temp_counts[2] + 4'd1;
            else if (current_val == 2'd3) temp_counts[3] <= temp_counts[3] + 4'd1;
            else if (current_val == 2'd4) temp_counts[4] <= temp_counts[4] + 4'd1;
            
            // Check if all values are found
            all_values_found = (temp_counts[1] > 4'd0) && 
                              (temp_counts[2] > 4'd0) && 
                              (temp_counts[3] > 4'd0) && 
                              (temp_counts[4] > 4'd0);
            
            if (all_values_found) begin
              window_end <= inner_idx;
              next_state <= UPDATE_BEST;
            end else begin
              inner_idx <= inner_idx + 4'd1;
              next_state <= INNER_LOOP;
            end
          end
        end
        
        UPDATE_BEST: begin
          reg [3:0] current_length = window_end - window_start + 4'd1;
          if (current_length < best_length) begin
            best_length <= current_length;
          end
          // Continue scanning from current position
          inner_idx <= inner_idx + 4'd1;
          next_state <= INNER_LOOP;
        end
        
        DONE: begin
          if (query_type == 1'b1) begin  // QUERY
            if (best_length == 4'd63) begin
              shortest_length <= 6'd63; // Not found
            end else begin
              shortest_length <= best_length;
            end
            result_valid <= 1'b1;
          end
          processing_done <= 1'b1;
          query_in_progress <= 1'b0;
          next_state <= IDLE;
        end
        
        default: next_state <= IDLE;
      endcase
    end
  end
  
  // Default assignments for outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_valid <= 1'b0;
      shortest_length <= 6'd63;
      processing_done <= 1'b0;
    end else if (current_state == DONE && query_type == 1'b0) begin
      // UPDATE query completes in 1 cycle
      processing_done <= 1'b1;
    end else if (current_state == DONE && query_type == 1'b1) begin
      // QUERY query completes when done
      processing_done <= 1'b1;
    end else begin
      processing_done <= 1'b0;
    end
  end
  
endmodule