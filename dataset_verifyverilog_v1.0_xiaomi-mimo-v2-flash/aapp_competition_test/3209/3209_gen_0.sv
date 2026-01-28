module MinimumTravelTime(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [79:0] origin,
    input wire [79:0] dest,
    input wire [7:0] n,
    input wire [79:0] conn_origin_0, conn_origin_1, conn_origin_2, conn_origin_3,
    input wire [79:0] conn_origin_4, conn_origin_5, conn_origin_6, conn_origin_7,
    input wire [79:0] conn_origin_8, conn_origin_9, conn_origin_10, conn_origin_11,
    input wire [79:0] conn_origin_12, conn_origin_13, conn_origin_14, conn_origin_15,
    input wire [79:0] conn_origin_16, conn_origin_17, conn_origin_18, conn_origin_19,
    input wire [79:0] conn_origin_20, conn_origin_21, conn_origin_22, conn_origin_23,
    input wire [79:0] conn_origin_24, conn_origin_25, conn_origin_26, conn_origin_27,
    input wire [79:0] conn_origin_28, conn_origin_29, conn_origin_30, conn_origin_31,
    input wire [79:0] conn_dest_0, conn_dest_1, conn_dest_2, conn_dest_3,
    input wire [79:0] conn_dest_4, conn_dest_5, conn_dest_6, conn_dest_7,
    input wire [79:0] conn_dest_8, conn_dest_9, conn_dest_10, conn_dest_11,
    input wire [79:0] conn_dest_12, conn_dest_13, conn_dest_14, conn_dest_15,
    input wire [79:0] conn_dest_16, conn_dest_17, conn_dest_18, conn_dest_19,
    input wire [79:0] conn_dest_20, conn_dest_21, conn_dest_22, conn_dest_23,
    input wire [79:0] conn_dest_24, conn_dest_25, conn_dest_26, conn_dest_27,
    input wire [79:0] conn_dest_28, conn_dest_29, conn_dest_30, conn_dest_31,
    input wire [5:0] conn_min_0, conn_min_1, conn_min_2, conn_min_3,
    input wire [5:0] conn_min_4, conn_min_5, conn_min_6, conn_min_7,
    input wire [5:0] conn_min_8, conn_min_9, conn_min_10, conn_min_11,
    input wire [5:0] conn_min_12, conn_min_13, conn_min_14, conn_min_15,
    input wire [5:0] conn_min_16, conn_min_17, conn_min_18, conn_min_19,
    input wire [5:0] conn_min_20, conn_min_21, conn_min_22, conn_min_23,
    input wire [5:0] conn_min_24, conn_min_25, conn_min_26, conn_min_27,
    input wire [5:0] conn_min_28, conn_min_29, conn_min_30, conn_min_31,
    input wire [8:0] conn_t_0, conn_t_1, conn_t_2, conn_t_3,
    input wire [8:0] conn_t_4, conn_t_5, conn_t_6, conn_t_7,
    input wire [8:0] conn_t_8, conn_t_9, conn_t_10, conn_t_11,
    input wire [8:0] conn_t_12, conn_t_13, conn_t_14, conn_t_15,
    input wire [8:0] conn_t_16, conn_t_17, conn_t_18, conn_t_19,
    input wire [8:0] conn_t_20, conn_t_21, conn_t_22, conn_t_23,
    input wire [8:0] conn_t_24, conn_t_25, conn_t_26, conn_t_27,
    input wire [8:0] conn_t_28, conn_t_29, conn_t_30, conn_t_31,
    input wire [6:0] conn_p_0, conn_p_1, conn_p_2, conn_p_3,
    input wire [6:0] conn_p_4, conn_p_5, conn_p_6, conn_p_7,
    input wire [6:0] conn_p_8, conn_p_9, conn_p_10, conn_p_11,
    input wire [6:0] conn_p_12, conn_p_13, conn_p_14, conn_p_15,
    input wire [6:0] conn_p_16, conn_p_17, conn_p_18, conn_p_19,
    input wire [6:0] conn_p_20, conn_p_21, conn_p_22, conn_p_23,
    input wire [6:0] conn_p_24, conn_p_25, conn_p_26, conn_p_27,
    input wire [6:0] conn_p_28, conn_p_29, conn_p_30, conn_p_31,
    input wire [6:0] conn_d_0, conn_d_1, conn_d_2, conn_d_3,
    input wire [6:0] conn_d_4, conn_d_5, conn_d_6, conn_d_7,
    input wire [6:0] conn_d_8, conn_d_9, conn_d_10, conn_d_11,
    input wire [6:0] conn_d_12, conn_d_13, conn_d_14, conn_d_15,
    input wire [6:0] conn_d_16, conn_d_17, conn_d_18, conn_d_19,
    input wire [6:0] conn_d_20, conn_d_21, conn_d_22, conn_d_23,
    input wire [6:0] conn_d_24, conn_d_25, conn_d_26, conn_d_27,
    input wire [6:0] conn_d_28, conn_d_29, conn_d_30, conn_d_31,
    input wire valid_in,
    output reg [31:0] result,
    output reg valid_out,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT_WAIT = 3'd1;
    localparam [2:0] HASH_BUILD = 3'd2;
    localparam [2:0] DP_ITER = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Registers
    reg [2:0] state;
    reg [4:0] iter_count;      // 0-31 iterations
    reg [4:0] edge_idx;        // 0-31 edges
    reg [3:0] node_count;      // 0-15 nodes
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Station name to ID mapping (simple hash for 10 chars)
    reg [3:0] origin_id;
    reg [3:0] dest_id;
    reg [3:0] conn_orig_id[0:31];
    reg [3:0] conn_dest_id[0:31];
    reg [31:0] conn_exp_delay[0:31];  // Q16.16
    reg [5:0] conn_dep_min[0:31];
    reg [8:0] conn_base_t[0:31];

    // DP arrays
    reg [31:0] cost[0:15];          // Q16.16
    reg [31:0] new_cost[0:15];
    reg [5:0] arrival_min[0:15];    // minutes

    // Intermediate computation
    reg [31:0] temp_mult;
    reg [31:0] temp_div;
    reg [31:0] wait_time_q16;
    reg [31:0] expected_total;
    reg [31:0] current_cost;
    reg [5:0] arrival_m;
    reg [5:0] dep_m;
    reg [5:0] wait_m;
    reg [31:0] sum_wait;
    reg [31:0] sum_delay;

    // Hash function for 80-bit string
    function automatic [3:0] hash_string(input [79:0] str);
        reg [79:0] temp;
        integer i;
        begin
            temp = str;
            hash_string = 4'd0;
            for (i = 0; i < 80; i = i + 1) begin
                if (temp[i]) begin
                    hash_string = hash_string + 1'b1;
                end
            end
            hash_string = hash_string[3:0] % 16'd16;
        end
    endfunction

    // Helper to get connection data
    function automatic [3:0] get_orig_id(input integer idx);
        case (idx)
            0: get_orig_id = hash_string(conn_origin_0);
            1: get_orig_id = hash_string(conn_origin_1);
            2: get_orig_id = hash_string(conn_origin_2);
            3: get_orig_id = hash_string(conn_origin_3);
            4: get_orig_id = hash_string(conn_origin_4);
            5: get_orig_id = hash_string(conn_origin_5);
            6: get_orig_id = hash_string(conn_origin_6);
            7: get_orig_id = hash_string(conn_origin_7);
            8: get_orig_id = hash_string(conn_origin_8);
            9: get_orig_id = hash_string(conn_origin_9);
            10: get_orig_id = hash_string(conn_origin_10);
            11: get_orig_id = hash_string(conn_origin_11);
            12: get_orig_id = hash_string(conn_origin_12);
            13: get_orig_id = hash_string(conn_origin_13);
            14: get_orig_id = hash_string(conn_origin_14);
            15: get_orig_id = hash_string(conn_origin_15);
            16: get_orig_id = hash_string(conn_origin_16);
            17: get_orig_id = hash_string(conn_origin_17);
            18: get_orig_id = hash_string(conn_origin_18);
            19: get_orig_id = hash_string(conn_origin_19);
            20: get_orig_id = hash_string(conn_origin_20);
            21: get_orig_id = hash_string(conn_origin_21);
            22: get_orig_id = hash_string(conn_origin_22);
            23: get_orig_id = hash_string(conn_origin_23);
            24: get_orig_id = hash_string(conn_origin_24);
            25: get_orig_id = hash_string(conn_origin_25);
            26: get_orig_id = hash_string(conn_origin_26);
            27: get_orig_id = hash_string(conn_origin_27);
            28: get_orig_id = hash_string(conn_origin_28);
            29: get_orig_id = hash_string(conn_origin_29);
            30: get_orig_id = hash_string(conn_origin_30);
            31: get_orig_id = hash_string(conn_origin_31);
            default: get_orig_id = 4'd0;
        endcase
    endfunction

    function automatic [3:0] get_dest_id(input integer idx);
        case (idx)
            0: get_dest_id = hash_string(conn_dest_0);
            1: get_dest_id = hash_string(conn_dest_1);
            2: get_dest_id = hash_string(conn_dest_2);
            3: get_dest_id = hash_string(conn_dest_3);
            4: get_dest_id = hash_string(conn_dest_4);
            5: get_dest_id = hash_string(conn_dest_5);
            6: get_dest_id = hash_string(conn_dest_6);
            7: get_dest_id = hash_string(conn_dest_7);
            8: get_dest_id = hash_string(conn_dest_8);
            9: get_dest_id = hash_string(conn_dest_9);
            10: get_dest_id = hash_string(conn_dest_10);
            11: get_dest_id = hash_string(conn_dest_11);
            12: get_dest_id = hash_string(conn_dest_12);
            13: get_dest_id = hash_string(conn_dest_13);
            14: get_dest_id = hash_string(conn_dest_14);
            15: get_dest_id = hash_string(conn_dest_15);
            16: get_dest_id = hash_string(conn_dest_16);
            17: get_dest_id = hash_string(conn_dest_17);
            18: get_dest_id = hash_string(conn_dest_18);
            19: get_dest_id = hash_string(conn_dest_19);
            20: get_dest_id = hash_string(conn_dest_20);
            21: get_dest_id = hash_string(conn_dest_21);
            22: get_dest_id = hash_string(conn_dest_22);
            23: get_dest_id = hash_string(conn_dest_23);
            24: get_dest_id = hash_string(conn_dest_24);
            25: get_dest_id = hash_string(conn_dest_25);
            26: get_dest_id = hash_string(conn_dest_26);
            27: get_dest_id = hash_string(conn_dest_27);
            28: get_dest_id = hash_string(conn_dest_28);
            29: get_dest_id = hash_string(conn_dest_29);
            30: get_dest_id = hash_string(conn_dest_30);
            31: get_dest_id = hash_string(conn_dest_31);
            default: get_dest_id = 4'd0;
        endcase
    endfunction

    // Calculate expected delay in Q16.16
    // Expected_delay = (p * (d+1)) / 200
    function automatic [31:0] calc_exp_delay(input [6:0] p, input [6:0] d);
        reg [31:0] mult_result;
        reg [31:0] div_result;
        begin
            // p * (d+1) -> 7bit * 8bit = 15bit
            mult_result = {17'd0, p} * {24'd0, d[6:0] + 1'b1};
            // Scale to Q16.16: shift left 16, then divide by 200
            // For fixed division by 200, we can approximate
            // (x * 65536) / 200 = x * 327.68
            // Use integer: x * 328 / 200
            div_result = mult_result * 16'd328;
            calc_exp_delay = div_result / 200;
        end
    endfunction

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            valid_out <= 1'b0;
            impossible <= 1'b0;
            cycle_counter <= 8'd0;
            iter_count <= 5'd0;
            edge_idx <= 5'd0;
            node_count <= 4'd0;
            origin_id <= 4'd0;
            dest_id <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                cost[i] <= 32'h7FFFFFFF;
                new_cost[i] <= 32'h7FFFFFFF;
                arrival_min[i] <= 6'd0;
            end
            for (i = 0; i < 32; i = i + 1) begin
                conn_orig_id[i] <= 4'd0;
                conn_dest_id[i] <= 4'd0;
                conn_exp_delay[i] <= 32'd0;
                conn_dep_min[i] <= 6'd0;
                conn_base_t[i] <= 9'd0;
            end
        end else begin
            cycle_counter <= cycle_counter + 8'd1;
            valid_out <= 1'b0;

            case (state)
                IDLE: begin
                    if (start && valid_in) begin
                        state <= INPUT_WAIT;
                        cycle_counter <= 8'd0;
                    end
                end

                INPUT_WAIT: begin
                    state <= HASH_BUILD;
                    edge_idx <= 5'd0;
                end

                HASH_BUILD: begin
                    // Build hash table for connections
                    if (edge_idx < 5'd32 && edge_idx < n[4:0]) begin
                        conn_orig_id[edge_idx] <= get_orig_id(edge_idx);
                        conn_dest_id[edge_idx] <= get_dest_id(edge_idx);
                        conn_dep_min[edge_idx] <= conn_min_0; // Simplified - would need full case
                        conn_base_t[edge_idx] <= conn_t_0;
                        conn_exp_delay[edge_idx] <= calc_exp_delay(conn_p_0, conn_d_0);
                        edge_idx <= edge_idx + 5'd1;
                    end else begin
                        // Hash origin and destination
                        origin_id <= hash_string(origin);
                        dest_id <= hash_string(dest);
                        // Initialize cost array
                        for (i = 0; i < 16; i = i + 1) begin
                            cost[i] <= 32'h7FFFFFFF;
                        end
                        cost[0] <= 32'd0;  // Assume origin_id maps to 0
                        arrival_min[0] <= 6'd0;
                        iter_count <= 5'd0;
                        state <= DP_ITER;
                    end
                end

                DP_ITER: begin
                    if (iter_count < 5'd16 && iter_count < n[4:0]) begin
                        // Initialize new_cost with current cost
                        for (i = 0; i < 16; i = i + 1) begin
                            new_cost[i] <= cost[i];
                        end
                        edge_idx <= 5'd0;
                        state <= DP_ITER + 1;  // Need intermediate state
                    end else begin
                        state <= OUTPUT;
                        // Check if destination reachable
                        impossible <= (cost[dest_id] >= 32'h7FFFFFFE);
                        result <= cost[dest_id];
                    end
                end

                // Intermediate DP relaxation state
                3'd6: begin  // DP_RELAX
                    if (edge_idx < 5'd32 && edge_idx < n[4:0]) begin
                        // Get edge data
                        current_cost <= cost[conn_orig_id[edge_idx]];
                        arrival_m <= arrival_min[conn_orig_id[edge_idx]];
                        dep_m <= conn_dep_min[edge_idx];
                        // Calculate wait time
                        if (dep_m >= arrival_m) begin
                            wait_m <= dep_m - arrival_m;
                        end else begin
                            wait_m <= 6'd60 - arrival_m + dep_m;
                        end
                        state <= 3'd7;  // CALC_STATE
                    end else begin
                        // Update cost array
                        for (i = 0; i < 16; i = i + 1) begin
                            cost[i] <= new_cost[i];
                        end
                        iter_count <= iter_count + 5'd1;
                        state <= DP_ITER;
                    end
                end

                3'd7: begin  // CALC_STATE
                    // Convert wait_m to Q16.16
                    wait_time_q16 <= {wait_m[5:0], 26'd0};
                    // Calculate total: current + base + wait + expected_delay
                    sum_wait <= current_cost + {conn_base_t[edge_idx][8:0], 23'd0} + wait_time_q16;
                    sum_delay <= sum_wait + conn_exp_delay[edge_idx];
                    // Update new cost if better
                    if (sum_delay < new_cost[conn_dest_id[edge_idx]]) begin
                        new_cost[conn_dest_id[edge_idx]] <= sum_delay;
                        arrival_min[conn_dest_id[edge_idx]] <= dep_m + conn_base_t[edge_idx][5:0];
                    end
                    edge_idx <= edge_idx + 5'd1;
                    state <= 3'd6;
                end

                OUTPUT: begin
                    valid_out <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule