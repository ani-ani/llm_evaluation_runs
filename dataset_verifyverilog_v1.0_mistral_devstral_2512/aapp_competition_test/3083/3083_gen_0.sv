module find_playlist (
    input clk,
    input rst_n,
    input start,
    input [6:0] n,  // number of songs (9-100)
    input [7:0] artist_idx [0:99],  // mapped artist indices for each song
    input [5:0] neighbor_count [0:99],  // number of neighbors per song
    input [6:0] neighbors [0:99][0:39],  // adjacency list
    output reg [6:0] path [0:8],  // output playlist of 9 songs
    output reg found,
    output reg done
);

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] START_SEARCH = 3'd2;
localparam [2:0] CHECK_NEIGHBOR = 3'd3;
localparam [2:0] CHECK_VALIDITY = 3'd4;
localparam [2:0] UPDATE_PATH = 3'd5;
localparam [2:0] BACKTRACK = 3'd6;
localparam [2:0] FOUND = 3'd7;
localparam [2:0] FAIL = 3'd8;

reg [2:0] state;
reg [3:0] current_depth;  // 0-9
reg [6:0] song_stack [0:8];  // current path
reg [5:0] neighbor_idx_stack [0:8];  // next neighbor to try
reg [99:0] artist_mask;  // bit mask for used artists
reg [6:0] start_song_idx;  // current starting song
reg [6:0] candidate_song;
reg [5:0] temp_idx;
reg duplicate;
reg artist_used;
integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        found <= 1'b0;
        done <= 1'b0;
        current_depth <= 4'd0;
        artist_mask <= 100'd0;
        start_song_idx <= 7'd0;
        for (i = 0; i < 9; i = i + 1) begin
            song_stack[i] <= 7'd0;
            neighbor_idx_stack[i] <= 6'd0;
            path[i] <= 7'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= INIT;
                    done <= 1'b0;
                    found <= 1'b0;
                end
            end
            INIT: begin
                current_depth <= 4'd0;
                artist_mask <= 100'd0;
                start_song_idx <= 7'd0;
                for (i = 0; i < 9; i = i + 1) begin
                    neighbor_idx_stack[i] <= 6'd0;
                end
                state <= START_SEARCH;
            end
            START_SEARCH: begin
                if (current_depth == 4'd0) begin
                    if (start_song_idx < n) begin
                        song_stack[0] <= start_song_idx;
                        artist_mask[artist_idx[start_song_idx]] <= 1'b1;
                        current_depth <= 4'd1;
                        neighbor_idx_stack[0] <= 6'd0;
                        state <= CHECK_NEIGHBOR;
                    end else begin
                        state <= FAIL;
                    end
                end else begin
                    state <= CHECK_NEIGHBOR;
                end
            end
            CHECK_NEIGHBOR: begin
                if (current_depth > 4'd0 && current_depth < 4'd9) begin
                    temp_idx = current_depth - 4'd1;
                    if (neighbor_idx_stack[temp_idx] < neighbor_count[song_stack[temp_idx]]) begin
                        candidate_song <= neighbors[song_stack[temp_idx]][neighbor_idx_stack[temp_idx]];
                        neighbor_idx_stack[temp_idx] <= neighbor_idx_stack[temp_idx] + 6'd1;
                        state <= CHECK_VALIDITY;
                    end else begin
                        state <= BACKTRACK;
                    end
                end else if (current_depth == 4'd9) begin
                    state <= FOUND;
                end else begin
                    state <= BACKTRACK;
                end
            end
            CHECK_VALIDITY: begin
                // Check duplicate song
                duplicate = 1'b0;
                for (i = 0; i < current_depth; i = i + 1) begin
                    if (song_stack[i] == candidate_song) duplicate = 1'b1;
                end
                // Check artist
                artist_used = artist_mask[artist_idx[candidate_song]];
                if (!duplicate && !artist_used) begin
                    state <= UPDATE_PATH;
                end else begin
                    state <= CHECK_NEIGHBOR;
                end
            end
            UPDATE_PATH: begin
                song_stack[current_depth] <= candidate_song;
                artist_mask[artist_idx[candidate_song]] <= 1'b1;
                neighbor_idx_stack[current_depth] <= 6'd0;
                current_depth <= current_depth + 4'd1;
                if (current_depth + 4'd1 == 4'd9) begin
                    state <= FOUND;
                end else begin
                    state <= CHECK_NEIGHBOR;
                end
            end
            BACKTRACK: begin
                if (current_depth == 4'd0) begin
                    start_song_idx <= start_song_idx + 7'd1;
                    state <= START_SEARCH;
                end else begin
                    artist_mask[artist_idx[song_stack[current_depth-4'd1]]] <= 1'b0;
                    current_depth <= current_depth - 4'd1;
                    state <= CHECK_NEIGHBOR;
                end
            end
            FOUND: begin
                for (i = 0; i < 9; i = i + 1) begin
                    path[i] <= song_stack[i];
                end
                found <= 1'b1;
                done <= 1'b1;
                state <= IDLE;
            end
            FAIL: begin
                found <= 1'b0;
                done <= 1'b1;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule