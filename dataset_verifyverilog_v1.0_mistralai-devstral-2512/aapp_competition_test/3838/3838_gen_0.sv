module permutation_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] q,
    input wire [63:0] s,
    input wire [3:0] n_in,
    input wire [3:0] k_in,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] SIMULATE = 3'd2;
    localparam [2:0] DECIDE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Input parsing
    reg [3:0] q_arr [0:15];
    reg [3:0] s_arr [0:15];
    reg [3:0] q_inv [0:15];
    reg [3:0] n, k;

    // Simulation state
    reg [3:0] p_current [0:15];
    reg [3:0] p_next [0:15];
    reg [3:0] first_match_move;
    reg match_found;
    reg [3:0] move_count;

    // Helper signals
    reg [3:0] i, j;
    reg identity_match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            n <= 4'd0;
            k <= 4'd0;
            first_match_move <= 4'd0;
            match_found <= 1'b0;
            move_count <= 4'd0;
            identity_match <= 1'b0;

            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                q_arr[i] <= 4'd0;
                s_arr[i] <= 4'd0;
                q_inv[i] <= 4'd0;
                p_current[i] <= 4'd0;
                p_next[i] <= 4'd0;
            end
        end else begin
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PARSE;
                        cycle_count <= 8'd0;
                    end
                end

                PARSE: begin
                    // Parse n and k
                    n <= n_in;
                    k <= k_in;

                    // Parse q and s arrays
                    for (i = 0; i < 16; i = i + 1) begin
                        q_arr[i] <= q[i*4 +: 4];
                        s_arr[i] <= s[i*4 +: 4];
                    end

                    // Compute q_inv
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (q_arr[j] == i + 1) begin
                                q_inv[i] <= j + 1;
                            end
                        end
                    end

                    // Initialize p_current to identity
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n) begin
                            p_current[i] <= i + 1;
                        end else begin
                            p_current[i] <= 4'd0;
                        end
                    end

                    // Check if s is identity
                    identity_match <= 1'b1;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n) begin
                            if (s_arr[i] != i + 1) begin
                                identity_match <= 1'b0;
                            end
                        end
                    end

                    state <= SIMULATE;
                end

                SIMULATE: begin
                    // Check if current state matches s
                    reg [3:0] current_match;
                    current_match <= 1'b1;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n) begin
                            if (p_current[i] != s_arr[i]) begin
                                current_match <= 1'b0;
                            end
                        end
                    end

                    // Record first match
                    if (current_match && !match_found) begin
                        match_found <= 1'b1;
                        first_match_move <= move_count;
                    end

                    // Simulate next move if not at k
                    if (move_count < k) begin
                        // Apply q (heads)
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < n) begin
                                p_next[i] <= p_current[q_arr[i] - 1];
                            end else begin
                                p_next[i] <= 4'd0;
                            end
                        end

                        // Copy next to current
                        for (i = 0; i < 16; i = i + 1) begin
                            p_current[i] <= p_next[i];
                        end

                        move_count <= move_count + 4'd1;
                    end else begin
                        state <= DECIDE;
                    end
                end

                DECIDE: begin
                    // Decision logic
                    if (k == 4'd0) begin
                        result <= identity_match;
                    end else begin
                        if (identity_match) begin
                            result <= 1'b0;
                        end else begin
                            if (match_found && (first_match_move == k)) begin
                                result <= 1'b1;
                            end else begin
                                result <= 1'b0;
                            end
                        end
                    end

                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule