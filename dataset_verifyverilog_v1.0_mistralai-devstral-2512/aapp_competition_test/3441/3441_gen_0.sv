module max_new_roads(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [7:0] m,
    input wire [3:0] edges_src [0:31],
    input wire [3:0] edges_dst [0:31],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] TRANSITIVE_CLOSURE = 3'd2;
    localparam [2:0] COUNT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd5000;

    // Adjacency and reachability matrices
    reg adj [0:15][0:15];
    reg reach [0:15][0:15];

    // Counters for loops
    reg [3:0] i, j, k;
    reg [3:0] edge_idx;
    reg [15:0] count;

    // Initialize matrices
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize adjacency and reachability matrices
            for (idx = 0; idx < 16; idx = idx + 1) begin
                for (idx = 0; idx < 16; idx = idx + 1) begin
                    adj[idx][idx] <= 1'b0;
                    reach[idx][idx] <= 1'b0;
                end
            end
            
            // Reset loop counters
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            edge_idx <= 4'd0;
            count <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD: begin
                if (edge_idx < m) begin
                    // Load edge into adjacency matrix
                    adj[edges_src[edge_idx]][edges_dst[edge_idx]] = 1'b1;
                    reach[edges_src[edge_idx]][edges_dst[edge_idx]] = 1'b1;
                    edge_idx = edge_idx + 4'd1;
                    next_state = LOAD;
                end else begin
                    edge_idx = 4'd0;
                    next_state = TRANSITIVE_CLOSURE;
                end
            end

            TRANSITIVE_CLOSURE: begin
                if (k < 16) begin
                    if (i < 16) begin
                        if (j < 16) begin
                            // Floyd-Warshall update
                            reach[i][j] = reach[i][j] | (reach[i][k] & reach[k][j]);
                            j = j + 4'd1;
                            next_state = TRANSITIVE_CLOSURE;
                        end else begin
                            j = 4'd0;
                            i = i + 4'd1;
                            next_state = TRANSITIVE_CLOSURE;
                        end
                    end else begin
                        i = 4'd0;
                        k = k + 4'd1;
                        next_state = TRANSITIVE_CLOSURE;
                    end
                end else begin
                    k = 4'd0;
                    i = 4'd0;
                    j = 4'd0;
                    next_state = COUNT;
                end
            end

            COUNT: begin
                if (i < n) begin
                    if (j < n) begin
                        if (i != j && adj[i][j] == 1'b0 && reach[i][j] == 1'b0) begin
                            count = count + 16'd1;
                        end
                        j = j + 4'd1;
                        next_state = COUNT;
                    end else begin
                        j = 4'd0;
                        i = i + 4'd1;
                        next_state = COUNT;
                    end
                end else begin
                    result = count;
                    done = 1'b1;
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
            end
        endcase
    end

endmodule