module plane_scheduler(input clk, input rst_n, input start, input [15:0] inspect_time [0:3], input [15:0] flight_times [0:3][0:3], input [1:0] flight_s [0:3], input [1:0] flight_f [0:3], input [15:0] flight_t [0:3], output reg [2:0] plane_count, output reg done);
  
  // FSM States
  typedef enum {IDLE, CALC, DONE} state_t;
  state_t current_state, next_state;
  reg [6:0] counter;
  
  // Edge connectivity matrix
  reg [3:0][3:0] connect;
  
  // Max match calculation
  reg [2:0] max_match;
  
  // FSM Control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      plane_count <= 0;
      counter <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_state <= CALC;
            counter <= 0;
          end
        end
        CALC: begin
          max_match <= calculate_max_match();  // Combinational calculation
          if (counter == 99) begin
            plane_count <= 4 - max_match;
            done <= 1'b1;
            current_state <= DONE;
          end else begin
            counter <= counter + 1;
          end
        end
        DONE: ;  // Hold done until reset
        default: current_state <= IDLE;
      endcase
    end
  end
  
  // Precompute connectivity
  integer i, j;
  always_comb begin
    for (i = 0; i < 4; i=i+1) begin
      for (j = 0; j < 4; j=j+1) begin
        if (i == j)
          connect[i][j] = 1'b0;
        else
          connect[i][j] = (flight_t[j] >= flight_t[i] + flight_times[flight_f[i]][flight_s[j]] + inspect_time[flight_f[i]]) ? 1'b1 : 1'b0;
      end
    end
  end
  
  // Maximum matching calculation
  function automatic logic [2:0] calculate_max_match;
    logic [3:0] src_mask;
    logic [3:0] dst_mask;
    logic [2:0] tmp_max;
    
    calculate_max_match = 0;
    // Check all connection permutations
    for (int p0=0; p0<4; p0=p0+1) begin
      if (!connect[0][p0] || (0 == p0)) continue;
      
      for (int p1=0; p1<4; p1=p1+1) begin
        if (!connect[1][p1] || (1 == p1) || (p1 == p0)) continue;
        
        for (int p2=0; p2<4; p2=p2+1) begin
          if (!connect[2][p2] || (2 == p2) || (p2 == p0) || (p2 == p1)) continue;
          
          for (int p3=0; p3<4; p3=p3+1) begin
            if (!connect[3][p3] || (3 == p3) || (p3 == p0) || (p3 == p1) || (p3 == p2)) continue;
            return 4;
          end
          
          // 3-order match
          tmp_max = 3;
        end
        
        // 2-order match
        if (calculate_max_match < 2) calculate_max_match = 2;
      end
      
      // 1-order match
      if (calculate_max_match < 1) calculate_max_match = 1;
    end
    
    // Explicit lower-bound checks
    if (calculate_max_match < tmp_max) calculate_max_match = tmp_max;
  endfunction
  
endmodule