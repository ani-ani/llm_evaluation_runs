module TournamentScheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] m,
    output reg [63:0] result,
    output reg [5:0] round_index,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CALC    = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    localparam [1:0] DONE    = 2'd3;
    
    reg [1:0] state, next_state;
    reg [5:0] current_round;
    reg [7:0] game_count;
    reg [7:0] game_index;
    reg [7:0] player_p;
    reg [7:0] player_q;
    reg [7:0] team_t;
    reg [7:0] team_u;
    reg [7:0] temp_result [0:7];
    reg [7:0] i;
    reg [7:0] j;

    // Calculate total rounds
    wire [9:0] total_rounds = (m - 1'b1) * n;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_round <= 6'd0;
            game_count <= 8'd0;
            game_index <= 8'd0;
            player_p <= 8'd0;
            player_q <= 8'd0;
            team_t <= 8'd0;
            team_u <= 8'd0;
            result <= 64'd0;
            round_index <= 6'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                temp_result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= CALC;
                        current_round <= 6'd0;
                        game_count <= 8'd0;
                        game_index <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                CALC: begin
                    // Initialize temp_result
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_result[i] <= 8'd0;
                    end
                    
                    // Calculate games for current round
                    game_count <= 8'd0;
                    for (team_t = 0; team_t < m; team_t = team_t + 1) begin
                        team_u <= (team_t + 1'b1) % m;
                        for (player_p = 0; player_p < n; player_p = player_p + 1) begin
                            player_q <= (current_round - player_p) % n;
                            if (game_count < 8'd8) begin
                                temp_result[game_count] <= team_t * 25 + player_p;
                                game_count <= game_count + 1'b1;
                                if (game_count < 8'd8) begin
                                    temp_result[game_count] <= team_u * 25 + player_q;
                                    game_count <= game_count + 1'b1;
                                end
                            end
                        end
                    end
                    next_state <= OUTPUT;
                end
                
                OUTPUT: begin
                    // Pack temp_result into result
                    result <= {temp_result[7], temp_result[6], temp_result[5], temp_result[4],
                              temp_result[3], temp_result[2], temp_result[1], temp_result[0]};
                    round_index <= current_round;
                    
                    // Check if done
                    if (current_round == total_rounds - 1'b1) begin
                        next_state <= DONE;
                    end else begin
                        current_round <= current_round + 1'b1;
                        next_state <= CALC;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule