module gold_store_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] t_i_0, h_i_0,
  input [15:0] t_i_1, h_i_1,
  input [15:0] t_i_2, h_i_2,
  input [15:0] t_i_3, h_i_3,
  input [15:0] t_i_4, h_i_4,
  input [15:0] t_i_5, h_i_5,
  input [15:0] t_i_6, h_i_6,
  input [15:0] t_i_7, h_i_7,
  output reg [3:0] max_count,
  output reg done
);
  
  typedef enum logic [1:0] { 
    IDLE       = 2'b00,
    SORT       = 2'b01,
    ACCUMULATE = 2'b10,
    DONE       = 2'b11
  } state_t;
  
  reg [1:0] current_state, next_state;
  reg [15:0] sorted_h [0:7];
  reg [15:0] sorted_t [0:7];
  reg [15:0] accumulated_time;
  reg [3:0] count, sort_pass, sort_index, acc_index;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      max_count <= 4'b0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Load inputs into sorted arrays
            sorted_h[0] <= h_i_0; sorted_t[0] <= t_i_0;
            sorted_h[1] <= h_i_1; sorted_t[1] <= t_i_1;
            sorted_h[2] <= h_i_2; sorted_t[2] <= t_i_2;
            sorted_h[3] <= h_i_3; sorted_t[3] <= t_i_3;
            sorted_h[4] <= h_i_4; sorted_t[4] <= t_i_4;
            sorted_h[5] <= h_i_5; sorted_t[5] <= t_i_5;
            sorted_h[6] <= h_i_6; sorted_t[6] <= t_i_6;
            sorted_h[7] <= h_i_7; sorted_t[7] <= t_i_7;
          end
        end
        
        SORT: begin
          if (sort_pass < (n-1)) begin
            if (sort_index < (n - sort_pass - 1)) begin
              if (sorted_h[sort_index] > sorted_h[sort_index+1]) begin
                // Swap logic
                sorted_h[sort_index] <= sorted_h[sort_index+1];
                sorted_h[sort_index+1] <= sorted_h[sort_index];
                sorted_t[sort_index] <= sorted_t[sort_index+1];
                sorted_t[sort_index+1] <= sorted_t[sort_index];
              end
              sort_index <= sort_index + 1;
            end else begin
              sort_pass <= sort_pass + 1;
              sort_index <= 4'b0;
            end
          end
        end
        
        ACCUMULATE: begin
          if (acc_index < n) begin
            if ((accumulated_time + sorted_t[acc_index]) <= sorted_h[acc_index]) begin
              accumulated_time <= accumulated_time + sorted_t[acc_index];
              count <= count + 1'b1;
            end
            acc_index <= acc_index + 1'b1;
          end
        end
        
        DONE: begin
          max_count <= count;
          done <= 1'b1;
        end
      endcase
    end
  end
  
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = SORT;
      SORT: if (sort_pass >= (n-1)) next_state = ACCUMULATE;
      ACCUMULATE: if (acc_index >= n) next_state = DONE;
      DONE: if (start) next_state = SORT;
      default: next_state = IDLE;
    endcase
  end
  
  // Initialization counters/accumulators upon state transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_pass <= 4'b0;
      sort_index <= 4'b0;
      acc_index <= 4'b0;
      accumulated_time <= 16'b0;
      count <= 4'b0;
    end else begin
      unique case (1'b1) // Synthesis-friendly priority logic
        (next_state == SORT && current_state != SORT): begin // Entering SORT
          sort_pass <= 4'b0;
          sort_index <= 4'b0;
        end
        (next_state == ACCUMULATE && current_state != ACCUMULATE): begin // Entering ACCUMULATE
          accumulated_time <= 16'b0;
          acc_index <= 4'b0;
          count <= 4'b0;
        end
        default: ;
      endcase
    end
  end
  
endmodule