module wine_arrangements(
    input clk,
    input rst_n,
    input start,
    input [3:0] R,
    input [3:0] W,
    output reg [15:0] result,
    output reg done
);

    // Parameters for state encoding
    localparam S_IDLE      = 4'd0;
    localparam S_INIT_1    = 4'd1; // Clear DP
    localparam S_INIT_2    = 4'd2; // Set Start State
    localparam S_LOOP_RD   = 4'd3; // Read DP value
    localparam S_UPD_R_RD  = 4'd4; // Read Red Dest
    localparam S_UPD_R_WR  = 4'd5; // Write Red Dest
    localparam S_UPD_W_RD  = 4'd6; // Read White Dest
    localparam S_UPD_W_WR  = 4'd7; // Write White Dest
    localparam S_NEXT      = 4'd8; // Increment counters
    localparam S_SUM       = 4'd9; // Sum results
    localparam S_DONE      = 4'd10;

    // Registers
    reg [3:0] current_state, next_state;
    reg [3:0] r_cnt, w_cnt; // 0..8
    reg [1:0] l_cnt, s_cnt; // 0..2
    reg [31:0] dp [0:8][0:8][0:2][0:2]; // Main DP table
    reg [31:0] temp_val; // Holds read value or working value
    reg [31:0] dest_val; // Holds destination value for read-modify-write

    // Wires for decoding destination indices
    wire [3:0] r_plus_1 = r_cnt + 1;
    wire [3:0] w_plus_1 = w_cnt + 1;
    wire [1:0] s_plus_1 = s_cnt + 1;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            done <= 1;
            result <= 0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    if (start) begin
                        current_state <= S_INIT_1;
                        done <= 0;
                    end
                end

                S_INIT_1: begin
                    result <= 0;
                    r_cnt <= 0;
                    w_cnt <= 0;
                    l_cnt <= 0;
                    s_cnt <= 0;
                    dp[0][0][0][0] <= 1; // Initialize start state
                    current_state <= S_LOOP_RD;
                end

                S_LOOP_RD: begin
                    // Check bounds
                    if (r_cnt > R || w_cnt > W) begin
                        current_state <= S_NEXT;
                    end else begin
                        // Read value
                        temp_val <= dp[r_cnt][w_cnt][l_cnt][s_cnt];

                        if (r_cnt == R && w_cnt == W) begin
                            result <= result + temp_val;
                        end

                        if (temp_val == 0) begin
                            current_state <= S_NEXT;
                        end else begin
                            current_state <= S_UPD_R_RD;
                        end
                    end
                end

                S_UPD_R_RD: begin
                    // Try Red update
                    if (r_cnt < R && (l_cnt != 1 || (l_cnt == 1 && s_cnt < 2))) begin
                        if (l_cnt != 1) begin
                            dest_val <= dp[r_plus_1][w_cnt][1][1];
                            r_dest_l <= 1;
                            r_dest_s <= 1;
                        end else begin
                            dest_val <= dp[r_plus_1][w_cnt][1][s_plus_1];
                            r_dest_l <= 1;
                            r_dest_s <= s_plus_1;
                        end
                        r_dest_r <= r_plus_1;
                        r_dest_w <= w_cnt;
                        current_state <= S_UPD_R_WR;
                    end else begin
                        current_state <= S_UPD_W_RD;
                    end
                end

                S_UPD_R_WR: begin
                    dp[r_dest_r][r_dest_w][r_dest_l][r_dest_s] <= dest_val + temp_val;
                    current_state <= S_UPD_W_RD;
                end

                S_UPD_W_RD: begin
                    if (w_cnt < W && (l_cnt != 2 || (l_cnt == 2))) begin
                        if (l_cnt != 2) begin
                            dest_val <= dp[r_cnt][w_plus_1][2][1];
                            w_dest_l <= 2;
                            w_dest_s <= 1;
                        end else begin
                            dest_val <= dp[r_cnt][w_plus_1][2][s_plus_1];
                            w_dest_l <= 2;
                            w_dest_s <= s_plus_1;
                        end
                        w_dest_r <= r_cnt;
                        w_dest_w <= w_plus_1;
                        current_state <= S_UPD_W_WR;
                    end else begin
                        current_state <= S_NEXT;
                    end
                end

                S_UPD_W_WR: begin
                    dp[w_dest_r][w_dest_w][w_dest_l][w_dest_s] <= dest_val + temp_val;
                    current_state <= S_NEXT;
                end

                S_NEXT: begin
                    if (s_cnt < 2) begin
                        s_cnt <= s_cnt + 1;
                    end else begin
                        s_cnt <= 0;
                        if (l_cnt < 2) begin
                            l_cnt <= l_cnt + 1;
                        end else begin
                            l_cnt <= 0;
                            if (w_cnt < W) begin
                                w_cnt <= w_cnt + 1;
                            end else begin
                                w_cnt <= 0;
                                if (r_cnt < R) begin
                                    r_cnt <= r_cnt + 1;
                                end else begin
                                    current_state <= S_DONE;
                                end
                            end
                        end
                    end
                    if (current_state != S_DONE) begin
                        current_state <= S_LOOP_RD;
                    end
                end

                S_DONE: begin
                    done <= 1;
                end

                default: current_state <= S_IDLE;
            endcase
        end
    end

    // Helper registers for destination storage
    reg [3:0] r_dest_r, r_dest_w;
    reg [1:0] r_dest_l, r_dest_s;
    reg [3:0] w_dest_r, w_dest_w;
    reg [1:0] w_dest_l, w_dest_s;

endmodule