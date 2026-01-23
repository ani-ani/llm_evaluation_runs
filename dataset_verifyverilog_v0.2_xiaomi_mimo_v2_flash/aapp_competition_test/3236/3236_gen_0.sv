module fibonacci_tour(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] heights_0,
    input wire [15:0] heights_1,
    input wire [15:0] heights_2,
    input wire [15:0] heights_3,
    input wire [15:0] heights_4,
    input wire [15:0] heights_5,
    input wire [15:0] heights_6,
    input wire [15:0] heights_7,
    input wire [7:0] adj_matrix_0,
    input wire [7:0] adj_matrix_1,
    input wire [7:0] adj_matrix_2,
    input wire [7:0] adj_matrix_3,
    input wire [7:0] adj_matrix_4,
    input wire [7:0] adj_matrix_5,
    input wire [7:0] adj_matrix_6,
    input wire [7:0] adj_matrix_7,
    input wire [3:0] num_nodes,
    output reg [3:0] max_length,
    output reg done
);

    // States
    localparam IDLE = 3'd0;
    localparam START_NEW = 3'd1;
    localparam CHECK_FIB = 3'd2;
    localparam FIND_NEXT = 3'd3;
    localparam UPDATE_BEST = 3'd4;
    localparam DONE = 3'd5;
    
    reg [2:0] state;
    reg [3:0] start_node;
    reg [3:0] current_node;
    reg [3:0] path_len;
    reg [7:0] visited;
    reg [3:0] best_len;
    reg [3:0] search_idx;
    reg [15:0] fib_seq [0:15];
    reg [15:0] current_height;
    reg [15:0] prev_height;
    reg [15:0] prev2_height;
    
    // Combinational logic for adjacency and height lookup
    reg [7:0] current_adj;
    reg [15:0] lookup_height;
    
    always @(*) begin
        case(current_node)
            4'd0: begin current_adj = adj_matrix_0; lookup_height = heights_0; end
            4'd1: begin current_adj = adj_matrix_1; lookup_height = heights_1; end
            4'd2: begin current_adj = adj_matrix_2; lookup_height = heights_2; end
            4'd3: begin current_adj = adj_matrix_3; lookup_height = heights_3; end
            4'd4: begin current_adj = adj_matrix_4; lookup_height = heights_4; end
            4'd5: begin current_adj = adj_matrix_5; lookup_height = heights_5; end
            4'd6: begin current_adj = adj_matrix_6; lookup_height = heights_6; end
            4'd7: begin current_adj = adj_matrix_7; lookup_height = heights_7; end
            default: begin current_adj = 8'd0; lookup_height = 16'd0; end
        endcase
    end
    
    // Helper wire for neighbor check
    wire neighbor_valid;
    assign neighbor_valid = (search_idx < num_nodes) && 
                           !visited[search_idx] && 
                           current_adj[search_idx];
    
    wire [15:0] neighbor_height;
    assign neighbor_height = (search_idx == 4'd0) ? heights_0 :
                            (search_idx == 4'd1) ? heights_1 :
                            (search_idx == 4'd2) ? heights_2 :
                            (search_idx == 4'd3) ? heights_3 :
                            (search_idx == 4'd4) ? heights_4 :
                            (search_idx == 4'd5) ? heights_5 :
                            (search_idx == 4'd6) ? heights_6 :
                            heights_7;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_length <= 4'd0;
            done <= 1'b0;
            start_node <= 4'd0;
            best_len <= 4'd0;
            // Initialize Fibonacci sequence
            fib_seq[0] <= 16'd1;
            fib_seq[1] <= 16'd1;
            fib_seq[2] <= 16'd2;
            fib_seq[3] <= 16'd3;
            fib_seq[4] <= 16'd5;
            fib_seq[5] <= 16'd8;
            fib_seq[6] <= 16'd13;
            fib_seq[7] <= 16'd21;
            fib_seq[8] <= 16'd34;
            fib_seq[9] <= 16'd55;
            fib_seq[10] <= 16'd89;
            fib_seq[11] <= 16'd144;
            fib_seq[12] <= 16'd233;
            fib_seq[13] <= 16'd377;
            fib_seq[14] <= 16'd610;
            fib_seq[15] <= 16'd987;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        start_node <= 4'd0;
                        best_len <= 4'd0;
                        done <= 1'b0;
                        state <= START_NEW;
                    end
                end
                
                START_NEW: begin
                    if (start_node < num_nodes) begin
                        current_node <= start_node;
                        visited <= (8'b1 << start_node);
                        path_len <= 4'd1;
                        // Check if first node has height 1
                        if (lookup_height == 16'd1) begin
                            state <= CHECK_FIB;
                        end else begin
                            // Invalid start, move to next
                            start_node <= start_node + 4'd1;
                            state <= START_NEW;
                        end
                    end else begin
                        max_length <= best_len;
                        state <= DONE;
                    end
                end
                
                CHECK_FIB: begin
                    // Verify and extend path based on length
                    if (path_len == 4'd1) begin
                        // Need second node with height 1
                        // Try to find neighbors
                        search_idx <= 4'd0;
                        state <= FIND_NEXT;
                    end else if (path_len == 4'd2) begin
                        // Need third node with height 2
                        search_idx <= 4'd0;
                        state <= FIND_NEXT;
                    end else if (path_len >= 4'd3) begin
                        // Need next Fibonacci number
                        if (path_len < 4'd16) begin
                            search_idx <= 4'd0;
                            state <= FIND_NEXT;
                        end else begin
                            // Path is long enough, update best and continue
                            if (path_len > best_len) begin
                                best_len <= path_len;
                            end
                            start_node <= start_node + 4'd1;
                            state <= START_NEW;
                        end
                    end else begin
                        start_node <= start_node + 4'd1;
                        state <= START_NEW;
                    end
                end
                
                FIND_NEXT: begin
                    if (search_idx < num_nodes) begin
                        if (neighbor_valid) begin
                            // Check if height matches required Fibonacci number
                            if (path_len == 4'd1 && neighbor_height == 16'd1) begin
                                // Found second node
                                current_node <= search_idx;
                                visited <= visited | (8'b1 << search_idx);
                                path_len <= path_len + 4'd1;
                                state <= UPDATE_BEST;
                            end else if (path_len == 4'd2 && neighbor_height == 16'd2) begin
                                // Found third node
                                current_node <= search_idx;
                                visited <= visited | (8'b1 << search_idx);
                                path_len <= path_len + 4'd1;
                                state <= UPDATE_BEST;
                            end else if (path_len >= 4'd3 && path_len < 4'd16) begin
                                if (neighbor_height == fib_seq[path_len]) begin
                                    // Found next node in sequence
                                    current_node <= search_idx;
                                    visited <= visited | (8'b1 << search_idx);
                                    path_len <= path_len + 4'd1;
                                    state <= UPDATE_BEST;
                                end else begin
                                    search_idx <= search_idx + 4'd1;
                                end
                            end else begin
                                search_idx <= search_idx + 4'd1;
                            end
                        end else begin
                            search_idx <= search_idx + 4'd1;
                        end
                    end else begin
                        // No valid neighbor found
                        if (path_len > best_len) begin
                            best_len <= path_len;
                        end
                        start_node <= start_node + 4'd1;
                        state <= START_NEW;
                    end
                end
                
                UPDATE_BEST: begin
                    // Path extended, continue searching from new node
                    state <= CHECK_FIB;
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