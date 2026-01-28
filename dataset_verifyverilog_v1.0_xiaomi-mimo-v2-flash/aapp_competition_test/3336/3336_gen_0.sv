module ExcursionMaxStudents(
    input clk,
    input rst_n,
    input start,
    input [8:0] h [0:15],
    input [0:0] sex [0:15],
    input [2:0] music [0:15],
    input [2:0] sport [0:15],
    output reg [7:0] result,
    output reg done
);
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] STORE_DATA = 4'd1;
    localparam [3:0] BUILD_EDGES = 4'd2;
    localparam [3:0] MATCH_INIT = 4'd3;
    localparam [3:0] MATCH_START = 4'd4;
    localparam [3:0] MATCH_SEEK = 4'd5;
    localparam [3:0] MATCH_CHECK = 4'd6;
    localparam [3:0] MATCH_UPDATE = 4'd7;
    localparam [3:0] CALC_RESULT = 4'd8;
    localparam [3:0] DONE_STATE = 4'd9;
    localparam [3:0] MAX_N = 4'd16;
    localparam [8:0] HEIGHT_DIFF = 9'd40;
    
    reg [3:0] state, next_state;
    reg [3:0] n;
    reg [8:0] h_reg [0:15];
    reg [0:0] sex_reg [0:15];
    reg [2:0] music_reg [0:15];
    reg [2:0] sport_reg [0:15];
    reg [15:0] adj [0:15];
    reg [3:0] u;
    reg [3:0] v;
    reg [3:0] i;
    reg seen [0:15];
    reg [3:0] matchL [0:15];
    reg [3:0] matchR [0:15];
    reg [3:0] match_count;
    reg [7:0] depth;
    reg [3:0] save_u;
    reg [3:0] seen_idx;
    reg found_path;
    reg [8:0] diff_h;
    
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            n <= 4'd0;
            for (k = 0; k < 16; k = k + 1) begin
                h_reg[k] <= 9'd0;
                sex_reg[k] <= 1'd0;
                music_reg[k] <= 3'd0;
                sport_reg[k] <= 3'd0;
                adj[k] <= 16'd0;
                matchL[k] <= 4'd15;
                matchR[k] <= 4'd15;
                seen[k] <= 1'b0;
            end
            u <= 4'd0;
            v <= 4'd0;
            i <= 4'd0;
            depth <= 8'd0;
            match_count <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n <= MAX_N;
                    end
                end
                STORE_DATA: begin
                    h_reg[i] <= h[i];
                    sex_reg[i] <= sex[i];
                    music_reg[i] <= music[i];
                    sport_reg[i] <= sport[i];
                    i <= i + 4'd1;
                end
                BUILD_EDGES: begin
                    if (i < n) begin
                        adj[i] <= 16'd0;
                    end
                    if (i < n && v < n) begin
                        if (sex_reg[i] != sex_reg[v]) begin
                            if (h_reg[i] >= h_reg[v]) diff_h <= h_reg[i] - h_reg[v];
                            else diff_h <= h_reg[v] - h_reg[i];
                        end
                    end
                end
                MATCH_INIT: begin
                    matchL[u] <= 4'd15;
                    matchR[u] <= 4'd15;
                    match_count <= 4'd0;
                    u <= 4'd0;
                    v <= 4'd0;
                    i <= 4'd0;
                    for (k = 0; k < 16; k = k + 1) seen[k] <= 1'b0;
                    save_u <= 4'd0;
                    found_path <= 1'b0;
                end
                MATCH_START: begin
                    if (u < n) begin
                        v <= 4'd0;
                        i <= 4'd0;
                        for (k = 0; k < 16; k = k + 1) seen[k] <= 1'b0;
                        save_u <= u;
                        found_path <= 1'b0;
                    end
                end
                MATCH_SEEK: begin
                    if (i < n && !found_path) begin
                        if (adj[save_u][i] && !seen[i]) begin
                            seen[i] <= 1'b1;
                            if (matchR[i] == 4'd15 || matchR[i] == save_u) begin
                                found_path <= 1'b1;
                            end
                        end
                        i <= i + 4'd1;
                    end
                end
                MATCH_UPDATE: begin
                    if (found_path && match_count <= n) begin
                        match_count <= match_count + 4'd1;
                    end
                end
                CALC_RESULT: begin
                    result <= n - match_count;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = STORE_DATA;
            STORE_DATA: if (i == MAX_N) next_state = BUILD_EDGES;
            BUILD_EDGES: begin
                if (i < n) begin
                    if (v < n) begin
                        if (sex_reg[i] != sex_reg[v]) begin
                            if (diff_h <= HEIGHT_DIFF && music_reg[i] == music_reg[v] && sport_reg[i] != sport_reg[v]) begin
                                if (i != v) begin
                                end
                            end
                        end
                    end
                end
                if (i >= n) next_state = MATCH_INIT;
            end
            MATCH_INIT: next_state = MATCH_START;
            MATCH_START: if (u >= n) next_state = CALC_RESULT;
            MATCH_SEEK: if (i >= n || found_path) next_state = MATCH_UPDATE;
            MATCH_UPDATE: next_state = MATCH_START;
            CALC_RESULT: next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    always @(posedge clk) begin
        if (state == BUILD_EDGES && i < n && v < n) begin
            if (sex_reg[i] != sex_reg[v]) begin
                if (diff_h <= HEIGHT_DIFF && music_reg[i] == music_reg[v] && sport_reg[i] != sport_reg[v]) begin
                    if (i != v) begin
                        adj[i][v] <= 1'b1;
                    end
                end
            end
            if (v < n) begin
                if (v == n - 1) begin
                    v <= 4'd0;
                    i <= i + 4'd1;
                end else begin
                    v <= v + 4'd1;
                end
            end
        end
    end
endmodule