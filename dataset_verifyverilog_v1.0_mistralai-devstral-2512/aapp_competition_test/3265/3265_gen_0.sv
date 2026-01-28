module MarkovChainSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [15:0] L,
    input wire [7:0] transitions [0:7][0:7],
    output reg done,
    output reg result_valid,
    output reg [15:0] T_out
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] NORMALIZE = 2'd1;
    localparam [1:0] ITERATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    // Transition matrix and state vector
    reg signed [31:0] transition_matrix [0:7][0:7];
    reg signed [31:0] state_vector [0:7];
    reg signed [31:0] next_state_vector [0:7];

    // Iteration variables
    reg [15:0] current_t;
    reg [2:0] i, j, k;
    reg [31:0] sum, temp, product;
    reg [31:0] target_probability;
    reg found;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 16'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            T_out <= 16'd0;
            current_t <= 16'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            sum <= 32'd0;
            temp <= 32'd0;
            product <= 32'd0;
            found <= 1'b0;
            target_probability <= 32'd62259;

            // Initialize transition matrix and state vectors
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    transition_matrix[i][j] <= 32'd0;
                end
                state_vector[i] <= 32'd0;
                next_state_vector[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            if (cycle_count >= MAX_CYCLES) begin
                next_state <= DONE_STATE;
            end
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                result_valid <= 1'b0;
                T_out <= 16'd0;
                if (start) begin
                    next_state = NORMALIZE;
                    cycle_count = 16'd0;
                    i = 3'd0;
                    j = 3'd0;
                    k = 3'd0;
                    sum = 32'd0;
                    temp = 32'd0;
                    product = 32'd0;
                    found = 1'b0;
                    current_t = L;

                    // Initialize state vector
                    for (i = 0; i < 8; i = i + 1) begin
                        state_vector[i] = 32'd0;
                    end
                    state_vector[0] = 32'd65536;
                end else begin
                    next_state = IDLE;
                end
            end

            NORMALIZE: begin
                if (i < 8) begin
                    if (j < 8) begin
                        // Compute sum of outgoing edges for row i
                        if (j == 0) begin
                            sum = 32'd0;
                            for (k = 0; k < 8; k = k + 1) begin
                                sum = sum + transitions[i][k];
                            end
                        end

                        // Compute probability = (edges[i][j] * 65536) / sum
                        if (sum != 0) begin
                            temp = transitions[i][j] * 32'd65536;
                            transition_matrix[i][j] = temp / sum;
                        end else begin
                            transition_matrix[i][j] = 32'd0;
                        end

                        j = j + 3'd1;
                    end else begin
                        j = 3'd0;
                        i = i + 3'd1;
                    end
                end else begin
                    i = 3'd0;
                    j = 3'd0;
                    next_state = ITERATE;
                end
            end

            ITERATE: begin
                if (current_t <= L + 10 && !found) begin
                    if (i < 8) begin
                        if (j < 8) begin
                            // Multiply state vector by transition matrix
                            product = state_vector[j] * transition_matrix[j][i];
                            temp = temp + product;
                            j = j + 3'd1;
                        end else begin
                            next_state_vector[i] = temp[47:16];
                            j = 3'd0;
                            temp = 32'd0;
                            i = i + 3'd1;
                        end
                    end else begin
                        // Check if probability at node N matches target
                        if (next_state_vector[N - 1] == target_probability) begin
                            T_out = current_t;
                            result_valid = 1'b1;
                            found = 1'b1;
                        end

                        // Copy next_state_vector to state_vector
                        for (i = 0; i < 8; i = i + 1) begin
                            state_vector[i] = next_state_vector[i];
                        end

                        i = 3'd0;
                        j = 3'd0;
                        current_t = current_t + 16'd1;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                done <= 1'b0;
                result_valid <= 1'b0;
                T_out <= 16'd0;
            end
        endcase
    end

endmodule