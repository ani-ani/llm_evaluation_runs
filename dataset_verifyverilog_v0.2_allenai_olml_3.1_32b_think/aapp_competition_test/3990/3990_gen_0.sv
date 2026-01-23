module shortest_path_solver (input clk, input rst_n, input start, input [2:0] n, input [2:0] num_edges, input [23:0] edge_data, output reg [3:0] result, output reg done);
localparam N_MAX = 8;
localparam ACTUAL_N = n + 2;

reg [2:0] state;
reg [N_MAX-1:0][N_MAX-1:0] adj_rail;
reg [N_MAX-1:0] visited;
reg [2:0] queue [N_MAX-1:0];
reg [2:0] queue_count;
reg [3:0] distance;
reg use_rail;
reg [3:0] result_reg;
reg done_reg;

parameter IDLE = 3'b000;
parameter BUILD_GRAPH = 3'b001;
parameter CHECK_DIRECT = 3'b010;
parameter BFS_INIT = 3'b011;
parameter BFS_PROCESSING = 3'b100;
parameter DONE = 3'b101;

localparam TARGET = ACTUAL_N - 1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        adj_rail <= 0;
        visited <= 0;
        queue <= 0;
        queue_count <=0;
        distance <=0;
        use_rail <=0;
        result_reg <=0;
        done_reg <=0;
    end else begin
        if (state == IDLE) begin
            if (start) state <= BUILD_GRAPH;
        end else if (state == BUILD_GRAPH) begin
            if (num_edges >0) begin
                wire [2:0] u, v;
                u = (edge_data >> 21) &7;
                v = (edge_data >> 18) &7;
                u = u -1;
                v = v -1;
                if (u >=0 && u < ACTUAL_N && v >=0 && v < ACTUAL_N) begin
                    adj_rail[u][v] <=1;
                    adj_rail[v][u] <=1;
                end
            end
            if (num_edges >1) begin
                u = (edge_data >>15) &7;
                v = (edge_data >>12) &7;
                u = u -1;
                v = v -1;
                if (u >=0 && u < ACTUAL_N && v >=0 && v < ACTUAL_N) begin
                    adj_rail[u][v] <=1;
                    adj_rail[v][u] <=1;
                end
            end
            if (num_edges >2) begin
                u = (edge_data >>9) &7;
                v = (edge_data >>6) &7;
                u = u -1;
                v = v -1;
                if (u >=0 && u < ACTUAL_N && v >=0 && v < ACTUAL_N) begin
                    adj_rail[u][v] <=1;
                    adj_rail[v][u] <=1;
                end
            end
            if (num_edges >3) begin
                u = (edge_data >>3) &7;
                v = edge_data[2:0];
                u = u -1;
                v = v -1;
                if (u >=0 && u < ACTUAL_N && v >=0 && v < ACTUAL_N) begin
                    adj_rail[u][v] <=1;
                    adj_rail[v][u] <=1;
                end
            end
            state <= CHECK_DIRECT;
        end else if (state == CHECK_DIRECT) begin
            if (adj_rail[0][TARGET]) use_rail <=1;
            else use_rail <=0;
            state <= BFS_INIT;
        end else if (state == BFS_INIT) begin
            distance <=0;
            visited <=0;
            queue_count <=0;
            if (queue_count < N_MAX) begin
                queue[queue_count] <=0;
                queue_count <= queue_count +1;
            end
            visited[0] <=1;
            if (0 == TARGET) begin
                result_reg <=0;
                done_reg <=1;
                state <= DONE;
            end else begin
                state <= BFS_PROCESSING;
            end
        end else if (state == BFS_PROCESSING) begin
            if (queue_count ==0) begin
                result_reg <=15;
                done_reg <=1;
                state <= DONE;
            end
        end
    end
endmodule