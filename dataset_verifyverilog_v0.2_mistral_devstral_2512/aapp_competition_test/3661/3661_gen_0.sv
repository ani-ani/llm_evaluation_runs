module lawsuit_assignment(
  input clk,
  input rst_n,
  input start,
  input [3:0] lawsuit_index,
  input [2:0] individual_idx,
  input [2:0] corporation_idx,
  output reg [2:0] winner_type,
  output reg [2:0] winner_id,
  output reg done,
  output reg [3:0] max_wins
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    UPDATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Win counters
  reg [3:0] individuals_wins [0:7];
  reg [3:0] corporations_wins [0:7];

  // Internal registers
  reg [3:0] lawsuit_counter;
  reg [3:0] current_max_wins;
  reg [2:0] current_individual_idx;
  reg [2:0] current_corporation_idx;
  reg [2:0] current_winner_type;
  reg [2:0] current_winner_id;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      lawsuit_counter <= 0;
      current_max_wins <= 0;
      done <= 0;
      winner_type <= 0;
      winner_id <= 0;
      max_wins <= 0;
      
      // Reset win counters
      for (int i = 0; i < 8; i++) begin
        individuals_wins[i] <= 0;
        corporations_wins[i] <= 0;
      end
    end else begin
      current_state <= next_state;
      
      // State-specific actions
      case (current_state)
        IDLE: begin
          done <= 0;
          winner_type <= 0;
          winner_id <= 0;
          max_wins <= 0;
        end
        
        PROCESSING: begin
          current_individual_idx <= individual_idx;
          current_corporation_idx <= corporation_idx;
        end
        
        UPDATE: begin
          // Compare wins and assign winner
          if (individuals_wins[current_individual_idx] <= corporations_wins[current_corporation_idx]) begin
            current_winner_type <= 0; // INDV
            current_winner_id <= current_individual_idx;
            individuals_wins[current_individual_idx] <= individuals_wins[current_individual_idx] + 1;
          end else begin
            current_winner_type <= 1; // CORP
            current_winner_id <= current_corporation_idx;
            corporations_wins[current_corporation_idx] <= corporations_wins[current_corporation_idx] + 1;
          end
          
          // Update max wins
          if (current_winner_type == 0) begin
            if (individuals_wins[current_individual_idx] > current_max_wins) begin
              current_max_wins <= individuals_wins[current_individual_idx];
            end
          end else begin
            if (corporations_wins[current_corporation_idx] > current_max_wins) begin
              current_max_wins <= corporations_wins[current_corporation_idx];
            end
          end
          
          // Increment lawsuit counter
          lawsuit_counter <= lawsuit_counter + 1;
        end
        
        DONE: begin
          done <= 1;
          winner_type <= current_winner_type;
          winner_id <= current_winner_id + 1; // Convert to 1-indexed
          max_wins <= current_max_wins;
        end
        
        default: begin
          current_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end
      
      PROCESSING: begin
        next_state = UPDATE;
      end
      
      UPDATE: begin
        if (lawsuit_counter == lawsuit_index) begin
          next_state = DONE;
        end else begin
          next_state = PROCESSING;
        end
      end
      
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output assignments
  always @(*) begin
    case (current_state)
      IDLE: begin
        winner_type = 0;
        winner_id = 0;
        done = 0;
        max_wins = 0;
      end
      
      PROCESSING: begin
        winner_type = 0;
        winner_id = 0;
        done = 0;
        max_wins = current_max_wins;
      end
      
      UPDATE: begin
        winner_type = current_winner_type;
        winner_id = current_winner_id + 1; // Convert to 1-indexed
        done = 0;
        max_wins = current_max_wins;
      end
      
      DONE: begin
        winner_type = current_winner_type;
        winner_id = current_winner_id + 1; // Convert to 1-indexed
        done = 1;
        max_wins = current_max_wins;
      end
      
      default: begin
        winner_type = 0;
        winner_id = 0;
        done = 0;
        max_wins = 0;
      end
    endcase
  end

endmodule