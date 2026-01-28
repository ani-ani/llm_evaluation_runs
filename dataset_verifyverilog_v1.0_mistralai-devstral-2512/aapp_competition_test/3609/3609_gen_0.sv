module EdgePartitionFSM(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] edge_u,
    input wire [3:0] edge_v,
    input wire edge_valid,
    output reg [7:0] result_string [0:29],
    output reg valid,
    output reg impossible
);

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_EDGES = 3'd1;
    localparam [2:0] SOLVE = 3'd2;
    localparam [2:0] DONE = 3'd3;
    localparam [2:0] FAIL = 3'd4;

    reg [2:0] state;
    reg [7:0] edge_count;
    reg [3:0] edge_buffer_u [0:29];
    reg [3:0] edge_buffer_v [0:29];
    reg [3:0] n;
    reg [3:0] i, j, k;
    reg [3:0] l_assign_count [1:16];
    reg [3:0] r_assign_count [1:16];
    reg [3:0] temp_u, temp_v;
    reg found;
    reg [7:0] result_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_count <= 8'd0;
            n <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            result_index <= 8'd0;
            cycle_count <= 8'd0;
            valid <= 1'b0;
            impossible <= 1'b0;

            // Initialize edge buffers
            for (k = 0; k < 30; k = k + 1) begin
                edge_buffer_u[k] <= 4'd0;
                edge_buffer_v[k] <= 4'd0;
            end

            // Initialize counters
            for (k = 1; k < 16; k = k + 1) begin
                l_assign_count[k] <= 4'd0;
                r_assign_count[k] <= 4'd0;
            end

            // Initialize result string
            for (k = 0; k < 30; k = k + 1) begin
                result_string[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        state <= READ_EDGES;
                        edge_count <= 8'd0;
                        n <= 4'd0;
                    end
                end

                READ_EDGES: begin
                    if (edge_valid) begin
                        edge_buffer_u[edge_count] <= edge_u;
                        edge_buffer_v[edge_count] <= edge_v;
                        edge_count <= edge_count + 8'd1;
                        if (edge_u > n) begin
                            n <= edge_u;
                        end
                        if (edge_v > n) begin
                            n <= edge_v;
                        end
                    end
                    if (edge_count >= 8'd30 || !edge_valid) begin
                        state <= SOLVE;
                        cycle_count <= 8'd0;
                    end
                end

                SOLVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FAIL;
                    end else begin
                        // Initialize counters
                        for (k = 1; k < 16; k = k + 1) begin
                            l_assign_count[k] <= 4'd0;
                            r_assign_count[k] <= 4'd0;
                        end

                        // Check degrees
                        for (i = 1; i <= n; i = i + 1) begin
                            for (j = 0; j < edge_count; j = j + 1) begin
                                if (edge_buffer_u[j] == i || edge_buffer_v[j] == i) begin
                                    if (edge_buffer_u[j] < edge_buffer_v[j]) begin
                                        if (edge_buffer_v[j] == i) begin
                                            l_assign_count[i] <= l_assign_count[i] + 4'd1;
                                        end
                                        if (edge_buffer_u[j] == i) begin
                                            r_assign_count[i] <= r_assign_count[i] + 4'd1;
                                        end
                                    end
                                end
                            end
                        end

                        // Check constraints
                        if (l_assign_count[1] != 4'd0 || r_assign_count[n] != 4'd0) begin
                            state <= FAIL;
                        end else begin
                            // Try to assign edges
                            for (i = 0; i < edge_count; i = i + 1) begin
                                temp_u <= edge_buffer_u[i];
                                temp_v <= edge_buffer_v[i];
                                if (temp_u < temp_v) begin
                                    if (l_assign_count[temp_v] < 4'd1) begin
                                        l_assign_count[temp_v] <= l_assign_count[temp_v] + 4'd1;
                                        result_string[result_index] <= 8'd76; // 'L'
                                        result_index <= result_index + 8'd1;
                                    end else if (r_assign_count[temp_u] < 4'd1) begin
                                        r_assign_count[temp_u] <= r_assign_count[temp_u] + 4'd1;
                                        result_string[result_index] <= 8'd82; // 'R'
                                        result_index <= result_index + 8'd1;
                                    end else begin
                                        state <= FAIL;
                                    end
                                end
                            end

                            // Verify all nodes have correct degrees
                            found <= 1'b1;
                            for (i = 2; i <= n; i = i + 1) begin
                                if (l_assign_count[i] != 4'd1) begin
                                    found <= 1'b0;
                                end
                            end
                            for (i = 1; i < n; i = i + 1) begin
                                if (r_assign_count[i] != 4'd1) begin
                                    found <= 1'b0;
                                end
                            end

                            if (found) begin
                                state <= DONE;
                            end else begin
                                state <= FAIL;
                            end
                        end
                    end
                end

                DONE: begin
                    valid <= 1'b1;
                    impossible <= 1'b0;
                    state <= IDLE;
                end

                FAIL: begin
                    valid <= 1'b0;
                    impossible <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule