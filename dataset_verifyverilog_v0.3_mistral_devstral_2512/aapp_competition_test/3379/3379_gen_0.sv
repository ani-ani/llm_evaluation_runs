module topological_width #(
    parameter N = 4,
    parameter GRAPH_WIDTH = N * N,
    parameter RESULT_WIDTH = 4,
    parameter CLK_PERIOD = 10
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [GRAPH_WIDTH-1:0] graph_packed,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] UNPACK = 3'd1;
    localparam [2:0] REACHABILITY = 3'd2;
    localparam [2:0] CYCLE_DETECTION = 3'd3;
    localparam [2:0] ANTICHAIN = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Adjacency matrix
    reg [N-1:0] adj [0:N-1];
    integer i, j, k;

    // Reachability matrix
    reg [N-1:0] reach [0:N-1];

    // Good nodes
    reg [N-1:0] good_nodes;
    reg [3:0] good_count;

    // Antichain computation
    reg [N-1:0] current_subset;
    reg [3:0] max_size;
    reg [3:0] current_size;
    reg [3:0] subset_index;

    // Cycle counter
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Unpack graph
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    adj[i][j] <= 1'b0;
                    reach[i][j] <= 1'b0;
                end
            end
            good_count <= 4'd0;
            max_size <= 4'd0;
            current_size <= 4'd0;
            subset_index <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= UNPACK;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                UNPACK: begin
                    // Unpack graph_packed into adj
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) begin
                            adj[i][j] <= graph_packed[i*N + j];
                        end
                    end
                    next_state <= REACHABILITY;
                end

                REACHABILITY: begin
                    // Initialize reachability matrix
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) begin
                            reach[i][j] <= adj[i][j];
                        end
                    end
                    // Floyd-Warshall algorithm
                    for (k = 0; k < N; k = k + 1) begin
                        for (i = 0; i < N; i = i + 1) begin
                            for (j = 0; j < N; j = j + 1) begin
                                reach[i][j] <= reach[i][j] || (reach[i][k] && reach[k][j]);
                            end
                        end
                    end
                    next_state <= CYCLE_DETECTION;
                end

                CYCLE_DETECTION: begin
                    // Identify good nodes
                    for (i = 0; i < N; i = i + 1) begin
                        reg cycle_flag;
                        cycle_flag = 1'b0;
                        for (j = 0; j < N; j = j + 1) begin
                            if (i != j && reach[i][j] && reach[j][i]) begin
                                cycle_flag = 1'b1;
                            end
                        end
                        good_nodes[i] <= !cycle_flag;
                    end
                    // Count good nodes
                    good_count = 4'd0;
                    for (i = 0; i < N; i = i + 1) begin
                        if (good_nodes[i]) begin
                            good_count = good_count + 4'd1;
                        end
                    end
                    if (good_count == 4'd0) begin
                        result <= 4'd0;
                        next_state <= FINISH;
                    end else begin
                        next_state <= ANTICHAIN;
                    end
                end

                ANTICHAIN: begin
                    // Brute-force antichain computation
                    if (subset_index == 4'd0) begin
                        max_size <= 4'd0;
                        current_size <= 4'd0;
                        for (i = 0; i < N; i = i + 1) begin
                            current_subset[i] <= 1'b0;
                        end
                    end
                    // Check current subset
                    reg is_antichain;
                    is_antichain = 1'b1;
                    for (i = 0; i < N; i = i + 1) begin
                        if (current_subset[i] && good_nodes[i]) begin
                            for (j = i + 1; j < N; j = j + 1) begin
                                if (current_subset[j] && good_nodes[j] && (reach[i][j] || reach[j][i])) begin
                                    is_antichain = 1'b0;
                                end
                            end
                        end
                    end
                    if (is_antichain && current_size > max_size) begin
                        max_size <= current_size;
                    end
                    // Increment subset
                    subset_index <= subset_index + 4'd1;
                    if (subset_index == (1 << N) - 1) begin
                        result <= max_size;
                        next_state <= FINISH;
                    end else begin
                        // Update current_subset
                        for (i = 0; i < N; i = i + 1) begin
                            current_subset[i] <= subset_index[i];
                        end
                        // Count bits
                        current_size = 4'd0;
                        for (i = 0; i < N; i = i + 1) begin
                            if (current_subset[i]) begin
                                current_size = current_size + 4'd1;
                            end
                        end
                        next_state <= ANTICHAIN;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule