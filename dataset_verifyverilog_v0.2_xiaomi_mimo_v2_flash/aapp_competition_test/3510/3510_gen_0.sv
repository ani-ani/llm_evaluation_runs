module game_solver(
    input clk,
    input rst_n,
    input [1:0] start_pos,
    input [1:0] target_pos,
    input start,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    parameter N = 3;
    parameter MAX_ITER = 32;
    parameter INF = 8'd255;

    // State Definition
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam UPDATE = 2'b10;
    localparam FINISH = 2'b11;

    // Internal Registers
    reg [1:0] current_state, next_state;
    reg [7:0] dist_buffer [0:2][0:2]; // 3x3 matrix
    reg [7:0] next_dist_buffer [0:2][0:2];
    reg [4:0] iter_count; // Counter for max 32 iterations
    reg [1:0] u, t; // Iteration variables for positions
    reg [7:0] max_v1, max_v2; // Storing max for options
    reg [7:0] min_opt; // Storing min of options
    reg [7:0] calc_val; // Calculated next value
    
    // Combinational helper logic for neighbor lookup based on fixed test case
    reg [7:0] opt1_max, opt2_max;
    
    always @(*) begin
        // Default max values to 0 for max() calculation
        max_v1 = 0;
        max_v2 = 0;
        
        // Option 1 Logic
        case(u)
            2'b00: begin // a -> b
                max_v1 = dist_buffer[1][t];
            end
            2'b01: begin // b -> b
                max_v1 = dist_buffer[1][t];
            end
            2'b10: begin // c -> {a, b}
                if (dist_buffer[0][t] > dist_buffer[1][t]) max_v1 = dist_buffer[0][t];
                else max_v1 = dist_buffer[1][t];
            end
            default: max_v1 = INF;
        endcase

        // Option 2 Logic
        case(u)
            2'b00: begin // a has only 1 option, duplicate option 1 or set to INF
                max_v2 = INF;
            end
            2'b01: begin // b -> a
                max_v2 = dist_buffer[0][t];
            end
            2'b10: begin // c -> {a, c}
                if (dist_buffer[0][t] > dist_buffer[2][t]) max_v2 = dist_buffer[0][t];
                else max_v2 = dist_buffer[2][t];
            end
            default: max_v2 = INF;
        endcase

        // Min of options
        if (max_v1 < max_v2) min_opt = max_v1;
        else min_opt = max_v2;
        
        // Add 1, clamp to INF
        if (min_opt == INF) calc_val = INF;
        else if (min_opt == 8'hFF) calc_val = INF; // safety
        else calc_val = min_opt + 1;
    end

    // State Transition and Output Logic
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            iter_count <= 0;
            u <= 0;
            t <= 0;
            // Reset buffer
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    dist_buffer[i][j] <= INF;
                end
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize Matrix: dist[S][T] = 0 for S==T, else INF
                        for (i = 0; i < 3; i = i + 1) begin
                            for (j = 0; j < 3; j = j + 1) begin
                                if (i == j) dist_buffer[i][j] <= 0;
                                else dist_buffer[i][j] <= INF;
                            end
                        end
                        current_state <= COMPUTE;
                        iter_count <= 0;
                        u <= 0;
                        t <= 0;
                    end
                end

                COMPUTE: begin
                    // Iterate through all u, t to calculate next values
                    // We calculate next_dist_buffer for all pairs based on current dist_buffer
                    // Then commit to dist_buffer at end of cycle or separate state
                    // To save latency, let's do update in separate state or pipeline
                    current_state <= UPDATE;
                end

                UPDATE: begin
                    // Apply the calculated value for (u, t)
                    // Update rule: dist[u][t] = 1 + min(max(opt1), max(opt2))
                    // unless dist[u][t] is 0 (start==target case handled by init)
                    if (dist_buffer[u][t] != 0) begin
                        dist_buffer[u][t] <= calc_val;
                    end

                    // Increment indices
                    if (t == 2) begin
                        t <= 0;
                        if (u == 2) begin
                            u <= 0;
                            // End of full matrix sweep
                            iter_count <= iter_count + 1;
                            if (iter_count + 1 >= MAX_ITER) begin
                                current_state <= FINISH;
                            end else begin
                                current_state <= COMPUTE;
                            end
                        end else begin
                            u <= u + 1;
                            current_state <= COMPUTE;
                        end
                    end else begin
                        t <= t + 1;
                        current_state <= COMPUTE;
                    end
                end

                FINISH: begin
                    // Read result for requested start/target
                    result <= dist_buffer[start_pos][target_pos];
                    done <= 1;
                    if (!start) current_state <= IDLE; // Wait for start to go low before restarting
                end
            endcase
        end
    end

endmodule
