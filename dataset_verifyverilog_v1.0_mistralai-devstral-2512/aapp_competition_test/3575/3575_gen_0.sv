module absorbing_markov_chain(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] adj [0:7],
    input wire [3:0] start_s,
    input wire [3:0] start_t,
    input wire [3:0] n,
    output reg [31:0] expected_time,
    output reg done,
    output reg never_meet
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Adjacency matrix storage
    reg [7:0] adj_reg [0:7];
    reg [3:0] start_s_reg;
    reg [3:0] start_t_reg;
    reg [3:0] n_reg;

    // Expected time storage (Q16.16)
    reg signed [31:0] E [0:7][0:7];
    reg signed [31:0] E_next [0:7][0:7];

    // Degree calculation
    reg [3:0] degree [0:7];
    reg [31:0] inv_degree [0:7];

    // Convergence check
    reg signed [31:0] max_diff;
    localparam [31:0] CONVERGE_THRESHOLD = 32'd16; // 16/65536 = 0.000244

    // Initialize registers
    integer i, j, k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            never_meet <= 1'b0;
            expected_time <= 32'd0;
            cycle_count <= 8'd0;

            // Initialize adjacency matrix
            for (i = 0; i < 8; i = i + 1) begin
                adj_reg[i] <= 8'd0;
            end

            // Initialize expected times
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    E[i][j] <= 32'd0;
                    E_next[i][j] <= 32'd0;
                end
            end

            // Initialize degrees
            for (i = 0; i < 8; i = i + 1) begin
                degree[i] <= 4'd0;
                inv_degree[i] <= 32'd0;
            end

            start_s_reg <= 4'd0;
            start_t_reg <= 4'd0;
            n_reg <= 4'd0;

        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    never_meet <= 1'b0;
                    cycle_count <= 8'd0;

                    if (start) begin
                        // Store inputs
                        for (i = 0; i < 8; i = i + 1) begin
                            adj_reg[i] <= adj[i];
                        end
                        start_s_reg <= start_s;
                        start_t_reg <= start_t;
                        n_reg <= n;

                        // Calculate degrees
                        for (i = 0; i < 8; i = i + 1) begin
                            degree[i] <= 4'd0;
                            for (j = 0; j < 8; j = j + 1) begin
                                if (adj_reg[i][j]) begin
                                    degree[i] <= degree[i] + 4'd1;
                                end
                            end
                        end

                        // Precompute inverse degrees (Q16.16)
                        for (i = 0; i < 8; i = i + 1) begin
                            if (degree[i] > 4'd0) begin
                                // Fixed-point division: 1/degree[i] in Q16.16
                                inv_degree[i] <= 32'd65536 / degree[i];
                            end else begin
                                inv_degree[i] <= 32'd0;
                            end
                        end

                        // Initialize expected times
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (i == j) begin
                                    E[i][j] <= 32'd0; // Absorbing state
                                end else begin
                                    E[i][j] <= 32'd0; // Initial guess
                                end
                            end
                        end

                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    max_diff <= 32'd0;

                    // Compute next expected times
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (i == j) begin
                                E_next[i][j] <= 32'd0; // Absorbing state
                            end else if (degree[i] == 4'd0 || degree[j] == 4'd0) begin
                                // No outgoing edges - can't meet
                                E_next[i][j] <= 32'd0;
                            end else begin
                                // E_next = 1 + (1/deg(i)) * (1/deg(j)) * sum over neighbors
                                reg signed [31:0] sum_val;
                                sum_val = 32'd0;

                                for (k = 0; k < 8; k = k + 1) begin
                                    if (adj_reg[i][k] && adj_reg[j][k]) begin
                                        sum_val = sum_val + E[i][j];
                                    end
                                end

                                // Multiply by inverse degrees (Q16.16 * Q16.16 = Q32.32)
                                reg signed [63:0] temp;
                                temp = {32'd0, inv_degree[i]} * {32'd0, inv_degree[j]};
                                temp = temp * {32'd0, sum_val};

                                // Take middle 32 bits (Q16.16)
                                E_next[i][j] = 32'd65536 + temp[47:16];

                                // Check convergence
                                reg signed [31:0] diff;
                                diff = E_next[i][j] - E[i][j];
                                if (diff < 32'd0) begin
                                    diff = -diff;
                                end
                                if (diff > max_diff) begin
                                    max_diff <= diff;
                                end
                            end
                        end
                    end

                    // Update expected times
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            E[i][j] <= E_next[i][j];
                        end
                    end

                    // Check for convergence or max cycles
                    if (max_diff < CONVERGE_THRESHOLD || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Check if they can meet
                    reg can_meet;
                    can_meet = 1'b0;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (i != j && E[i][j] != 32'd0) begin
                                can_meet = 1'b1;
                            end
                        end
                    end

                    if (can_meet) begin
                        expected_time <= E[start_s_reg][start_t_reg];
                        never_meet <= 1'b0;
                    end else begin
                        expected_time <= 32'd0;
                        never_meet <= 1'b1;
                    end

                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule