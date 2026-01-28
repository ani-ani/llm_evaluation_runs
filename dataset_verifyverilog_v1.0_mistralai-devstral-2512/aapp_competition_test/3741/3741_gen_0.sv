module ShortestCycleFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] data_in,
    input wire wr_en,
    input wire [3:0] num_nodes,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_BITS = 4'd1;
    localparam [3:0] BUILD_GRAPH = 4'd2;
    localparam [3:0] BFS_LOOP = 4'd3;
    localparam [3:0] UPDATE_MIN = 4'd4;
    localparam [3:0] FINISH = 4'd5;

    // Storage for node values
    reg [63:0] vals [0:15];
    reg [3:0] write_index;

    // FSM state
    reg [3:0] state;

    // BFS variables
    reg [3:0] src_node;
    reg [3:0] current_node;
    reg [3:0] neighbor;
    reg [3:0] queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] dist [0:15];
    reg [3:0] parent [0:15];
    reg [15:0] min_cycle;
    reg [3:0] i, j, k;

    // Bit check variables
    reg [5:0] bit;
    reg [3:0] bit_count [0:63];
    reg bit_check_done;

    // Graph adjacency
    reg edge [0:15][0:15];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            write_index <= 4'd0;
            done <= 1'b0;
            result <= 16'd0;
            min_cycle <= 16'd65535;
            bit_check_done <= 1'b0;
            src_node <= 4'd0;
            current_node <= 4'd0;
            neighbor <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            bit <= 6'd0;

            // Reset arrays
            for (i = 0; i < 16; i = i + 1) begin
                vals[i] <= 64'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    edge[i][j] <= 1'b0;
                end
                dist[i] <= 4'd15;
                parent[i] <= 4'd0;
                queue[i] <= 4'd0;
            end

            // Reset bit count
            for (i = 0; i < 64; i = i + 1) begin
                bit_count[i] <= 4'd0;
            end
        end else begin
            // Write data to array
            if (wr_en && write_index < num_nodes) begin
                vals[write_index] <= data_in;
                write_index <= write_index + 4'd1;
            end

            // State machine
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CHECK_BITS;
                        bit_check_done <= 1'b0;
                        bit <= 6'd0;
                        min_cycle <= 16'd65535;
                    end
                end

                CHECK_BITS: begin
                    if (!bit_check_done) begin
                        // Count nodes with each bit set
                        if (bit == 6'd0) begin
                            for (i = 0; i < 64; i = i + 1) begin
                                bit_count[i] <= 4'd0;
                            end
                        end

                        // Count current bit
                        for (i = 0; i < num_nodes; i = i + 1) begin
                            if (vals[i][bit]) begin
                                bit_count[bit] <= bit_count[bit] + 4'd1;
                            end
                        end

                        // Check if any bit is set in 3+ nodes
                        if (bit_count[bit] >= 4'd3) begin
                            min_cycle <= 16'd3;
                            bit_check_done <= 1'b1;
                        end

                        // Move to next bit
                        if (bit == 6'd63) begin
                            bit_check_done <= 1'b1;
                        end else begin
                            bit <= bit + 6'd1;
                        end
                    end else begin
                        if (min_cycle == 16'd3) begin
                            state <= FINISH;
                        end else begin
                            state <= BUILD_GRAPH;
                            i <= 4'd0;
                            j <= 4'd0;
                        end
                    end
                end

                BUILD_GRAPH: begin
                    // Build adjacency matrix
                    if (i < num_nodes) begin
                        if (j < num_nodes) begin
                            if (i != j && (vals[i] & vals[j]) != 64'd0) begin
                                edge[i][j] <= 1'b1;
                            end else begin
                                edge[i][j] <= 1'b0;
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        state <= BFS_LOOP;
                        src_node <= 4'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end

                BFS_LOOP: begin
                    // Initialize BFS for current source
                    if (i == 4'd0) begin
                        // Reset distance and parent arrays
                        for (j = 0; j < 16; j = j + 1) begin
                            dist[j] <= 4'd15;
                            parent[j] <= 4'd0;
                        end
                        // Reset queue
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        // Set source distance
                        dist[src_node] <= 4'd0;
                        queue[queue_tail] <= src_node;
                        queue_tail <= queue_tail + 4'd1;
                        i <= 4'd1;
                    end

                    // Process queue
                    if (queue_head < queue_tail) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;

                        // Check all neighbors
                        if (j < num_nodes) begin
                            if (edge[current_node][j] && dist[j] == 4'd15) begin
                                dist[j] <= dist[current_node] + 4'd1;
                                parent[j] <= current_node;
                                queue[queue_tail] <= j;
                                queue_tail <= queue_tail + 4'd1;
                            end else if (edge[current_node][j] && parent[current_node] != j && dist[j] != 4'd15) begin
                                // Cycle found
                                if (dist[current_node] + dist[j] + 4'd1 < min_cycle) begin
                                    min_cycle <= dist[current_node] + dist[j] + 4'd1;
                                end
                            end
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                        end
                    end else begin
                        // Move to next source
                        if (src_node < num_nodes - 4'd1) begin
                            src_node <= src_node + 4'd1;
                            i <= 4'd0;
                            j <= 4'd0;
                        end else begin
                            state <= UPDATE_MIN;
                        end
                    end
                end

                UPDATE_MIN: begin
                    if (min_cycle == 16'd65535) begin
                        result <= 16'd65535;
                    end else begin
                        result <= min_cycle;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule