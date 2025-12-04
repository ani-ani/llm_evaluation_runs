module second_smallest(
  input clk,
  input rst_n,
  input start,
  input [15:0] numbers[0:7],
  output reg [15:0] result,
  output reg valid,
  output reg done
);

parameter IDLE = 2'b00;
parameter REMOVE_DUPS = 2'b01;
parameter SORT = 2'b10;
parameter OUTPUT = 2'b11;

reg [1:0] state, next_state;
reg [3:0] i, i_next;
reg [3:0] sort_cycle, sort_cycle_next;
reg [2:0] uniq_count, uniq_count_next;
reg [15:0] uniq[0:7], uniq_next[0:7];
reg [15:0] temp[0:7], temp_next[0:7];
reg [15:0] result_next;
reg valid_next;
reg done_next;

always @(*) begin
  next_state = state;
  i_next = i;
  sort_cycle_next = sort_cycle;
  uniq_count_next = uniq_count;
  result_next = result;
  valid_next = valid;
  done_next = done;
  
  for (int k=0; k<8; k++) begin
    uniq_next[k] = uniq[k];
    temp_next[k] = temp[k];
  end

  case (state)
    IDLE: begin
      if (start) begin
        next_state = REMOVE_DUPS;
        i_next = 0;
        sort_cycle_next = 0;
        uniq_count_next = 0;
        for (int k=0; k<8; k++) begin
          uniq_next[k] = 0;
          temp_next[k] = 0;
        end
        result_next = 0;
        valid_next = 0;
        done_next = 0;
      end
    end
    
    REMOVE_DUPS: begin
      if (i < 8) begin
        reg found;
        found = 0;
        for (int j=0; j<uniq_count; j++) begin
          if (uniq[j] == numbers[i]) begin
            found = 1;
          end
        end
        
        if (!found) begin
          uniq_next[uniq_count] = numbers[i];
          uniq_count_next = uniq_count + 1;
        end
        
        i_next = i + 1;
        
        if (i == 7) begin
          next_state = SORT;
        end else begin
          next_state = REMOVE_DUPS;
        end
      end
    end
    
    SORT: begin
      if (sort_cycle < 8) begin
        if (sort_cycle == 0) begin
          for (int k=0; k<8; k++) begin
            if (k < uniq_count) begin
              temp_next[k] = uniq[k];
            end else begin
              temp_next[k] = 16'h7FFF;
            end
          end
        end else begin
          temp_next = temp;
          if (sort_cycle % 2 == 0) begin
            for (int i=0; i<8; i+=2) begin
              if (i+1 < 8) begin
                if (temp[i] > temp[i+1]) begin
                  temp_next[i] = temp[i+1];
                  temp_next[i+1] = temp[i];
                end
              end
            end
          end else begin
            for (int i=1; i<7; i+=2) begin
              if (i+1 < 8) begin
                if (temp[i] > temp[i+1]) begin
                  temp_next[i] = temp[i+1];
                  temp_next[i+1] = temp[i];
                end
              end
            end
          end
        end
        
        sort_cycle_next = sort_cycle + 1;
        
        if (sort_cycle == 7) begin
          next_state = OUTPUT;
        end else begin
          next_state = SORT;
        end
      end
    end
    
    OUTPUT: begin
      if (uniq_count >= 2) begin
        result_next = temp[1];
        valid_next = 1;
      end else begin
        result_next = 0;
        valid_next = 0;
      end
      done_next = 1;
      next_state = IDLE;
    end
  endcase
end

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    i <= 0;
    sort_cycle <= 0;
    uniq_count <= 0;
    for (int k=0; k<8; k++) begin
      uniq[k] <= 0;
      temp[k] <= 0;
    end
    result <= 0;
    valid <= 0;
    done <= 0;
  end else begin
    state <= next_state;
    i <= i_next;
    sort_cycle <= sort_cycle_next;
    uniq_count <= uniq_count_next;
    for (int k=0; k<8; k++) begin
      uniq[k] <= uniq_next[k];
      temp[k] <= temp_next[k];
    end
    result <= result_next;
    valid <= valid_next;
    done <= done_next;
  end
end

endmodule