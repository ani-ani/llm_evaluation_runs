module ResourceClaimingSolver(
    input clk,
    input rst_n,
    input start,
    input [7:0] graph_in_data,
    input [3:0] graph_in_addr,
    input graph_in_valid,
    input [15:0] iron_mask,
    input [15:0] coal_mask,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_GRAPH = 3'd1;
    localparam [2:0] BFS = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Graph storage (16 nodes, 8 edges each)
    reg [7:0] graph_edges [0:15];
    reg [3:0] load_addr;
    reg [7:0] load_data;
    reg load_valid;
    reg [3:0] load_counter;

    // BFS variables
    reg [15:0] visited;
    reg [3:0] current_distance;
    reg [3:0] distance_ram [0:15];
    reg [3:0] bfs_counter;
    reg [3:0] node_ptr;
    reg [7:0] queue [0:15];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;

    // Result computation
    reg [3:0] min_d_iron;
    reg [3:0] min_d_coal;
    reg [3:0] scan_counter;

    // State machine
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            load_counter <= 4'd0;
            load_addr <= 4'd0;
            load_data <= 8'd0;
            load_valid <= 1'b0;
            visited <= 16'd0;
            current_distance <= 4'd0;
            bfs_counter <= 4'd0;
            node_ptr <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            for (integer i = 0; i < 16; i = i + 1) begin
                graph_edges[i] <= 8'd0;
                distance_ram[i] <= 4'd15;
                queue[i] <= 8'd0;
            end
            min_d_iron <= 4'd15;
            min_d_coal <= 4'd15;
            scan_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD_GRAPH;
                        load_counter <= 4'd0;
                        load_addr <= 4'd0;
                        load_data <= 8'd0;
                        load_valid <= 1'b0;
                    end
                end

                LOAD_GRAPH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (graph_in_valid) begin
                        if (graph_in_addr < 4'd16) begin
                            graph_edges[graph_in_addr] <= graph_in_data;
                        end
                    end
                    load_counter <= load_counter + 4'd1;
                    if (load_counter >= 4'd16 || cycle_count >= MAX_CYCLES) begin
                        state <= BFS;
                        visited <= 16'd0;
                        current_distance <= 4'd0;
                        bfs_counter <= 4'd0;
                        node_ptr <= 4'd0;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        for (integer i = 0; i < 16; i = i + 1) begin
                            distance_ram[i] <= 4'd15;
                            queue[i] <= 8'd0;
                        end
                        distance_ram[0] <= 4'd0;
                        queue[0] <= 8'd0;
                        queue_tail <= 4'd1;
                        visited[0] <= 1'b1;
                    end
                end

                BFS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (queue_head < queue_tail) begin
                        node_ptr <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        current_distance <= distance_ram[node_ptr];
                        if (current_distance < 4'd15) begin
                            for (integer i = 0; i < 8; i = i + 1) begin
                                reg [3:0] neighbor;
                                neighbor <= graph_edges[node_ptr][4*i +: 4];
                                if (neighbor < 4'd16 && !visited[neighbor]) begin
                                    visited[neighbor] <= 1'b1;
                                    distance_ram[neighbor] <= current_distance + 4'd1;
                                    queue[queue_tail] <= neighbor;
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                        end
                    end
                    bfs_counter <= bfs_counter + 4'd1;
                    if (queue_head >= queue_tail || bfs_counter >= 4'd16 || cycle_count >= MAX_CYCLES) begin
                        state <= COMPUTE;
                        min_d_iron <= 4'd15;
                        min_d_coal <= 4'd15;
                        scan_counter <= 4'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (scan_counter < 4'd16) begin
                        if (iron_mask[scan_counter] && visited[scan_counter] && distance_ram[scan_counter] < min_d_iron) begin
                            min_d_iron <= distance_ram[scan_counter];
                        end
                        if (coal_mask[scan_counter] && visited[scan_counter] && distance_ram[scan_counter] < min_d_coal) begin
                            min_d_coal <= distance_ram[scan_counter];
                        end
                        scan_counter <= scan_counter + 4'd1;
                    end
                    if (scan_counter >= 4'd16 || cycle_count >= MAX_CYCLES) begin
                        if (min_d_iron == 4'd15 || min_d_coal == 4'd15) begin
                            result <= 8'd255;
                        end else begin
                            result <= (min_d_iron + min_d_coal - 4'd1);
                        end
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule