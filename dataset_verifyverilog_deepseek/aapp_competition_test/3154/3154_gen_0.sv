module toy_assignment(
  input clk,
  input rst_n,
  input start,
  input [3:0] in_kid_id,
  input [3:0] in_toy_id,
  input [15:0] in_event_time,
  input [2:0] in_event_count,
  output reg [7:0] assignments,
  output reg impossible_flag,
  output reg done
);

  localparam [2:0] 
    IDLE = 3'b000,
    PROCESS = 3'b001,
    COMPUTE_PREF = 3'b010,
    ENUM_CHECK = 3'b011,
    DONE = 3'b100;

  reg [2:0] state, next_state;
  reg [15:0] total_play [0:3][0:3];
  reg [15:0] first_playtime [0:3][0:3];
  reg [1:0] kid_idx;
  reg [1:0] toy_idx;
  reg [2:0] event_counter;
  reg [4:0] perm_counter;
  reg [7:0] best_assign;
  reg found;
  reg invalid_assignment;
  
  wire [1:0] curr_kid = in_kid_id[1:0];
  wire [1:0] curr_toy = in_toy_id[1:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      impossible_flag <= 0;
      assignments <= 8'b0;
      for (int k=0; k<4; k=k+1) begin
        for (int t=0; t<4; t=t+1) begin
          total_play[k][t] <= 16'b0;
          first_playtime[k][t] <= 16'hFFFF;
        end
      end
      event_counter <= 0;
      perm_counter <= 0;
      best_assign <= 8'b0;
      found <= 0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 0;
          impossible_flag <= 0;
          found <= 0;
          if (start) begin
            event_counter <= 0;
            perm_counter <= 0;
            for (int k=0; k<4; k=k+1) begin
              for (int t=0; t<4; t=t+1) begin
                total_play[k][t] <= 16'b0;
                first_playtime[k][t] <= 16'hFFFF;
              end
            end
          end
        end

        PROCESS: begin
          if (event_counter < in_event_count) begin
            total_play[curr_kid][curr_toy] <= total_play[curr_kid][curr_toy] + in_event_time;
            if (in_event_time < first_playtime[curr_kid][curr_toy])
              first_playtime[curr_kid][curr_toy] <= in_event_time;
            event_counter <= event_counter + 1;
          end
        end

        COMPUTE_PREF: begin
          perm_counter <= 0;
          best_assign <= 8'b0;
          found <= 0;
        end

        ENUM_CHECK: begin
          if (!found) perm_counter <= perm_counter + 1;
          if (!invalid_assignment && !found) begin
            best_assign <= assignments;
            found <= 1;
          end
          if (perm_counter == 24 && !found) begin
            impossible_flag <= 1;
          end
        end

        DONE: begin
          done <= 1;
          if (!impossible_flag) assignments <= best_assign;
        end
      endcase
    end
  end

  always_comb begin
    case (state)
      IDLE: next_state = start ? PROCESS : IDLE;
      PROCESS: next_state = (event_counter == in_event_count) ? COMPUTE_PREF : PROCESS;
      COMPUTE_PREF: next_state = ENUM_CHECK;
      ENUM_CHECK: next_state = (perm_counter == 24 || found) ? DONE : ENUM_CHECK;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  always_comb begin
    assignments = 8'b0;
    invalid_assignment = 0;
    case (perm_counter)
      00: assignments = {2'd0,2'd1,2'd2,2'd3};
      01: assignments = {2'd0,2'd1,2'd3,2'd2};
      02: assignments = {2'd0,2'd2,2'd1,2'd3};
      03: assignments = {2'd0,2'd2,2'd3,2'd1};
      04: assignments = {2'd0,2'd3,2'd1,2'd2};
      05: assignments = {2'd0,2'd3,2'd2,2'd1};
      06: assignments = {2'd1,2'd0,2'd2,2'd3};
      07: assignments = {2'd1,2'd0,2'd3,2'd2};
      08: assignments = {2'd1,2'd2,2'd0,2'd3};
      09: assignments = {2'd1,2'd2,2'd3,2'd0};
      10: assignments = {2'd1,2'd3,2'd0,2'd2};
      11: assignments = {2'd1,2'd3,2'd2,2'd0};
      12: assignments = {2'd2,2'd0,2'd1,2'd3};
      13: assignments = {2'd2,2'd0,2'd3,2'd1};
      14: assignments = {2'd2,2'd1,2'd0,2'd3};
      15: assignments = {2'd2,2'd1,2'd3,2'd0};
      16: assignments = {2'd2,2'd3,2'd0,2'd1};
      17: assignments = {2'd2,2'd3,2'd1,2'd0};
      18: assignments = {2'd3,2'd0,2'd1,2'd2};
      19: assignments = {2'd3,2'd0,2'd2,2'd1};
      20: assignments = {2'd3,2'd1,2'd0,2'd2};
      21: assignments = {2'd3,2'd1,2'd2,2'd0};
      22: assignments = {2'd3,2'd2,2'd0,2'd1};
      23: assignments = {2'd3,2'd2,2'd1,2'd0};
      default: assignments = 8'b0;
    endcase
    
    for (int i=0; i<4; i=i+1) begin
      automatic logic [1:0] toy_i = assignments[i*2 +: 2];
      for (int j=0; j<4; j=j+1) begin
        automatic logic [1:0] toy_j = assignments[j*2 +: 2];
        if (i != j && toy_i == toy_j) invalid_assignment = 1;
      end
    end
    
    if (!invalid_assignment) begin
      for (int k=0; k<4; k=k+1) begin
        automatic logic [1:0] toy_k = assignments[k*2 +: 2];
        for (int a=0; a<4; a=a+1) begin
          if (total_play[a][toy_k] > total_play[k][toy_k])
            invalid_assignment = 1;
        end
      end
    end
  end

endmodule