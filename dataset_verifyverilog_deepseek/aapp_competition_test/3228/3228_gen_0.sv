module gondola_scheduler(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [4:0] t,
  input [1:0] g,
  input [4:0] skier_times [0:7],
  output reg [8:0] sum,
  output reg done
);
  
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;
  
  state_t state, next_state;
  reg [2:0] skier_idx;
  reg signed [5:0] gondola_departures [0:2];
  reg [4:0] sorted_times [0:7];
  reg [8:0] sum_next;
  reg sort_complete;
  integer i, j;
  
  always_comb begin
    for (i=0; i<8; i=i+1) sorted_times[i] = skier_times[i];
    sort_complete = 1'b0;
    
    if (state == IDLE) begin
      for (i=0; i<7; i=i+1) begin
        for (j=0; j<7-i; j=j+1) begin
          if (sorted_times[j] > sorted_times[j+1]) begin
            sorted_times[j] = sorted_times[j+1];
            sorted_times[j+1] = sorted_times[j];
          end
        end
      end
      sort_complete = 1'b1;
    end
  end
  
  always_comb begin
    automatic logic signed [5:0] current_departure;
    automatic logic signed [5:0] min_departure;
    automatic logic signed [5:0] arrival_signed;
    automatic logic [1:0] gondola_choice;
    
    sum_next = sum;
    min_departure = 6'sb111111;
    gondola_choice = 2'b0;
    
    if (state == PROCESSING) begin
      for (int k=0; k<g; k=k+1) begin
        if (gondola_departures[k] < min_departure) begin
          min_departure = gondola_departures[k];
          gondola_choice = k;
        end
      end
      
      arrival_signed = {1'b0, sorted_times[skier_idx]};
      
      if (min_departure <= arrival_signed) begin
        current_departure = arrival_signed + (t << 1);
        sum_next = sum;
      end
      else begin
        current_departure = min_departure + (t << 1);
        sum_next = sum + (min_departure - arrival_signed);
      end
    end
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum <= 9'b0;
      done <= 1'b0;
      skier_idx <= 3'b0;
      for (int i=0; i<3; i=i+1) gondola_departures[i] <= -6'sb100000;
    end
    else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          skier_idx <= 3'b0;
          sum <= 9'b0;
          done <= 1'b0;
          for (int i=0; i<g; i=i+1) gondola_departures[i] <= - (t << 1);
          if (start) begin
            next_state = PROCESSING;
          end
          else begin
            next_state = IDLE;
          end
        end
        
        PROCESSING: begin
          if (skier_idx < n) begin
            gondola_departures[gondola_choice] <= current_departure;
            sum <= sum_next;
            skier_idx <= skier_idx + 1;
            next_state = PROCESSING;
          end
          else begin
            next_state = DONE;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          if (start) begin
            next_state = IDLE;
          end
          else begin
            next_state = DONE;
          end
        end
        
        default: next_state = IDLE;
      endcase
    end
  end
endmodule