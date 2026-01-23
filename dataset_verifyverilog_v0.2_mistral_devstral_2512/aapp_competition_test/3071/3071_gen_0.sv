module tournament_scheduler (
  input clk,
  input rst_n,
  input start,
  input [3:0] n_in,
  input [3:0] m_in,
  output reg [5:0] round_index,
  output reg [4:0] game_count,
  output reg [4:0] player1_idx,
  output reg [4:0] player2_idx,
  output reg output_valid,
  output reg done
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam SETUP = 3'b001;
  localparam GEN_ROUND = 3'b010;
  localparam NEXT_ROUND = 3'b011;
  localparam DONE = 3'b100;

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // Internal registers
  reg [5:0] current_round = 0;
  reg [4:0] current_game = 0;
  reg [4:0] total_players = 0;
  reg [4:0] total_games = 0;
  reg [4:0] player1 = 0;
  reg [4:0] player2 = 0;
  reg [4:0] rotation = 0;
  reg [4:0] fixed_player = 0;
  reg [4:0] game_counter = 0;
  reg [4:0] team_size = 0;
  reg [4:0] num_teams = 0;
  reg [4:0] i = 0;
  reg [4:0] j = 0;
  reg [4:0] k = 0;
  reg [4:0] temp_player = 0;
  reg [4:0] team1 = 0;
  reg [4:0] team2 = 0;
  reg valid_pair = 0;
  reg [4:0] bye_player = 0;
  reg [4:0] max_rounds = 0;

  // State transitions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_round <= 0;
      current_game <= 0;
      total_players <= 0;
      total_games <= 0;
      player1 <= 0;
      player2 <= 0;
      rotation <= 0;
      fixed_player <= 0;
      game_counter <= 0;
      team_size <= 0;
      num_teams <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      temp_player <= 0;
      team1 <= 0;
      team2 <= 0;
      valid_pair <= 0;
      bye_player <= 0;
      max_rounds <= 0;
      round_index <= 0;
      game_count <= 0;
      player1_idx <= 0;
      player2_idx <= 0;
      output_valid <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = SETUP;
        end
      end
      SETUP: begin
        next_state = GEN_ROUND;
      end
      GEN_ROUND: begin
        if (current_game >= total_games - 1) begin
          next_state = NEXT_ROUND;
        end
      end
      NEXT_ROUND: begin
        if (current_round >= max_rounds - 1) begin
          next_state = DONE;
        end else begin
          next_state = GEN_ROUND;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else begin
      case (state)
        IDLE: begin
          // Wait for start
        end
        SETUP: begin
          // Calculate total players and games
          team_size <= n_in;
          num_teams <= m_in;
          total_players <= team_size * num_teams;
          total_games <= (total_players % 2 == 0) ? total_players / 2 : (total_players - 1) / 2;
          max_rounds <= (total_players % 2 == 0) ? total_players - 1 : total_players;
          current_round <= 0;
          current_game <= 0;
          rotation <= 0;
          fixed_player <= 0;
          game_counter <= 0;
          round_index <= 0;
          game_count <= total_games;
          done <= 0;
        end
        GEN_ROUND: begin
          // Generate games for current round
          if (current_game < total_games) begin
            // Circle method for round-robin
            if (current_game == 0) begin
              // First game: fixed player vs rotation
              player1 <= fixed_player;
              player2 <= rotation;
            end else begin
              // Other games: rotate players
              i <= current_game;
              j <= (current_game + rotation) % (total_players - 1);
              if (j >= fixed_player) begin
                j <= j + 1;
              end
              player1 <= i;
              player2 <= j;
            end
            // Check if players are from different teams
            team1 <= player1 / team_size;
            team2 <= player2 / team_size;
            valid_pair <= (team1 != team2);
            // Output valid game
            if (valid_pair) begin
              player1_idx <= player1;
              player2_idx <= player2;
              output_valid <= 1;
              current_game <= current_game + 1;
            end else begin
              // Skip invalid pair
              current_game <= current_game + 1;
            end
          end
        end
        NEXT_ROUND: begin
          // Move to next round
          rotation <= (rotation + 1) % (total_players - 1);
          current_round <= current_round + 1;
          current_game <= 0;
          round_index <= current_round;
          game_count <= total_games;
          output_valid <= 0;
        end
        DONE: begin
          done <= 1;
          output_valid <= 0;
        end
        default: begin
          // Default case
        end
      endcase
    end
  end

endmodule