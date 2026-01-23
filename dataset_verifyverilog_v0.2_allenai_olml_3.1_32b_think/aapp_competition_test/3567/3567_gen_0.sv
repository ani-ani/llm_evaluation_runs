module character_creator (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] num_players,
    input [7:0] num_features,
    input [7:0][7:0] characters,
    output reg [7:0] best_character,
    output reg [7:0] min_max_similarity,
    output reg done
);

localparam IDLE = 2'd0;
localparam INIT = 2'd1;
localparam PROCESS = 2'd2;
localparam DONE_STATE = 2'd3;

reg [1:0] state, next_state;
reg [7:0] best_char, min_max_sim, candidate, captured_num_players, captured_num_features, total_candidates;
reg [7:0] mask;
reg done;

function [3:0] popcount;
    input [7:0] x;
    popcount = x[7] + x[6] + x[5] + x[4] + x[3] + x[2] + x[1] + x[0];
endfunction

always @(*) begin
    case (captured_num_features)
        0: mask = 0;
        1: mask = 1;
        2: mask = 3;
        3: mask = 7;
        4: mask = 15;
        5: mask = 31;
        6: mask = 63;
        7: mask = 127;
        8: mask = 255;
        default: mask = 0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        best_char <= 0;
        min_max_sim <= 0;
        candidate <= 0;
        captured_num_players <= 0;
        captured_num_features <= 0;
        total_candidates <= 0;
        done <= 0;
    end else begin
        case (state)
            IDLE:  
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            INIT: begin
                captured_num_players <= num_players;
                captured_num_features <= num_features;
                case (captured_num_features)
                    0: total_candidates <= 1;
                    1: total_candidates <= 2;
                    2: total_candidates <= 4;
                    3: total_candidates <= 8;
                    4: total_candidates <= 16;
                    5: total_candidates <= 32;
                    6: total_candidates <= 64;
                    7: total_candidates <= 128;
                    8: total_candidates <= 256;
                    default: total_candidates <= 1;
                endcase
                next_state = PROCESS;
                candidate <= 0;
            end
            PROCESS: begin
                if (candidate >= total_candidates) begin
                    next_state = DONE_STATE;
                    done <= 1;
                end else begin
                    reg [7:0] current_max;
                    current_max = 0;
                    if (captured_num_players >= 1) begin
                        current_max = captured_num_features - popcount(candidate ^ (characters[0] & mask));
                    end
                    if (captured_num_players >= 2) begin
                        reg [7:0] sim1 = captured_num_features - popcount(candidate ^ (characters[1] & mask));
                        if (sim1 > current_max) current_max = sim1;
                    end
                    if (captured_num_players >= 3) begin
                        reg [7:0] sim2 = captured_num_features - popcount(candidate ^ (characters[2] & mask));
                        if (sim2 > current_max) current_max = sim2;
                    end
                    if (captured_num_players >= 4) begin
                        reg [7:0] sim3 = captured_num_features - popcount(candidate ^ (characters[3] & mask));
                        if (sim3 > current_max) current_max = sim3;
                    end
                    if (captured_num_players >= 5) begin
                        reg [7:0] sim4 = captured_num_features - popcount(candidate ^ (characters[4] & mask));
                        if (sim4 > current_max) current_max = sim4;
                    end
                    if (captured_num_players >= 6) begin
                        reg [7:0] sim5 = captured_num_features - popcount(candidate ^ (characters[5] & mask));
                        if (sim5 > current_max) current_max = sim5;
                    end
                    if (captured_num_players >= 7) begin
                        reg [7:0] sim6 = captured_num_features - popcount(candidate ^ (characters[6] & mask));
                        if (sim6 > current_max) current_max = sim6;
                    end
                    if (captured_num_players >= 8) begin
                        reg [7:0] sim7 = captured_num_features - popcount(candidate ^ (characters[7] & mask));
                        if (sim7 > current_max) current_max = sim7;
                    end
                    if (current_max < min_max_sim || min_max_sim == 0) begin
                        best_char <= candidate;
                        min_max_sim <= current_max;
                    end
                    candidate <= candidate + 1;
                    next_state = PROCESS;
                end
            end
            DONE_STATE: next_state = DONE_STATE;
        endcase
        state <= next_state;
    end
end
endmodule