module CityDistanceModule(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    input wire [3:0] k_in,
    input wire city_valid,
    input wire [31:0] city_x,
    input wire [31:0] city_y,
    input wire [15:0] city_pop,
    output reg result_valid,
    output reg [31:0] result_dist_sq,
    output reg busy
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_CITY = 4'd1;
    localparam [3:0] GEN_EDGES = 4'd2;
    localparam [3:0] SORT_EDGES = 4'd3;
    localparam [3:0] CHECK_CONDITION = 4'd4;
    localparam [3:0] DONE = 4'd5;

    reg [3:0] state;
    reg [3:0] next_state;

    // City data storage (16 cities max)
    reg [31:0] city_x_mem [0:15];
    reg [31:0] city_y_mem [0:15];
    reg [15:0] city_pop_mem [0:15];
    reg [3:0] city_count;
    reg [3:0] city_index;

    // Edge data (120 edges max for 16 cities)
    reg [31:0] edge_dist_sq [0:119];
    reg [3:0] edge_u [0:119];
    reg [3:0] edge_v [0:119];
    reg [6:0] edge_count;
    reg [6:0] edge_index;

    // DSU data
    reg [3:0] parent [0:15];
    reg [3:0] rank [0:15];

    // Remainder sets (16-bit bitmask per component)
    reg [15:0] remainder_set [0:15];

    // K value
    reg [3:0] k_val;

    // Temporary variables
    reg [31:0] temp_dist_sq;
    reg [3:0] temp_u, temp_v;
    reg [3:0] i, j, k;
    reg [3:0] root_u, root_v;
    reg [15:0] temp_remainder_set;
    reg found;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_valid <= 1'b0;
            result_dist_sq <= 32'd0;
            busy <= 1'b0;
            city_count <= 4'd0;
            city_index <= 4'd0;
            edge_count <= 7'd0;
            edge_index <= 7'd0;
            k_val <= 4'd0;
            temp_dist_sq <= 32'd0;
            temp_u <= 4'd0;
            temp_v <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            root_u <= 4'd0;
            root_v <= 4'd0;
            temp_remainder_set <= 16'd0;
            found <= 1'b0;

            // Initialize city memory
            for (i = 0; i < 16; i = i + 1) begin
                city_x_mem[i] <= 32'd0;
                city_y_mem[i] <= 32'd0;
                city_pop_mem[i] <= 16'd0;
            end

            // Initialize edge memory
            for (i = 0; i < 120; i = i + 1) begin
                edge_dist_sq[i] <= 32'd0;
                edge_u[i] <= 4'd0;
                edge_v[i] <= 4'd0;
            end

            // Initialize DSU
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 4'd0;
            end

            // Initialize remainder sets
            for (i = 0; i < 16; i = i + 1) begin
                remainder_set[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                busy = 1'b0;
                result_valid = 1'b0;
                if (start) begin
                    next_state = LOAD_CITY;
                    busy = 1'b1;
                    city_count = n_in;
                    k_val = k_in;
                    city_index = 4'd0;
                end
            end

            LOAD_CITY: begin
                if (city_valid) begin
                    city_x_mem[city_index] = city_x;
                    city_y_mem[city_index] = city_y;
                    city_pop_mem[city_index] = city_pop;
                    city_index = city_index + 4'd1;
                    if (city_index == city_count) begin
                        next_state = GEN_EDGES;
                        edge_count = 7'd0;
                        i = 4'd0;
                        j = 4'd1;
                    end
                end
            end

            GEN_EDGES: begin
                if (i < city_count) begin
                    if (j < city_count) begin
                        // Calculate squared distance
                        temp_dist_sq = (city_x_mem[i] - city_x_mem[j]) * (city_x_mem[i] - city_x_mem[j]) +
                                      (city_y_mem[i] - city_y_mem[j]) * (city_y_mem[i] - city_y_mem[j]);
                        edge_dist_sq[edge_count] = temp_dist_sq;
                        edge_u[edge_count] = i;
                        edge_v[edge_count] = j;
                        edge_count = edge_count + 7'd1;
                        j = j + 4'd1;
                    end else begin
                        i = i + 4'd1;
                        j = i + 4'd1;
                    end
                end else begin
                    next_state = SORT_EDGES;
                    i = 4'd0;
                    j = 4'd0;
                end
            end

            SORT_EDGES: begin
                // Bubble sort for small dataset
                if (i < edge_count) begin
                    if (j < edge_count - i - 7'd1) begin
                        if (edge_dist_sq[j] > edge_dist_sq[j + 7'd1]) begin
                            // Swap edges
                            temp_dist_sq = edge_dist_sq[j];
                            edge_dist_sq[j] = edge_dist_sq[j + 7'd1];
                            edge_dist_sq[j + 7'd1] = temp_dist_sq;
                            
                            temp_u = edge_u[j];
                            edge_u[j] = edge_u[j + 7'd1];
                            edge_u[j + 7'd1] = temp_u;
                            
                            temp_v = edge_v[j];
                            edge_v[j] = edge_v[j + 7'd1];
                            edge_v[j + 7'd1] = temp_v;
                        end
                        j = j + 4'd1;
                    end else begin
                        i = i + 4'd1;
                        j = 4'd0;
                    end
                end else begin
                    next_state = CHECK_CONDITION;
                    edge_index = 7'd0;
                    
                    // Initialize remainder sets for each city
                    for (i = 0; i < city_count; i = i + 1) begin
                        remainder_set[i] = 16'd0;
                        remainder_set[i][city_pop_mem[i] % k_val] = 1'b1;
                    end
                end
            end

            CHECK_CONDITION: begin
                if (edge_index < edge_count) begin
                    // Get current edge
                    temp_u = edge_u[edge_index];
                    temp_v = edge_v[edge_index];
                    
                    // Find roots
                    root_u = temp_u;
                    while (parent[root_u] != root_u) begin
                        root_u = parent[root_u];
                    end
                    
                    root_v = temp_v;
                    while (parent[root_v] != root_v) begin
                        root_v = parent[root_v];
                    end
                    
                    // Union if different components
                    if (root_u != root_v) begin
                        // Merge remainder sets
                        temp_remainder_set = 16'd0;
                        for (i = 0; i < k_val; i = i + 1) begin
                            if (remainder_set[root_u][i]) begin
                                for (j = 0; j < k_val; j = j + 1) begin
                                    if (remainder_set[root_v][j]) begin
                                        temp_remainder_set[(i + j) % k_val] = 1'b1;
                                    end
                                end
                            end
                        end
                        
                        // Check if remainder 0 is possible
                        if (temp_remainder_set[0]) begin
                            found = 1'b1;
                        end
                        
                        // Update remainder set for new root
                        remainder_set[root_u] = temp_remainder_set;
                        
                        // Union by rank
                        if (rank[root_u] < rank[root_v]) begin
                            parent[root_u] = root_v;
                            remainder_set[root_v] = temp_remainder_set;
                        end else if (rank[root_u] > rank[root_v]) begin
                            parent[root_v] = root_u;
                        end else begin
                            parent[root_v] = root_u;
                            rank[root_u] = rank[root_u] + 4'd1;
                        end
                    end
                    
                    // Check if condition is met
                    if (found) begin
                        result_dist_sq = edge_dist_sq[edge_index];
                        next_state = DONE;
                    end else begin
                        edge_index = edge_index + 7'd1;
                    end
                end else begin
                    // No solution found, output max distance
                    result_dist_sq = edge_dist_sq[edge_count - 7'd1];
                    next_state = DONE;
                end
            end

            DONE: begin
                result_valid = 1'b1;
                next_state = IDLE;
                busy = 1'b0;
            end

            default: begin
                next_state = IDLE;
                busy = 1'b0;
            end
        endcase
    end

endmodule