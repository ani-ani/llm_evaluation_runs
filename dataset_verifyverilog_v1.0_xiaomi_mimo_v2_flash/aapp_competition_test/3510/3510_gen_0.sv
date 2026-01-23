module game_solver #(parameter N=8, parameter MAX_OPTIONS=8) (
    input wire clk,
    input wire rst_n,
    input wire load_en,
    input wire [2:0] load_pos,
    input wire [2:0] load_option_idx,
    input wire [N-1:0] load_option_mask,
    input wire compute,
    input wire [2:0] target,
    input wire [2:0] start,
    output reg [3:0] distance,
    output reg done
);

    // Function to compute log2 ceiling
    function integer log2ceiling;
        input integer n;
        integer i;
        begin
            log2ceiling = 0;
            for(i = 0; 2**i < n; i = i + 1)
                log2ceiling = i + 1;
        end
    endfunction

    localparam [3:0] STATE_IDLE = 4'd0;
    localparam [3:0] STATE_INIT = 4'd1;
    localparam [3:0] STATE_START_ROUND = 4'd2;
    localparam [3:0] STATE_CHECK_POS = 4'd3;
    localparam [3:0] STATE_CHECK_OPT = 4'd4;
    localparam [3:0] STATE_NEXT_OPT = 4'd5;
    localparam [3:0] STATE_NEXT_POS = 4'd6;
    localparam [3:0] STATE_AFTER_ROUND = 4'd7;
    localparam [3:0] STATE_OUTPUT = 4'd8;

    // Storage for game description
    reg [N-1:0] option_masks [0:N-1][0:MAX_OPTIONS-1];
    reg option_valid [0:N-1][0:MAX_OPTIONS-1];

    // Computation state
    reg [3:0] dist [0:N-1];
    reg [3:0] next_dist [0:N-1];
    reg [2:0] round;
    reg [2:0] p;
    reg [2:0] opt;
    reg updated;
    reg [3:0] state;

    // Combinational signals
    reg option_good;
    integer i;

    // Option check: all successors have dist != 4'hF
    always @(*) begin
        option_good = 0;
        if (state == STATE_CHECK_OPT && option_valid[p][opt]) begin
            option_good = 1;
            for (i = 0; i < N; i = i + 1) begin
                if (option_masks[p][opt][i]) begin
                    if (dist[i] == 4'hF) begin
                        option_good = 0;
                    end
                end
            end
        end
    end

    // Load logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset valid flags
            for (i = 0; i < N; i = i + 1) begin
                for (integer j = 0; j < MAX_OPTIONS; j = j + 1) begin
                    option_valid[i][j] <= 0;
                end
            end
        end else if (load_en) begin
            option_masks[load_pos][load_option_idx] <= load_option_mask;
            option_valid[load_pos][load_option_idx] <= 1;
        end
    end

    // State machine
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done <= 0;
            distance <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 0;
                    if (compute) begin
                        state <= STATE_INIT;
                    end
                end

                STATE_INIT: begin
                    // Initialize dist: all invalid, target = 0
                    for (i = 0; i < N; i = i + 1) begin
                        dist[i] <= 4'hF;
                    end
                    dist[target] <= 0;
                    round <= 1;
                    state <= STATE_START_ROUND;
                end

                STATE_START_ROUND: begin
                    // Copy current dist to next_dist
                    for (i = 0; i < N; i = i + 1) begin
                        next_dist[i] <= dist[i];
                    end
                    updated <= 0;
                    p <= 0;
                    state <= STATE_CHECK_POS;
                end

                STATE_CHECK_POS: begin
                    if (p >= N) begin
                        state <= STATE_AFTER_ROUND;
                    end else if (dist[p] != 4'hF) begin
                        // Already assigned, skip
                        state <= STATE_NEXT_POS;
                    end else begin
                        opt <= 0;
                        state <= STATE_CHECK_OPT;
                    end
                end

                STATE_CHECK_OPT: begin
                    if (opt >= MAX_OPTIONS) begin
                        state <= STATE_NEXT_POS;
                    end else if (!option_valid[p][opt]) begin
                        state <= STATE_NEXT_OPT;
                    end else if (option_good) begin
                        next_dist[p] <= round;
                        updated <= 1;
                        state <= STATE_NEXT_POS;
                    end else begin
                        state <= STATE_NEXT_OPT;
                    end
                end

                STATE_NEXT_OPT: begin
                    opt <= opt + 1;
                    state <= STATE_CHECK_OPT;
                end

                STATE_NEXT_POS: begin
                    p <= p + 1;
                    state <= STATE_CHECK_POS;
                end

                STATE_AFTER_ROUND: begin
                    if (updated && round < N) begin
                        // Apply updates and go to next round
                        for (i = 0; i < N; i = i + 1) begin
                            dist[i] <= next_dist[i];
                        end
                        round <= round + 1;
                        state <= STATE_START_ROUND;
                    end else begin
                        // No updates or max rounds reached
                        state <= STATE_OUTPUT;
                    end
                end

                STATE_OUTPUT: begin
                    distance <= dist[start];
                    done <= 1;
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule