module character_creator (
  input clk,
  input rst_n,
  input start,
  input [7:0] num_players,
  input [7:0] num_features,
  input [7:0][7:0] characters,
  output reg [7:0] best_character,
  output reg [7:0] min_max_similarity,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT_CANDIDATE,
    COMPUTE_SIM,
    UPDATE_MAX,
    NEXT_CANDIDATE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] candidate;
  reg [7:0] current_max_sim;
  reg [7:0] player_idx;
  reg [7:0] current_similarity;
  reg [7:0] best_candidate;
  reg [7:0] best_max_sim;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      candidate <= 0;
      current_max_sim <= 0;
      player_idx <= 0;
      current_similarity <= 0;
      best_candidate <= 0;
      best_max_sim <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_CANDIDATE;
      end
      INIT_CANDIDATE: begin
        next_state = COMPUTE_SIM;
      end
      COMPUTE_SIM: begin
        if (player_idx == num_players - 1) begin
          next_state = UPDATE_MAX;
        end else begin
          next_state = COMPUTE_SIM;
        end
      end
      UPDATE_MAX: begin
        next_state = NEXT_CANDIDATE;
      end
      NEXT_CANDIDATE: begin
        if (candidate == (1 << num_features) - 1) begin
          next_state = DONE;
        end else begin
          next_state = INIT_CANDIDATE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      candidate <= 0;
      current_max_sim <= 0;
      player_idx <= 0;
      current_similarity <= 0;
      best_candidate <= 0;
      best_max_sim <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          // No action
        end
        INIT_CANDIDATE: begin
          if (state == INIT_CANDIDATE) begin
            candidate <= 0;
            current_max_sim <= 0;
            player_idx <= 0;
            current_similarity <= 0;
          end
        end
        COMPUTE_SIM: begin
          if (state == COMPUTE_SIM) begin
            current_similarity <= compute_similarity(candidate, characters[player_idx], num_features);
            if (player_idx == num_players - 1) begin
              // Last player, move to update
            end else begin
              player_idx <= player_idx + 1;
            end
          end
        end
        UPDATE_MAX: begin
          if (state == UPDATE_MAX) begin
            if (current_similarity > current_max_sim) begin
              current_max_sim <= current_similarity;
            end
            if (current_max_sim < best_max_sim || best_max_sim == 0) begin
              best_max_sim <= current_max_sim;
              best_candidate <= candidate;
            end
          end
        end
        NEXT_CANDIDATE: begin
          if (state == NEXT_CANDIDATE) begin
            candidate <= candidate + 1;
          end
        end
        DONE: begin
          if (state == DONE) begin
            best_character <= best_candidate;
            min_max_similarity <= best_max_sim;
            done <= 1;
          end
        end
        default: ;
      endcase
    end
  end

  // Combinational similarity calculation
  function [7:0] compute_similarity;
    input [7:0] a;
    input [7:0] b;
    input [7:0] k;
    reg [7:0] count;
    integer i;
    begin
      count = 0;
      for (i = 0; i < k; i = i + 1) begin
        if (a[i] == b[i]) begin
          count = count + 1;
        end
      end
      compute_similarity = count;
    end
  endfunction

endmodule