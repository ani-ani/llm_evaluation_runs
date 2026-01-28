module chemical_table(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [63:0] grid,
    output reg [7:0] answer,
    output reg done
);

    // Parameters
    localparam N = 8;
    localparam M = 8;
    localparam NM = N * M;
    localparam NODES = N + M;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_DSU = 3'd1;
    localparam [2:0] PROCESS_CELLS = 3'd2;
    localparam [2:0] FIND_ROW = 3'd3;
    localparam [2:0] FIND_COL = 3'd4;
    localparam [2:0] MERGE = 3'd5;
    localparam [2:0] COUNT_COMPONENTS = 3'd6;
    localparam [2:0] DONE = 3'd7;

    // State register
    reg [2:0] state;

    // DSU arrays
    reg [3:0] parent [0:NODES-1];
    reg [1:0] rank [0:NODES-1];

    // Processing variables
    reg [5:0] current_cell;
    reg [3:0] row_node;
    reg [3:0] col_node;
    reg [3:0] row_root;
    reg [3:0] col_root;
    reg [3:0] temp_node;

    // Component counting
    reg [3:0] node_counter;
    reg [3:0] component_count;

    // Find operation helper
    reg [3:0] find_target;
    reg [3:0] find_result;
    reg [1:0] find_state;
    localparam [1:0] FIND_INIT = 2'd0;
    localparam [1:0] FIND_ITERATE = 2'd1;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            answer <= 8'd0;
            done <= 1'b0;
            current_cell <= 6'd0;
            node_counter <= 4'd0;
            component_count <= 4'd0;
            find_state <= FIND_INIT;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_DSU;
                    end
                end

                INIT_DSU: begin
                    // Initialize parent array
                    integer i;
                    for (i = 0; i < NODES; i = i + 1) begin
                        parent[i] <= i;
                        rank[i] <= 2'd0;
                    end
                    current_cell <= 6'd0;
                    state <= PROCESS_CELLS;
                end

                PROCESS_CELLS: begin
                    if (current_cell >= NM) begin
                        state <= COUNT_COMPONENTS;
                    end else begin
                        reg [3:0] i = current_cell[5:3];
                        reg [3:0] j = current_cell[2:0];
                        if (i < n && j < m && grid[current_cell]) begin
                            row_node <= i;
                            col_node <= N + j;
                            find_target <= row_node;
                            find_state <= FIND_INIT;
                            state <= FIND_ROW;
                        end else begin
                            current_cell <= current_cell + 6'd1;
                        end
                    end
                end

                FIND_ROW: begin
                    case (find_state)
                        FIND_INIT: begin
                            temp_node <= find_target;
                            find_state <= FIND_ITERATE;
                        end
                        FIND_ITERATE: begin
                            if (parent[temp_node] == temp_node) begin
                                row_root <= temp_node;
                                find_state <= FIND_INIT;
                                find_target <= col_node;
                                state <= FIND_COL;
                            end else begin
                                temp_node <= parent[temp_node];
                            end
                        end
                    endcase
                end

                FIND_COL: begin
                    case (find_state)
                        FIND_INIT: begin
                            temp_node <= find_target;
                            find_state <= FIND_ITERATE;
                        end
                        FIND_ITERATE: begin
                            if (parent[temp_node] == temp_node) begin
                                col_root <= temp_node;
                                find_state <= FIND_INIT;
                                state <= MERGE;
                            end else begin
                                temp_node <= parent[temp_node];
                            end
                        end
                    endcase
                end

                MERGE: begin
                    if (row_root != col_root) begin
                        if (rank[row_root] < rank[col_root]) begin
                            parent[row_root] <= col_root;
                        end else if (rank[row_root] > rank[col_root]) begin
                            parent[col_root] <= row_root;
                        end else begin
                            parent[col_root] <= row_root;
                            rank[row_root] <= rank[row_root] + 2'd1;
                        end
                    end
                    current_cell <= current_cell + 6'd1;
                    state <= PROCESS_CELLS;
                end

                COUNT_COMPONENTS: begin
                    if (node_counter < n + m) begin
                        reg [3:0] node;
                        if (node_counter < n) begin
                            node <= node_counter;
                        end else begin
                            node <= N + (node_counter - n);
                        end
                        if (parent[node] == node) begin
                            component_count <= component_count + 4'd1;
                        end
                        node_counter <= node_counter + 4'd1;
                    end else begin
                        if (component_count > 4'd0) begin
                            answer <= component_count - 4'd1;
                        end else begin
                            answer <= 8'd0;
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule