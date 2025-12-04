module explosion_probability(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_my_minions,
  input [1:0] num_opp_minions,
  input [1:0] my_health_1,
  input [1:0] my_health_2,
  input [1:0] opp_health_1,
  input [1:0] opp_health_2,
  input [1:0] d,
  output reg [31:0] prob,
  output reg done
);

typedef enum {IDLE, INIT, PROCESSING, DONE} state_t;
state_t current_state, next_state;

logic [7:0] state_addr;
logic [1:0] step_cnt;
logic [31:0] current_prob [0:255];
logic [31:0] next_prob [0:255];
logic [7:0] health_state;
logic [1:0] my_h1, my_h2, opp_h1, opp_h2;
logic [3:0] minion_alive;
logic [1:0] alive_count;
logic [31:0] multiplier;
logic [31:0] contrib;

// Fixed-point constants
localparam Q16_ONE = 32'h1_0000;
localparam Q16_HALF = 32'h0_8000;
localparam Q16_THIRD = 32'h0_5555;
localparam Q16_QUARTER = 32'h0_4000;

// FSM logic
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    done <= 0;
    prob <= 0;
    step_cnt <= 0;
    for (int i=0; i<256; i++) current_prob[i] <= 0;
  end
  else begin
    case (current_state)
      IDLE: begin
        done <= 0;
        if (start) current_state <= INIT;
      end
      
      INIT: begin
        for (int i=0; i<256; i++) current_prob[i] <= 0;
        health_state = {my_health_1, my_health_2, opp_health_1, opp_health_2};
        current_prob[health_state] <= Q16_ONE;
        step_cnt <= 0;
        current_state <= PROCESSING;
      end
      
      PROCESSING: begin
        if (step_cnt == d) begin
          current_state <= DONE;
        end
        else begin
          step_cnt <= step_cnt + 1;
          for (int i=0; i<256; i++) begin
            current_prob[i] <= next_prob[i];
          end
        end
      end
      
      DONE: begin
        done <= 1;
        current_state <= IDLE;
        // Sum final probabilities where all opponent minions are dead
        prob <= 0;
        for (int i=0; i<256; i=i+1) begin
          {my_h1, my_h2, opp_h1, opp_h2} = i;
          if ((num_opp_minions >= 2'd1 && opp_h1 == 0 || num_opp_minions < 2'd1) &&
              (num_opp_minions >= 2'd2 && opp_h2 == 0 || num_opp_minions < 2'd2)) begin
            prob <= prob + current_prob[i];
          end
        end
      end
      
      default: current_state <= IDLE;
    endcase
  end
end

// Next state combinational logic
always_comb begin
  next_state = current_state;
  if (current_state == DONE) next_state = IDLE;
end

// Probability processing
always_comb begin
  // Default: clear all next states
  for (int i=0; i<256; i++) next_prob[i] = 0;
  
  if (current_state == PROCESSING) begin
    
    for (int i=0; i<256; i++) begin
      if (current_prob[i] != 0) begin
        health_state = i;
        {my_h1, my_h2, opp_h1, opp_h2} = health_state;
        
        // Determine alive minions
        minion_alive[0] = (num_my_minions >= 1) && (my_h1 != 0);
        minion_alive[1] = (num_my_minions >= 2) && (my_h2 != 0);
        minion_alive[2] = (num_opp_minions >= 1) && (opp_h1 != 0);
        minion_alive[3] = (num_opp_minions >= 2) && (opp_h2 != 0);
        alive_count = minion_alive[0] + minion_alive[1] + minion_alive[2] + minion_alive[3];
        
        case (alive_count)
          1: multiplier = Q16_ONE;   // 1/1
          2: multiplier = Q16_HALF;   // 1/2
          3: multiplier = Q16_THIRD;  // 1/3
          4: multiplier = Q16_QUARTER;// 1/4
          default: multiplier = 0;
        endcase
        
        // Generate next states
        if (alive_count > 0) begin
          // Each valid target
          if (minion_alive[0]) begin // My minion 1
            contrib = (current_prob[i] * multiplier) >>> 16;
            next_prob[{((my_h1 > 1) ? my_h1 - 1 : 0), my_h2, opp_h1, opp_h2}] += contrib;
          end
          if (minion_alive[1]) begin // My minion 2
            contrib = (current_prob[i] * multiplier) >>> 16;
            next_prob[{my_h1, ((my_h2 > 1) ? my_h2 - 1 : 0), opp_h1, opp_h2}] += contrib;
          end
          if (minion_alive[2]) begin // Opp minion 1
            contrib = (current_prob[i] * multiplier) >>> 16;
            next_prob[{my_h1, my_h2, ((opp_h1 > 1) ? opp_h1 - 1 : 0), opp_h2}] += contrib;
          end
          if (minion_alive[3]) begin // Opp minion 2
            contrib = (current_prob[i] * multiplier) >>> 16;
            next_prob[{my_h1, my_h2, opp_h1, ((opp_h2 > 1) ? opp_h2 - 1 : 0)}] += contrib;
          end
        end
        else begin
          next_prob[health_state] += current_prob[i];
        end
      end
    end
  end
end

endmodule