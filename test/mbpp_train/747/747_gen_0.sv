module lcs_three_strings(
    input  clk,
    input  rst_n,
    input  start,
    input  [7:0][7:0] str1,
    input  [7:0][7:0] str2,
    input  [7:0][7:0] str3,
    output reg [7:0] lcs_length,
    output reg       done
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        COMPUTE = 2'b01,
        DONE    = 2'b10
    } state_t;

    state_t state, next_state;

    // DP table L[0:8][0:8][0:8], each entry 8 bits
    reg [7:0] L [0:8][0:8][0:8];

    // Loop indices for DP iteration (1..8)
    reg [3:0] i, j, k;

    // Start pulse edge-detect
    reg start_d;
    wire start_pulse = start & ~start_d;

    // Max of three 8-bit values
    function automatic [7:0] max3;
        input [7:0] a, b, c;
        reg   [7:0] m1;
    begin
        m1   = (a >= b) ? a : b;
        max3 = (m1 >= c) ? m1 : c;
    end
    endfunction

    // Combinational next-state logic
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_pulse)
                    next_state = COMPUTE;
            end
            COMPUTE: begin
                // Transition to DONE after finishing i=j=k loops
                if ((i == 4'd8) && (j == 4'd8) && (k == 4'd8))
                    next_state = DONE;
            end
            DONE: begin
                if (start_pulse)
                    next_state = COMPUTE;
            end
            default: next_state = IDLE;
        endcase
    end

    integer ii, jj, kk;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            start_d     <= 1'b0;
            done        <= 1'b0;
            lcs_length  <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            // Initialize DP table to zero on reset
            for (ii = 0; ii <= 8; ii = ii + 1) begin
                for (jj = 0; jj <= 8; jj = jj + 1) begin
                    for (kk = 0; kk <= 8; kk = kk + 1) begin
                        L[ii][jj][kk] <= 8'd0;
                    end
                end
            end
        end else begin
            // Edge-detect register
            start_d <= start;

            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // On start_pulse, initialize indices and base layer
                    if (start_pulse) begin
                        // Initialize full DP table to zero (including boundaries)
                        for (ii = 0; ii <= 8; ii = ii + 1) begin
                            for (jj = 0; jj <= 8; jj = jj + 1) begin
                                for (kk = 0; kk <= 8; kk = kk + 1) begin
                                    L[ii][jj][kk] <= 8'd0;
                                end
                            end
                        end
                        // Set starting indices to first valid cell (1,1,1)
                        i <= 4'd1;
                        j <= 4'd1;
                        k <= 4'd1;
                    end
                end

                COMPUTE: begin
                    // Perform DP update for current (i,j,k)
                    if ((i != 4'd0) && (j != 4'd0) && (k != 4'd0)) begin
                        if ((str1[i-1] == str2[j-1]) && (str1[i-1] == str3[k-1])) begin
                            L[i][j][k] <= L[i-1][j-1][k-1] + 8'd1;
                        end else begin
                            L[i][j][k] <= max3(L[i-1][j][k], L[i][j-1][k], L[i][j][k-1]);
                        end
                    end

                    // Triple nested loop progression over 1..8 for i,j,k
                    if (k < 4'd8) begin
                        k <= k + 4'd1;
                    end else begin
                        k <= 4'd1;
                        if (j < 4'd8) begin
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd1;
                            if (i < 4'd8) begin
                                i <= i + 4'd1;
                            end else begin
                                // Completed (8,8,8); will move to DONE next_state
                                i <= 4'd8;
                                j <= 4'd8;
                                k <= 4'd8;
                            end
                        end
                    end

                    // When finishing last cell, capture result
                    if ((i == 4'd8) && (j == 4'd8) && (k == 4'd8)) begin
                        lcs_length <= L[8][8][8];
                    end
                end

                DONE: begin
                    // Hold result and done flag until next start
                    done <= 1'b1;
                    if (start_pulse) begin
                        done <= 1'b0;
                        // Re-initialize DP indices and table for new computation
                        for (ii = 0; ii <= 8; ii = ii + 1) begin
                            for (jj = 0; jj <= 8; jj = jj + 1) begin
                                for (kk = 0; kk <= 8; kk = kk + 1) begin
                                    L[ii][jj][kk] <= 8'd0;
                                end
                            end
                        end
                        i <= 4'd1;
                        j <= 4'd1;
                        k <= 4'd1;
                    end
                end

                default: begin
                    // Should not happen; safe defaults
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule