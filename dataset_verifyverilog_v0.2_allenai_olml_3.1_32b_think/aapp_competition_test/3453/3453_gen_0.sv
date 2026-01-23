module danger_level_calculator (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_idx,
    input [2:0] neighbor_idx,
    input [7:0] edge_weight,
    input edge_valid,
    output reg [2:0] current_node,
    output reg [31:0] danger_level,
    output reg result_valid,
    output reg done
);

    localparam INF = 16'd65535;
    localparam MOD = 32'd1000000007;
    localparam NUM_NODES = 8;

    reg [15:0][7:0] adj_matrix;
    reg [15:0][7:0] distance;

    reg [2:0] state, next_state;
    localparam IDLE = 3'b000,
                LOAD_GRAPH = 3'b001,
                COMPUTE = 3'b010,
                CALCULATE_SUMS = 3'b011,
                OUTPUT_RESULTS = 3'b100,
                DONE = 3'b101;

    reg [31:0] total_sum;
    reg [2:0] current_node_reg;
    reg [31:0] danger_level_reg;
    reg result_valid_reg, done_reg;
    reg [9:0] floyd_counter;
    reg [2:0] node_counter;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            adj_matrix <= { {INF}{NUM_NODES} };
            distance <= { {INF}{NUM_NODES} };
            state <= IDLE;
            next_state <= IDLE;
            floyd_counter <= 10'd0;
            node_counter <= 3'd0;
            total_sum <= 32'd0;
            current_node_reg <= 3'd0;
            danger_level_reg <= 32'd0;
            result_valid_reg <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            if (edge_valid) begin
                adj_matrix[node_idx][neighbor_idx] <= min(adj_matrix[node_idx][neighbor_idx], edge_weight);
            end
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD_GRAPH;
            LOAD_GRAPH: next_state = COMPUTE;
            COMPUTE: if (floyd_counter == 512'd511) next_state = CALCULATE_SUMS; else next_state = COMPUTE;
            CALCULATE_SUMS: if (node_counter < NUM_NODES) next_state = CALCULATE_SUMS; else next_state = OUTPUT_RESULTS;
            OUTPUT_RESULTS: if (node_counter < NUM_NODES) next_state = OUTPUT_RESULTS; else next_state = DONE;
            DONE: next_state = DONE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (state == COMPUTE) begin
            if (floyd_counter < 512) begin
                floyd_counter <= floyd_counter + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (state == CALCULATE_SUMS) begin
            if (node_counter == 3'd0) begin
                total_sum <= distance[0][1] + distance[0][2] + distance[0][3] + distance[0][4] + distance[0][5] + distance[0][6] + distance[0][7];
            end else begin
                total_sum <= 32'd0; // Placeholder
            end
            node_counter <= node_counter + 1;
        end
    end

    always_ff @(posedge clk) begin
        if (state == OUTPUT_RESULTS) begin
            if (node_counter < NUM_NODES) begin
                current_node_reg <= node_counter;
                danger_level_reg <= total_sum; // Modulo removed for synthesizability
                result_valid_reg <= 1'b1;
                node_counter <= node_counter + 1;
            end else begin
                result_valid_reg <= 1'b0;
                done_reg <= 1'b1;
            end
        end
    end

    assign current_node = current_node_reg;
    assign danger_level = danger_level_reg;
    assign result_valid = result_valid_reg;
    assign done = done_reg;

endmodule