module StreamerCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_LEN = 4'd16;
    localparam [3:0] MIN_LEN = 4'd2;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_ADJ = 3'd1;
    localparam [2:0] COUNT_TREES = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [3:0] current_len;
    reg [7:0] arr_reg [0:15];
    reg [15:0] adj_matrix [0:15];
    reg [15:0] edge_mask;
    reg [3:0] edge_count;
    reg [31:0] tree_count;
    reg [3:0] i, j, k, l;
    reg [31:0] gcd_temp;
    reg [31:0] temp_result;

    // GCD function
    function [31:0] gcd;
        input [31:0] a, b;
        reg [31:0] x, y, t;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                t = y;
                y = x % y;
                x = t;
            end
            gcd = x;
        end
    endfunction

    // Check if graph is connected
    function [1:0] is_connected;
        input [15:0] edges [0:15];
        input [3:0] n;
        reg [15:0] visited;
        reg [3:0] stack [0:15];
        reg [3:0] sp;
        reg [3:0] current, neighbor;
        begin
            visited = 16'd0;
            sp = 0;
            stack[0] = 0;
            visited[0] = 1'b1;

            while (sp >= 0) begin
                current = stack[sp];
                sp = sp - 1;

                for (neighbor = 0; neighbor < n; neighbor = neighbor + 1) begin
                    if (edges[current][neighbor] && !visited[neighbor]) begin
                        visited[neighbor] = 1'b1;
                        sp = sp + 1;
                        stack[sp] = neighbor;
                    end
                end
            end

            for (current = 0; current < n; current = current + 1) begin
                if (!visited[current]) begin
                    is_connected = 2'd0;
                    return;
                end
            end

            is_connected = 2'd1;
        end
    endfunction

    // Check if edges cross
    function [1:0] edges_cross;
        input [3:0] i, j, k, l;
        begin
            if ((i < k) && (k < j) && (j < l)) begin
                edges_cross = 2'd1;
            end else if ((k < i) && (i < l) && (l < j)) begin
                edges_cross = 2'd1;
            end else begin
                edges_cross = 2'd0;
            end
        end
    endfunction

    // Check if edge mask is valid
    function [1:0] is_valid_tree;
        input [15:0] edges [0:15];
        input [15:0] mask;
        input [3:0] n;
        reg [3:0] count;
        reg [3:0] x, y;
        begin
            count = 0;
            for (x = 0; x < n; x = x + 1) begin
                for (y = x + 1; y < n; y = y + 1) begin
                    if (edges[x][y] && mask[y * n + x]) begin
                        count = count + 1;
                    end
                end
            end

            if (count != n - 1) begin
                is_valid_tree = 2'd0;
                return;
            end

            if (!is_connected(edges, n)) begin
                is_valid_tree = 2'd0;
                return;
            end

            for (x = 0; x < n; x = x + 1) begin
                for (y = x + 1; y < n; y = y + 1) begin
                    if (edges[x][y] && mask[y * n + x]) begin
                        for (k = 0; k < n; k = k + 1) begin
                            for (l = k + 1; l < n; l = l + 1) begin
                                if (edges[k][l] && mask[l * n + k] && edges_cross(x, y, k, l)) begin
                                    is_valid_tree = 2'd0;
                                    return;
                                end
                            end
                        end
                    end
                end
            end

            is_valid_tree = 2'd1;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_len <= 4'd0;
            tree_count <= 32'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            l <= 4'd0;
            edge_mask <= 16'd0;
            edge_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_ADJ;
                end
            end

            COMPUTE_ADJ: begin
                if (cycle_count == 8'd0) begin
                    current_len = len;
                    for (i = 0; i < 16; i = i + 1) begin
                        arr_reg[i] = arr[i];
                    end
                end

                if (i < current_len) begin
                    if (j < current_len) begin
                        if (i != j) begin
                            gcd_temp = gcd(arr_reg[i], arr_reg[j]);
                            adj_matrix[i][j] = (gcd_temp > 1) ? 1'b1 : 1'b0;
                        end
                        j = j + 1;
                    end else begin
                        j = 0;
                        i = i + 1;
                    end
                end else begin
                    i = 0;
                    j = 0;
                    next_state = COUNT_TREES;
                end
            end

            COUNT_TREES: begin
                if (edge_mask == 16'd0) begin
                    tree_count = 0;
                end

                if (edge_count < current_len - 1) begin
                    if (edge_mask[15:0] == 16'd0) begin
                        edge_mask = 16'd1 << (current_len * (current_len - 1) / 2 - 1);
                    end else begin
                        edge_mask = edge_mask >> 1;
                    end

                    if (edge_mask[0]) begin
                        edge_count = edge_count + 1;
                    end
                end else begin
                    if (is_valid_tree(adj_matrix, edge_mask, current_len)) begin
                        tree_count = (tree_count + 1) % MOD;
                    end

                    edge_count = 0;
                    edge_mask = edge_mask >> 1;

                    if (edge_mask == 16'd0) begin
                        next_state = FINISH;
                    end
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Cycle counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: cycle_count <= 8'd0;
                COMPUTE_ADJ: cycle_count <= cycle_count + 8'd1;
                COUNT_TREES: cycle_count <= cycle_count + 8'd1;
                FINISH: cycle_count <= 8'd0;
                default: cycle_count <= 8'd0;
            endcase
        end
    end

    // Result and done
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            if (state == FINISH) begin
                result <= tree_count;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule