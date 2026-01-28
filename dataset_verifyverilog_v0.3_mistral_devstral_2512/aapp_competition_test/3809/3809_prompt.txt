module boat_transport (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] c50,
    input wire [3:0] c100,
    input wire [9:0] k,
    output reg [7:0] min_rides,
    output reg [31:0] ways,
    output reg done
);

// Parameters
parameter MAX_ITER = 100;
parameter INF = 8'hFF;
parameter MOD = 32'd1000000007;

// State definitions
parameter IDLE = 3'd0;
parameter INIT = 3'd1;
parameter SET_DEPTH = 3'd2;
parameter CHECK_STATE = 3'd3;
parameter NEXT_STATE = 3'd4;
parameter CHECK_MOVE = 3'd5;
parameter UPDATE = 3'd6;
parameter DONE = 3'd7;

// Registers and wires
reg [2:0] state, next_state;
reg [7:0] dist [0:8][0:8][0:1]; // distance array
reg [31:0] ways_arr [0:8][0:8][0:1]; // ways array
reg [7:0] C [0:8][0:8]; // combination table

// State variables
reg [3:0] i, j, s; 
reg [3:0] x, y;
reg [3:0] max_x, max_y;
reg [7:0] current_depth;
reg [7:0] new_dist;
reg [31:0] ways_contrib;
reg [3:0] ni, nj;
reg ns;
reg [9:0] move_weight;

// Combination table initialization (combinational)
integer idx1, idx2;
always @(*) begin
    for (idx1 = 0; idx1 <= 8; idx1 = idx1 + 1) begin
        for (idx2 = 0; idx2 <= 8; idx2 = idx2 + 1) begin
            if (idx2 > idx1) C[idx1][idx2] = 8'd0;
            else if (idx2 == 0 || idx2 == idx1) C[idx1][idx2] = 8'd1;
            else if (idx1 == 1) C[idx1][idx2] = 8'd1;
            else if (idx1 == 2) C[idx1][idx2] = (idx2 == 1) ? 8'd2 : 8'd1;
            else if (idx1 == 3) C[idx1][idx2] = (idx2 == 1 || idx2 == 2) ? 8'd3 : 8'd1;
            else if (idx1 == 4) C[idx1][idx2] = (idx2 == 2) ? 8'd6 : (idx2 == 1 || idx2 == 3) ? 8'd4 : 8'd1;
            else if (idx1 == 5) C[idx1][idx2] = (idx2 == 2) ? 8'd10 : (idx2 == 3) ? 8'd10 : (idx2 == 1 || idx2 == 4) ? 8'd5 : 8'd1;
            else if (idx1 == 6) C[idx1][idx2] = (idx2 == 3) ? 8'd20 : (idx2 == 2 || idx2 == 4) ? 8'd15 : (idx2 == 1 || idx2 == 5) ? 8'd6 : 8'd1;
            else if (idx1 == 7) C[idx1][idx2] = (idx2 == 3) ? 8'd35 : (idx2 == 4) ? 8'd35 : (idx2 == 2 || idx2 == 5) ? 8'd21 : (idx2 == 1 || idx2 == 6) ? 8'd7 : 8'd1;
            else if (idx1 == 8) C[idx1][idx2] = (idx2 == 4) ? 8'd70 : (idx2 == 3 || idx2 == 5) ? 8'd56 : (idx2 == 2 || idx2 == 6) ? 8'd28 : (idx2 == 1 || idx2 == 7) ? 8'd8 : 8'd1;
            else C[idx1][idx2] = 8'd0;
        end
    end
end

// State transition and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        min_rides <= 8'd0;
        ways <= 32'd0;
        done <= 1'b0;
        current_depth <= 8'd0;
        i <= 4'd0;
        j <= 4'd0;
        s <= 1'd0;
        x <= 4'd0;
        y <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) state <= INIT;
            end

            INIT: begin
                // Initialize dist and ways_arr arrays
                for (i = 0; i <= 8; i = i + 1) begin
                    for (j = 0; j <= 8; j = j + 1) begin
                        for (s = 0; s <= 1; s = s + 1) begin
                            dist[i][j][s] <= INF;
                            ways_arr[i][j][s] <= 32'd0;
                        end
                    end
                end
                // Set initial state
                dist[c50][c100][0] <= 8'd0;
                ways_arr[c50][c100][0] <= 32'd1;
                // Reset counters
                current_depth <= 8'd0;
                i <= 4'd0;
                j <= 4'd0;
                s <= 1'd0;
                state <= SET_DEPTH;
            end

            SET_DEPTH: begin
                if (current_depth >= MAX_ITER) begin
                    state <= DONE;
                end else begin
                    i <= 4'd0;
                    j <= 4'd0;
                    s <= 1'd0;
                    state <= CHECK_STATE;
                end
            end

            CHECK_STATE: begin
                if (i > c50 || (i == c50 && j > c100 && s > 1)) begin
                    current_depth <= current_depth + 1;
                    state <= SET_DEPTH;
                end else begin
                    if (dist[i][j][s] == current_depth) begin
                        // Setup move generation
                        if (s == 0) begin
                            max_x <= i;
                            max_y <= j;
                        end else begin
                            max_x <= c50 - i;
                            max_y <= c100 - j;
                        end
                        x <= 4'd0;
                        y <= 4'd0;
                        state <= CHECK_MOVE;
                    end else begin
                        state <= NEXT_STATE;
                    end
                end
            end

            NEXT_STATE: begin
                if (s == 1) begin
                    s <= 1'd0;
                    if (j == c100) begin
                        j <= 4'd0;
                        i <= i + 1;
                    end else begin
                        j <= j + 1;
                    end
                end else begin
                    s <= s + 1;
                end
                state <= CHECK_STATE;
            end

            CHECK_MOVE: begin
                if (x > max_x) begin
                    state <= NEXT_STATE;
                end else if (y > max_y) begin
                    y <= 4'd0;
                    x <= x + 1;
                end else begin
                    // Check move validity
                    move_weight = x * 8'd50 + y * 8'd100;
                    if ((x + y > 0) && (move_weight <= k)) begin
                        // Compute new state
                        if (s == 0) begin
                            ni = i - x;
                            nj = j - y;
                        end else begin
                            ni = i + x;
                            nj = j + y;
                        end
                        ns = 1 - s;
                        new_dist = current_depth + 1;
                        // Compute ways contribution
                        if (s == 0) begin
                            ways_contrib = ways_arr[i][j][s] * C[i][x] * C[j][y];
                        end else begin
                            ways_contrib = ways_arr[i][j][s] * C[c50 - i][x] * C[c100 - j][y];
                        end
                        ways_contrib = ways_contrib % MOD;
                        // Update state
                        if (new_dist < dist[ni][nj][ns]) begin
                            dist[ni][nj][ns] <= new_dist;
                            ways_arr[ni][nj][ns] <= ways_contrib;
                        end else if (new_dist == dist[ni][nj][ns]) begin
                            ways_arr[ni][nj][ns] <= (ways_arr[ni][nj][ns] + ways_contrib) % MOD;
                        end
                    end
                    y <= y + 1;
                end
            end

            DONE: begin
                if (dist[0][0][1] == INF) begin
                    min_rides <= 8'hFF; // Represent -1
                    ways <= 32'd0;
                end else begin
                    min_rides <= dist[0][0][1];
                    ways <= ways_arr[0][0][1];
                end
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule