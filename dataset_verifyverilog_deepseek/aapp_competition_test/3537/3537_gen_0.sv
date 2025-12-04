module travel_frustration_minimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] target_n,
  input [31:0] flight_table [0:7][0:3],
  output reg [31:0] min_frustration,
  output reg done
);
  
  typedef enum logic [1:0] { IDLE, PROCESS, FINISH } state_t;
  state_t state, next_state;
  
  // Country list: [0] = country1, [1] = country2, ..., [4] = country5
  reg [31:0] frustration [0:4];
  reg [6:0] arrival_time [0:4];
  reg [4:0] counter;
  
  // Combinational next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:   if (start) next_state = PROCESS;
      PROCESS: if (counter == 14) next_state = FINISH;
      FINISH: next_state = FINISH;
      default: next_state = IDLE;
    endcase
  end
  
  // State transition and registers update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      frustration <= '{0:'0, default:'1};
      arrival_time <= '{default:0};
      counter <= 0;
      min_frustration <= 0;
    end else begin
      state <= next_state;
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            frustration <= '{0:'0, default:'1};
            arrival_time <= '{default:0};
            counter <= 0;
          end
          min_frustration <= 0;
        end
        PROCESS: begin
          frustration <= next_frustration;
          arrival_time <= next_arrival;
          counter <= counter + 1;
        end
        FINISH: begin
          done <= 1;
          min_frustration <= frustration[target_n - 1];
        end
      endcase
    end
  end
  
  // Combinational logic to update frustration and arrival_time
  reg [31:0] next_frustration [0:4];
  reg [6:0] next_arrival [0:4];
  always_comb begin
    next_frustration = frustration;
    next_arrival = arrival_time;
    
    if (state == PROCESS) begin
      for (int i = 0; i < 8; i++) begin
        logic [2:0] a = flight_table[i][0][2:0];
        logic [2:0] b = flight_table[i][1][2:0];
        logic [6:0] s = flight_table[i][2][6:0];
        logic [6:0] e = flight_table[i][3][6:0];
        
        if (a >= 3'd1 && a <= 3'd5 && b >= 3'd1 && b <= 3'd5) begin
          int a_idx = a - 1;
          int b_idx = b - 1;
          
          if (frustration[a_idx] != '1) begin
            logic signed [6:0] wait_time = s - arrival_time[a_idx];
            
            if ($signed(wait_time) >= 0) begin
              logic [31:0] new_frust = frustration[a_idx] + (wait_time ** 2);
              
              if (new_frust < next_frustration[b_idx]) begin
                next_frustration[b_idx] = new_frust;
                next_arrival[b_idx] = e;
              end
            end
          end
        end
      end
    end
  end
endmodule