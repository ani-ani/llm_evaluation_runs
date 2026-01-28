module joke_party_dp(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] load_addr,
    input wire [31:0] load_data,
    input wire load_valid,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALC_INIT = 3'd2;
    localparam [2:0] CALC_LOOP = 3'd3;
    localparam [2:0] FINAL_SUM = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Node values and adjacency matrix
    reg [4:0] node_val [0:15];
    reg adj [0:15][0:15];

    // DP table: dp[node][L][R]
    reg [31:0] dp [0:15][0:15][0:15];

    // Counters for FSM
    reg [3:0] current_node;
    reg [3:0] L_counter;
    reg [3:0] R_counter;
    reg [3:0] child_counter;
    reg [31:0] temp_sum;
    reg [31:0] temp_product;

    // Load phase control
    reg [3:0] load_index;
    reg load_complete;

    // Cycle counter to prevent infinite loops
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            current_node <= 4'd0;
            L_counter <= 4'd0;
            R_counter <= 4'd0;
            child_counter <= 4'd0;
            temp_sum <= 32'd0;
            temp_product <= 32'd0;
            load_index <= 4'd0;
            load_complete <= 1'b0;
            cycle_count <= 16'd0;

            // Initialize node_val and adj
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                node_val[i] <= 5'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    adj[i][j] <= 1'b0;
                end
            end

            // Initialize dp table
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    for (k = 0; k < 16; k = k + 1) begin
                        dp[i][j][k] <= 32'd0;
                    end
                end
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        load_index <= 4'd0;
                        load_complete <= 1'b0;
                    end
                end

                LOAD: begin
                    if (load_valid) begin
                        if (load_addr < 4'd16) begin
                            // Loading node value
                            node_val[load_addr] <= load_data[7:4];
                        end else begin
                            // Loading edge
                            adj[load_data[7:4]][load_data[3:0]] <= 1'b1;
                        end
                        load_index <= load_index + 4'd1;
                        if (load_index >= 4'd32) begin
                            load_complete <= 1'b1;
                        end
                    end
                    if (load_complete) begin
                        next_state <= CALC_INIT;
                        current_node <= 4'd15; // Start from last node
                    end
                end

                CALC_INIT: begin
                    // Initialize DP for leaves
                    if (current_node == 4'd0) begin
                        next_state <= CALC_LOOP;
                        current_node <= 4'd15;
                        L_counter <= 4'd0;
                        R_counter <= 4'd0;
                    end else begin
                        // Check if current_node is a leaf
                        integer j;
                        reg is_leaf;
                        is_leaf = 1'b1;
                        for (j = 0; j < 16; j = j + 1) begin
                            if (adj[current_node][j]) begin
                                is_leaf = 1'b0;
                            end
                        end
                        if (is_leaf) begin
                            // Leaf node: dp[u][v][v] = 1 if v == V[u]
                            integer v;
                            for (v = 0; v < 16; v = v + 1) begin
                                if (v == node_val[current_node]) begin
                                    dp[current_node][v][v] <= 32'd1;
                                end else begin
                                    dp[current_node][v][v] <= 32'd0;
                                end
                            end
                        end
                        current_node <= current_node - 4'd1;
                    end
                end

                CALC_LOOP: begin
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end else begin
                        // Process current_node, L_counter, R_counter
                        if (L_counter == 4'd16) begin
                            L_counter <= 4'd0;
                            R_counter <= R_counter + 4'd1;
                            if (R_counter == 4'd16) begin
                                R_counter <= 4'd0;
                                current_node <= current_node - 4'd1;
                                if (current_node == 4'd255) begin
                                    next_state <= FINAL_SUM;
                                    current_node <= 4'd0;
                                end
                            end
                        end else begin
                            // Check if V[u] is in [L, R]
                            if (node_val[current_node] >= L_counter && node_val[current_node] <= R_counter) begin
                                temp_product <= 32'd1;
                                child_counter <= 4'd0;
                                // Iterate through children
                                integer j;
                                for (j = 0; j < 16; j = j + 1) begin
                                    if (adj[current_node][j]) begin
                                        // Calculate child_ways
                                        temp_sum <= 32'd0;
                                        integer i, k;
                                        for (i = L_counter; i <= R_counter; i = i + 1) begin
                                            for (k = i; k <= R_counter; k = k + 1) begin
                                                temp_sum <= temp_sum + dp[j][i][k];
                                            end
                                        end
                                        temp_product <= temp_product * temp_sum;
                                    end
                                end
                                dp[current_node][L_counter][R_counter] <= temp_product;
                            end else begin
                                dp[current_node][L_counter][R_counter] <= 32'd0;
                            end
                            L_counter <= L_counter + 4'd1;
                        end
                    end
                end

                FINAL_SUM: begin
                    temp_sum <= 32'd0;
                    integer i, j;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = i; j < 16; j = j + 1) begin
                            temp_sum <= temp_sum + dp[0][i][j];
                        end
                    end
                    result <= temp_sum;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        next_state <= IDLE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule