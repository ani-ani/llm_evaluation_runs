module fibonacci_tour(input wire clk, input wire rst_n, input wire start, input wire [15:0] heights_0, input wire [15:0] heights_1, input wire [15:0] heights_2, input wire [15:0] heights_3, input wire [15:0] heights_4, input wire [15:0] heights_5, input wire [15:0] heights_6, input wire [15:0] heights_7, input wire [7:0] adj_matrix_0, input wire [7:0] adj_matrix_1, input wire [7:0] adj_matrix_2, input wire [7:0] adj_matrix_3, input wire [7:0] adj_matrix_4, input wire [7:0] adj_matrix_5, input wire [7:0] adj_matrix_6, input wire [7:0] adj_matrix_7, input wire [3:0] num_nodes, output reg [3:0] max_length, output reg done);

    // States
    localparam IDLE = 2'd0;
    localparam SEARCH = 2'd1;
    localparam COMPLETE = 2'd2;

    reg [1:0] state;
    reg [3:0] start_node;
    reg [3:0] current_node;
    reg [3:0] prev_node;
    reg [3:0] prev2_node;
    reg [3:0] path_length;
    reg [7:0] visited;
    reg [3:0] best_length;

    // Pre-computed Fibonacci values up to reasonable max (scaled for 16-bit heights)
    reg [15:0] fib_0;  // 1
    reg [15:0] fib_1;  // 1
    reg [15:0] fib_2;  // 2
    reg [15:0] fib_3;  // 3
    reg [15:0] fib_4;  // 5
    reg [15:0] fib_5;  // 8
    reg [15:0] fib_6;  // 13
    reg [15:0] fib_7;  // 21
    reg [15:0] fib_8;  // 34
    reg [15:0] fib_9;  // 55
    reg [15:0] fib_10; // 89
    reg [15:0] fib_11; // 144
    reg [15:0] fib_12; // 233
    reg [15:0] fib_13; // 377
    reg [15:0] fib_14; // 610
    reg [15:0] fib_15; // 987
    reg [15:0] fib_16; // 1597

    wire [15:0] get_height;
    wire [7:0] get_adj;

    // Combinational lookup for heights
    assign get_height = (current_node == 4'd0) ? heights_0 : (current_node == 4'd1) ? heights_1 : (current_node == 4'd2) ? heights_2 : (current_node == 4'd3) ? heights_3 : (current_node == 4'd4) ? heights_4 : (current_node == 4'd5) ? heights_5 : (current_node == 4'd6) ? heights_6 : heights_7;

    // Combinational lookup for adjacency
    assign get_adj = (current_node == 4'd0) ? adj_matrix_0 : (current_node == 4'd1) ? adj_matrix_1 : (current_node == 4'd2) ? adj_matrix_2 : (current_node == 4'd3) ? adj_matrix_3 : (current_node == 4'd4) ? adj_matrix_4 : (current_node == 4'd5) ? adj_matrix_5 : (current_node == 4'd6) ? adj_matrix_6 : adj_matrix_7;

    integer i;
    reg [3:0] next_node;
    reg [7:0] neighbors;
    reg found_next;
    reg [15:0] target_fib;
    reg [15:0] prev_height;
    reg [15:0] prev2_height;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_length <= 4'd0;
            done <= 1'b0;
            start_node <= 4'd0;
            fib_0 <= 16'd1;
            fib_1 <= 16'd1;
            fib_2 <= 16'd2;
            fib_3 <= 16'd3;
            fib_4 <= 16'd5;
            fib_5 <= 16'd8;
            fib_6 <= 16'd13;
            fib_7 <= 16'd21;
            fib_8 <= 16'd34;
            fib_9 <= 16'd55;
            fib_10 <= 16'd89;
            fib_11 <= 16'd144;
            fib_12 <= 16'd233;
            fib_13 <= 16'd377;
            fib_14 <= 16'd610;
            fib_15 <= 16'd987;
            fib_16 <= 16'd1597;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SEARCH;
                        start_node <= 4'd0;
                        best_length <= 4'd0;
                        done <= 1'b0;
                    end
                end

                SEARCH: begin
                    if (start_node < num_nodes) begin
                        // Initialize for new starting node
                        current_node <= start_node;
                        prev_node <= 4'hF;  // Invalid marker
                        prev2_node <= 4'hF;
                        visited <= (8'b1 << start_node);
                        path_length <= 4'd1;
                        state <= COMPLETE;  // Will process this start node
                    end else begin
                        max_length <= best_length;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                COMPLETE: begin
                    // Check if current path can be extended
                    if (path_length == 4'd1) begin
                        // First node: height must match fib_0 or fib_1 (both are 1)
                        if (get_height == 16'd1) begin
                            // Try to extend with fib_2 = 2
                            neighbors <= get_adj;
                            next_node <= 4'd0;
                            found_next <= 1'b0;
                            state <= (num_nodes > 4'd1) ? SEARCH : COMPLETE;
                        end else begin
                            // Single node path (not part of Fibonacci sequence)
                            if (path_length > best_length && get_height == 16'd1) begin
                                best_length <= path_length;
                            end
                            start_node <= start_node + 4'd1;
                            state <= SEARCH;
                        end
                    end else if (path_length == 4'd2) begin
                        // Second node: height must be 1 (fib_1)
                        if (get_height == 16'd1) begin
                            // Try to extend with fib_3 = 3
                            neighbors <= get_adj;
                            next_node <= 4'd0;
                            found_next <= 1'b0;
                            state <= SEARCH;
                        end else begin
                            if (path_length > best_length) begin
                                best_length <= path_length;
                            end
                            start_node <= start_node + 4'd1;
                            state <= SEARCH;
                        end
                    end else begin
                        // General case: check Fibonacci continuation
                        // Need heights to form consecutive Fibonacci numbers
                        // Simplified: assume path follows 1,1,2,3,5,... or 1,2,3,5,...
                        // Just check if next node can extend sequence

                        if (path_length > best_length) begin
                            best_length <= path_length;
                        end

                        // Try to find next valid node
                        if (next_node < num_nodes && !found_next) begin
                            if (!(visited & (8'b1 << next_node)) && (get_adj & (8'b1 << next_node))) begin
                                // Check if next height is valid
                                if (path_length == 4'd3) begin
                                    target_fib <= fib_3;  // 3
                                end else if (path_length == 4'd4) begin
                                    target_fib <= fib_4;  // 5
                                end else if (path_length == 4'd5) begin
                                    target_fib <= fib_5;  // 8
                                end else begin
                                    target_fib <= 16'd0;
                                end

                                if (path_length >= 4'd3 && path_length <= 4'd5 && get_height == target_fib) begin
                                    // Extend path
                                    current_node <= next_node;
                                    prev2_node <= prev_node;
                                    prev_node <= current_node;
                                    visited <= visited | (8'b1 << next_node);
                                    path_length <= path_length + 4'd1;
                                    found_next <= 1'b1;
                                    state <= COMPLETE;
                                end
                            end
                            next_node <= next_node + 4'd1;
                        end else if (found_next) begin
                            // Successfully extended, continue
                            state <= COMPLETE;
                        end else begin
                            // Cannot extend further
                            start_node <= start_node + 4'd1;
                            state <= SEARCH;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule