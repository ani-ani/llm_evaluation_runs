module ginger_candies #(
    parameter MAX_N = 8,
    parameter MAX_M = 16,
    parameter C_WIDTH = 16,
    parameter RESULT_WIDTH = 32,
    parameter ALPHA_WIDTH = 5
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] M,
    input wire [2:0] u [0:MAX_M-1],
    input wire [2:0] v [0:MAX_M-1],
    input wire [C_WIDTH-1:0] c [0:MAX_M-1],
    input wire [MAX_M-1:0] valid_edge,
    input wire [ALPHA_WIDTH-1:0] alpha,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] LOAD        = 4'd1;
    localparam [3:0] ENUM_INIT   = 4'd2;
    localparam [3:0] ENUM_CHECK  = 4'd3;
    localparam [3:0] CONN_CHECK  = 4'd4;
    localparam [3:0] CALC_COST   = 4'd5;
    localparam [3:0] UPDATE_MIN  = 4'd6;
    localparam [3:0] ENUM_NEXT   = 4'd7;
    localparam [3:0] DONE        = 4'd8;

    reg [3:0] state, next_state;

    // Control registers
    reg [3:0] m_reg;
    reg [MAX_M-1:0] subset_reg;
    reg [MAX_M-1:0] valid_edge_reg;
    reg [ALPHA_WIDTH-1:0] alpha_reg;
    reg [RESULT_WIDTH-1:0] min_cost;
    reg [RESULT_WIDTH-1:0] cost;

    // Computation registers
    reg [2:0] u_reg [0:MAX_M-1];
    reg [2:0] v_reg [0:MAX_M-1];
    reg [C_WIDTH-1:0] c_reg [0:MAX_M-1];
    reg [3:0] vertex_deg [0:MAX_N-1];
    reg [C_WIDTH-1:0] max_candy;
    reg [4:0] edge_count;
    reg [MAX_N-1:0] visited;
    reg [2:0] queue [0:MAX_N-1];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] edge_idx;
    reg [2:0] start_vertex;
    reg [2:0] current_vertex;
    reg connectivity_ok;
    reg all_even;
    reg edge_count_positive;
    reg has_valid_subset;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Temporary wires for arithmetic
    wire [31:0] candy_sq;
    wire [31:0] alpha_mult_k;
    wire [31:0] total_cost;
    wire [31:0] current_min;

    assign candy_sq = {16'd0, max_candy} * {16'd0, max_candy};
    assign alpha_mult_k = alpha_reg * edge_count;
    assign total_cost = candy_sq + alpha_mult_k;
    assign current_min = min_cost;

    // Integer for loops
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'hFFFFFFFF;
            done <= 1'b0;
            subset_reg <= 0;
            min_cost <= 32'hFFFFFFFF;
            cost <= 32'd0;
            m_reg <= 4'd0;
            edge_idx <= 4'd0;
            cycle_counter <= 8'd0;
            has_valid_subset <= 1'b0;
            for (i = 0; i < MAX_M; i = i + 1) begin
                u_reg[i] <= 3'd0;
                v_reg[i] <= 3'd0;
                c_reg[i] <= 16'd0;
            end
            valid_edge_reg <= 0;
            alpha_reg <= 0;
            for (i = 0; i < MAX_N; i = i + 1) begin
                vertex_deg[i] <= 4'd0;
                visited[i] <= 1'b0;
                queue[i] <= 3'd0;
            end
            max_candy <= 16'd0;
            edge_count <= 5'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            current_vertex <= 3'd0;
            start_vertex <= 3'd0;
            connectivity_ok <= 1'b0;
            all_even <= 1'b0;
            edge_count_positive <= 1'b0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    has_valid_subset <= 1'b0;
                    subset_reg <= 0;
                    min_cost <= 32'hFFFFFFFF;
                    if (start) begin
                        m_reg <= M;
                        valid_edge_reg <= valid_edge;
                        alpha_reg <= alpha;
                    end
                end

                LOAD: begin
                    // Load input arrays into registers
                    for (i = 0; i < MAX_M; i = i + 1) begin
                        if (i < m_reg) begin
                            u_reg[i] <= u[i];
                            v_reg[i] <= v[i];
                            c_reg[i] <= c[i];
                        end else begin
                            u_reg[i] <= 3'd0;
                            v_reg[i] <= 3'd0;
                            c_reg[i] <= 16'd0;
                        end
                    end
                end

                ENUM_INIT: begin
                    subset_reg <= 0;
                    cycle_counter <= 8'd0;
                end

                ENUM_CHECK: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Reset computation vars
                    edge_count <= 5'd0;
                    max_candy <= 16'd0;
                    all_even <= 1'b1;
                    edge_count_positive <= 1'b0;
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        vertex_deg[i] <= 4'd0;
                    end
                end

                CONN_CHECK: begin
                    // Reset visited and queue
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    queue_head <= 4'd0;
                    queue_tail <= 4'd0;
                    connectivity_ok <= 1'b1;
                end

                CALC_COST: begin
                    if (edge_count_positive && all_even && connectivity_ok) begin
                        cost <= total_cost;
                        has_valid_subset <= 1'b1;
                    end
                end

                UPDATE_MIN: begin
                    if (edge_count_positive && all_even && connectivity_ok) begin
                        if (cost < min_cost) begin
                            min_cost <= cost;
                        end
                    end
                end

                ENUM_NEXT: begin
                    // Continue loop
                end

                DONE: begin
                    if (has_valid_subset) begin
                        result <= min_cost;
                    end else begin
                        result <= 32'hFFFFFFFF;
                    end
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational next_state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end

            LOAD: begin
                next_state = ENUM_INIT;
            end

            ENUM_INIT: begin
                if (m_reg > 4'd0) next_state = ENUM_CHECK;
                else next_state = DONE;
            end

            ENUM_CHECK: begin
                // Iterate edges in current subset
                if (edge_idx < m_reg) begin
                    if (valid_edge_reg[edge_idx] && subset_reg[edge_idx]) begin
                        // Process this edge
                        edge_count = edge_count + 5'd1;
                        if (c[edge_idx] > max_candy) max_candy = c[edge_idx];
                        vertex_deg[u[edge_idx]] = vertex_deg[u[edge_idx]] + 4'd1;
                        vertex_deg[v[edge_idx]] = vertex_deg[v[edge_idx]] + 4'd1;
                    end
                    edge_idx = edge_idx + 4'd1;
                    next_state = ENUM_CHECK;
                end else begin
                    edge_idx = 4'd0;
                    // Check degrees
                    edge_count_positive = (edge_count > 5'd0);
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        if (vertex_deg[i] > 4'd0) begin
                            if (vertex_deg[i][0] == 1'b1) begin
                                all_even = 1'b0;
                            end
                        end
                    end
                    if (edge_count_positive && all_even) begin
                        // Find start vertex for BFS
                        start_vertex = 3'd0;
                        for (i = 0; i < MAX_N; i = i + 1) begin
                            if (vertex_deg[i] > 4'd0 && start_vertex == 3'd0) begin
                                start_vertex = i[2:0];
                            end
                        end
                        next_state = CONN_CHECK;
                    end else begin
                        next_state = ENUM_NEXT;
                    end
                end
            end

            CONN_CHECK: begin
                // BFS Implementation using while loop simulation with state
                // Check if queue has items
                if (queue_head < queue_tail) begin
                    // Dequeue
                    current_vertex = queue[queue_head[2:0]];
                    queue_head = queue_head + 4'd1;
                    // Process neighbors
                    for (i = 0; i < m_reg; i = i + 1) begin
                        if (valid_edge_reg[i] && subset_reg[i]) begin
                            // Check if edge connects current_vertex
                            if (u_reg[i] == current_vertex) begin
                                if (!visited[v_reg[i]]) begin
                                    visited[v_reg[i]] = 1'b1;
                                    queue[queue_tail[2:0]] = v_reg[i];
                                    queue_tail = queue_tail + 4'd1;
                                end
                            end else if (v_reg[i] == current_vertex) begin
                                if (!visited[u_reg[i]]) begin
                                    visited[u_reg[i]] = 1'b1;
                                    queue[queue_tail[2:0]] = u_reg[i];
                                    queue_tail = queue_tail + 4'd1;
                                end
                            end
                        end
                    end
                    next_state = CONN_CHECK;
                end else begin
                    // Queue empty, check connectivity
                    if (queue_head == 4'd0 && queue_tail == 4'd0) begin
                        // No nodes visited, edge case
                        connectivity_ok = 1'b0;
                    end else begin
                        // Check all vertices with degree > 0 are visited
                        for (i = 0; i < MAX_N; i = i + 1) begin
                            if (vertex_deg[i] > 4'd0 && !visited[i]) begin
                                connectivity_ok = 1'b0;
                            end
                        end
                    end
                    next_state = CALC_COST;
                end
            end

            CALC_COST: begin
                next_state = UPDATE_MIN;
            end

            UPDATE_MIN: begin
                // Generate next subset
                if (subset_reg < ((1 << m_reg) - 1)) begin
                    subset_reg = subset_reg + 1;
                    next_state = ENUM_CHECK;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule