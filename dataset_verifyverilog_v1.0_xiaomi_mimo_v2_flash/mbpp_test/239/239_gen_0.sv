module sequence_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] m,
    input wire [2:0] n,
    output reg [15:0] result,
    output reg done
);

    // FSM states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_BASE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;

    // Table storage: T[17][5] for i=0..16, j=0..4
    reg [15:0] T [0:16][0:4];

    // Iteration counters
    reg [4:0] i;
    reg [2:0] j;

    // Computation registers
    reg [15:0] temp_sum;
    reg [4:0] i_half;
    reg computing;
    reg [4:0] m_reg;
    reg [2:0] n_reg;

    // Control signals
    reg init_done;
    reg result_ready;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT_BASE;
                else
                    next_state = IDLE;
            end

            INIT_BASE: begin
                if (i == 0 || j == 0 || i < j) begin
                    // Base case initialized immediately
                    next_state = INIT_BASE;
                end else if (j == 1) begin
                    // Base case initialized immediately
                    next_state = INIT_BASE;
                end else begin
                    // Need computation
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                if (computing) begin
                    // Computation complete
                    next_state = INIT_BASE;
                end else begin
                    // Check if need to compute
                    if (i < j || j == 0 || j == 1) begin
                        // Skip computation
                        next_state = INIT_BASE;
                    end else begin
                        // Need computation
                        next_state = COMPUTE;
                    end
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 5'd0;
            j <= 3'd0;
            computing <= 1'b0;
            temp_sum <= 16'd0;
            i_half <= 5'd0;
            m_reg <= 5'd0;
            n_reg <= 3'd0;
            init_done <= 1'b0;
            result_ready <= 1'b0;
            // Initialize T array
            integer r, c;
            for (r = 0; r < 17; r = r + 1) begin
                for (c = 0; c < 5; c = c + 1) begin
                    T[r][c] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 5'd0;
                        j <= 3'd0;
                        m_reg <= m;
                        n_reg <= n;
                        computing <= 1'b0;
                        init_done <= 1'b0;
                        result_ready <= 1'b0;
                        // Reset T for new computation
                        integer r, c;
                        for (r = 0; r < 17; r = r + 1) begin
                            for (c = 0; c < 5; c = c + 1) begin
                                T[r][c] <= 16'd0;
                            end
                        end
                    end
                end

                INIT_BASE: begin
                    if (computing) begin
                        // Continue computation from COMPUTE state
                    end else begin
                        // Check base cases
                        if (i == 0 || j == 0 || i < j) begin
                            T[i][j] <= 16'd0;
                            // Move to next cell
                            if (j < n_reg && j < 3'd4) begin
                                j <= j + 3'd1;
                            end else begin
                                j <= 3'd0;
                                if (i < m_reg && i < 5'd16) begin
                                    i <= i + 5'd1;
                                end else begin
                                    // All cells initialized
                                    init_done <= 1'b1;
                                    // Start recursive computation from i=2, j=2
                                    if (m_reg >= 5'd2 && n_reg >= 3'd2) begin
                                        i <= 5'd2;
                                        j <= 3'd2;
                                    end else begin
                                        result <= T[m_reg][n_reg];
                                        result_ready <= 1'b1;
                                    end
                                end
                            end
                        end else if (j == 3'd1) begin
                            T[i][j] <= {11'd0, i}; // T[i][1] = i
                            // Move to next cell
                            if (j < n_reg && j < 3'd4) begin
                                j <= j + 3'd1;
                            end else begin
                                j <= 3'd0;
                                if (i < m_reg && i < 5'd16) begin
                                    i <= i + 5'd1;
                                end else begin
                                    init_done <= 1'b1;
                                    if (m_reg >= 5'd2 && n_reg >= 3'd2) begin
                                        i <= 5'd2;
                                        j <= 3'd2;
                                    end else begin
                                        result <= T[m_reg][n_reg];
                                        result_ready <= 1'b1;
                                    end
                                end
                            end
                        end else begin
                            // Need computation, set up
                            computing <= 1'b1;
                            i_half <= i >> 1;
                            temp_sum <= T[i-1][j];
                        end
                    end
                end

                COMPUTE: begin
                    if (computing) begin
                        // Complete the recursive computation
                        if (i_half > 5'd0 && j > 3'd1) begin
                            // Add T[i/2][j-1]
                            temp_sum <= temp_sum + T[i_half][j-1];
                        end
                        // Store result
                        T[i][j] <= temp_sum;
                        computing <= 1'b0;
                        // Move to next cell in INIT_BASE
                        // Keep i and j as they were
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= T[m_reg][n_reg];
                    state <= IDLE;
                end
            endcase

            // Check if computation is complete (after INIT_BASE handles the last cell)
            if (init_done && m_reg >= 5'd2 && n_reg >= 3'd2 && i == m_reg && j == n_reg && !computing) begin
                result <= T[m_reg][n_reg];
                result_ready <= 1'b1;
            end

            // Transition to finish when result is ready
            if (result_ready && state == IDLE && !start) begin
                // Actually finish when we reach the end of computation
            end
            if (init_done && state == INIT_BASE && !computing && i == m_reg && j == n_reg) begin
                // Ready to finish
            end
        end
    end

    // Combinational finish signal
    always @(*) begin
        if (state == INIT_BASE && !computing && init_done && m_reg >= 5'd2 && n_reg >= 3'd2 && i == m_reg && j == n_reg) begin
            next_state = FINISH;
        end else if (state == INIT_BASE && !computing && init_done && (m_reg < 5'd2 || n_reg < 3'd2) && result_ready) begin
            next_state = FINISH;
        end
    end

endmodule