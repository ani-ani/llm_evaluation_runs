module SharedNumberSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [47:0] p1_in,
    input wire [47:0] p2_in,
    input wire [3:0] n,
    input wire [3:0] m,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Parsed pairs storage
    reg [3:0] p1_pairs [0:11]; // 12 pairs, each with 2 numbers
    reg [3:0] p2_pairs [0:11];

    // Comparison results
    reg [3:0] shared_numbers [0:143]; // 12*12 max
    reg [7:0] shared_count;
    reg [7:0] shared_index;

    // Calculation variables
    reg [3:0] unique_values [0:9]; // Track unique shared numbers
    reg [7:0] unique_count;
    reg [3:0] candidate;
    reg candidate_valid;

    // Iteration counters
    reg [3:0] i, j, k;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all registers
            for (i = 0; i < 12; i = i + 1) begin
                p1_pairs[i] <= 4'd0;
                p2_pairs[i] <= 4'd0;
            end
            for (i = 0; i < 144; i = i + 1) begin
                shared_numbers[i] <= 4'd0;
            end
            shared_count <= 8'd0;
            shared_index <= 8'd0;
            for (i = 0; i < 10; i = i + 1) begin
                unique_values[i] <= 4'd0;
            end
            unique_count <= 8'd0;
            candidate <= 4'd0;
            candidate_valid <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PARSE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARSE: begin
                    // Parse p1_in into pairs
                    for (i = 0; i < 12; i = i + 1) begin
                        p1_pairs[i] <= p1_in[47 - (i * 4) - 3: 47 - (i * 4) - 6];
                    end
                    // Parse p2_in into pairs
                    for (i = 0; i < 12; i = i + 1) begin
                        p2_pairs[i] <= p2_in[47 - (i * 4) - 3: 47 - (i * 4) - 6];
                    end
                    next_state <= COMPARE;
                    i <= 4'd0;
                    j <= 4'd0;
                    shared_count <= 8'd0;
                end

                COMPARE: begin
                    // Compare all pairs
                    if (i < n && j < m) begin
                        // Check if pairs share exactly one number
                        if ((p1_pairs[i][3:0] == p2_pairs[j][3:0] && p1_pairs[i][7:4] != p2_pairs[j][7:4]) ||
                            (p1_pairs[i][3:0] == p2_pairs[j][7:4] && p1_pairs[i][7:4] != p2_pairs[j][3:0]) ||
                            (p1_pairs[i][7:4] == p2_pairs[j][3:0] && p1_pairs[i][3:0] != p2_pairs[j][7:4]) ||
                            (p1_pairs[i][7:4] == p2_pairs[j][7:4] && p1_pairs[i][3:0] != p2_pairs[j][3:0])) begin
                            // Store shared number
                            if (p1_pairs[i][3:0] == p2_pairs[j][3:0] || p1_pairs[i][3:0] == p2_pairs[j][7:4]) begin
                                shared_numbers[shared_count] <= p1_pairs[i][3:0];
                            end else begin
                                shared_numbers[shared_count] <= p1_pairs[i][7:4];
                            end
                            shared_count <= shared_count + 8'd1;
                        end
                        // Move to next pair
                        if (j == m - 1) begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end else begin
                            j <= j + 4'd1;
                        end
                    end else begin
                        next_state <= CALCULATE;
                        shared_index <= 8'd0;
                        unique_count <= 8'd0;
                        for (k = 0; k < 10; k = k + 1) begin
                            unique_values[k] <= 4'd0;
                        end
                    end
                end

                CALCULATE: begin
                    // Find unique shared numbers
                    if (shared_index < shared_count) begin
                        reg [3:0] current = shared_numbers[shared_index];
                        reg found = 1'b0;
                        for (k = 0; k < unique_count; k = k + 1) begin
                            if (unique_values[k] == current) begin
                                found = 1'b1;
                            end
                        end
                        if (!found && current != 4'd0) begin
                            unique_values[unique_count] <= current;
                            unique_count <= unique_count + 8'd1;
                        end
                        shared_index <= shared_index + 8'd1;
                    end else begin
                        // Determine result
                        if (unique_count == 4'd1) begin
                            result <= unique_values[0];
                            candidate_valid <= 1'b1;
                        end else if (unique_count > 4'd1) begin
                            // Check if all pairs from p1 share same number with p2
                            reg [3:0] p1_shared [0:11];
                            reg [3:0] p2_shared [0:11];
                            reg p1_consistent = 1'b1;
                            reg p2_consistent = 1'b1;
                            reg [3:0] p1_candidate = 4'd0;
                            reg [3:0] p2_candidate = 4'd0;
                            integer p1_idx, p2_idx;

                            // Initialize
                            for (p1_idx = 0; p1_idx < 12; p1_idx = p1_idx + 1) begin
                                p1_shared[p1_idx] <= 4'd0;
                            end
                            for (p2_idx = 0; p2_idx < 12; p2_idx = p2_idx + 1) begin
                                p2_shared[p2_idx] <= 4'd0;
                            end

                            // Find shared numbers for each p1 pair
                            for (p1_idx = 0; p1_idx < n; p1_idx = p1_idx + 1) begin
                                for (p2_idx = 0; p2_idx < m; p2_idx = p2_idx + 1) begin
                                    if ((p1_pairs[p1_idx][3:0] == p2_pairs[p2_idx][3:0] && p1_pairs[p1_idx][7:4] != p2_pairs[p2_idx][7:4]) ||
                                        (p1_pairs[p1_idx][3:0] == p2_pairs[p2_idx][7:4] && p1_pairs[p1_idx][7:4] != p2_pairs[p2_idx][3:0]) ||
                                        (p1_pairs[p1_idx][7:4] == p2_pairs[p2_idx][3:0] && p1_pairs[p1_idx][3:0] != p2_pairs[p2_idx][7:4]) ||
                                        (p1_pairs[p1_idx][7:4] == p2_pairs[p2_idx][7:4] && p1_pairs[p1_idx][3:0] != p2_pairs[p2_idx][3:0])) begin
                                        if (p1_pairs[p1_idx][3:0] == p2_pairs[p2_idx][3:0] || p1_pairs[p1_idx][3:0] == p2_pairs[p2_idx][7:4]) begin
                                            if (p1_shared[p1_idx] == 4'd0) begin
                                                p1_shared[p1_idx] <= p1_pairs[p1_idx][3:0];
                                            end else if (p1_shared[p1_idx] != p1_pairs[p1_idx][3:0]) begin
                                                p1_consistent = 1'b0;
                                            end
                                        end else begin
                                            if (p1_shared[p1_idx] == 4'd0) begin
                                                p1_shared[p1_idx] <= p1_pairs[p1_idx][7:4];
                                            end else if (p1_shared[p1_idx] != p1_pairs[p1_idx][7:4]) begin
                                                p1_consistent = 1'b0;
                                            end
                                        end
                                    end
                                end
                            end

                            // Find shared numbers for each p2 pair
                            for (p2_idx = 0; p2_idx < m; p2_idx = p2_idx + 1) begin
                                for (p1_idx = 0; p1_idx < n; p1_idx = p1_idx + 1) begin
                                    if ((p1_pairs[p1_idx][3:0] == p2_pairs[p2_idx][3:0] && p1_pairs[p1_idx][7:4] != p2_pairs[p2_idx][7:4]) ||
                                        (p1_pairs[p1_idx][3:0] == p2_pairs[p2_idx][7:4] && p1_pairs[p1_idx][7:4] != p2_pairs[p2_idx][3:0]) ||
                                        (p1_pairs[p1_idx][7:4] == p2_pairs[p2_idx][3:0] && p1_pairs[p1_idx][3:0] != p2_pairs[p2_idx][7:4]) ||
                                        (p1_pairs[p1_idx][7:4] == p2_pairs[p2_idx][7:4] && p1_pairs[p1_idx][3:0] != p2_pairs[p2_idx][3:0])) begin
                                        if (p2_pairs[p2_idx][3:0] == p1_pairs[p1_idx][3:0] || p2_pairs[p2_idx][3:0] == p1_pairs[p1_idx][7:4]) begin
                                            if (p2_shared[p2_idx] == 4'd0) begin
                                                p2_shared[p2_idx] <= p2_pairs[p2_idx][3:0];
                                            end else if (p2_shared[p2_idx] != p2_pairs[p2_idx][3:0]) begin
                                                p2_consistent = 1'b0;
                                            end
                                        end else begin
                                            if (p2_shared[p2_idx] == 4'd0) begin
                                                p2_shared[p2_idx] <= p2_pairs[p2_idx][7:4];
                                            end else if (p2_shared[p2_idx] != p2_pairs[p2_idx][7:4]) begin
                                                p2_consistent = 1'b0;
                                            end
                                        end
                                    end
                                end
                            end

                            // Check consistency
                            if (p1_consistent && p2_consistent) begin
                                // Find common candidate
                                for (p1_idx = 0; p1_idx < n; p1_idx = p1_idx + 1) begin
                                    if (p1_shared[p1_idx] != 4'd0) begin
                                        if (p1_candidate == 4'd0) begin
                                            p1_candidate = p1_shared[p1_idx];
                                        end else if (p1_candidate != p1_shared[p1_idx]) begin
                                            p1_consistent = 1'b0;
                                        end
                                    end
                                end
                                for (p2_idx = 0; p2_idx < m; p2_idx = p2_idx + 1) begin
                                    if (p2_shared[p2_idx] != 4'd0) begin
                                        if (p2_candidate == 4'd0) begin
                                            p2_candidate = p2_shared[p2_idx];
                                        end else if (p2_candidate != p2_shared[p2_idx]) begin
                                            p2_consistent = 1'b0;
                                        end
                                    end
                                end
                                if (p1_consistent && p2_consistent && p1_candidate == p2_candidate) begin
                                    result <= 4'd0;
                                    candidate_valid <= 1'b1;
                                end
                            end
                        end
                        if (!candidate_valid) begin
                            result <= 4'b1111; // -1
                        end
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule