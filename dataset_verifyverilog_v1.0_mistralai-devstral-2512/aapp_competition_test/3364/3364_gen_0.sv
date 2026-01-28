module union_find (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire op_type,
    input wire [3:0] a,
    input wire [3:0] b,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FIND_A    = 3'd1;
    localparam [2:0] FIND_B    = 3'd2;
    localparam [2:0] COMPRESS_A = 3'd3;
    localparam [2:0] COMPRESS_B = 3'd4;
    localparam [2:0] UNION     = 3'd5;
    localparam [2:0] QUERY     = 3'd6;
    localparam [2:0] COMPLETE  = 3'd7;
    
    reg [2:0] state, next_state;
    
    // Parent array: 16 elements, 4 bits each
    reg [3:0] parent [0:15];
    
    // Temporary storage for roots
    reg [3:0] root_a, root_b;
    
    // Counters for path traversal
    reg [3:0] find_counter;
    reg [3:0] current_node;
    reg [3:0] temp_parent;
    
    // Operation cycle counter
    reg [7:0] op_counter;
    localparam [7:0] MAX_OPS = 8'd64;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            op_counter <= 8'd0;
            
            // Initialize parent array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    op_counter <= 8'd0;
                    if (start) begin
                        next_state <= FIND_A;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                FIND_A: begin
                    if (find_counter == 4'd0) begin
                        current_node <= a;
                    end
                    
                    // Find root of a
                    if (parent[current_node] == current_node) begin
                        root_a <= current_node;
                        find_counter <= 4'd0;
                        next_state <= FIND_B;
                    end else begin
                        current_node <= parent[current_node];
                        find_counter <= find_counter + 4'd1;
                        if (find_counter >= 4'd15) begin
                            root_a <= current_node;
                            find_counter <= 4'd0;
                            next_state <= FIND_B;
                        end else begin
                            next_state <= FIND_A;
                        end
                    end
                end
                
                FIND_B: begin
                    if (find_counter == 4'd0) begin
                        current_node <= b;
                    end
                    
                    // Find root of b
                    if (parent[current_node] == current_node) begin
                        root_b <= current_node;
                        find_counter <= 4'd0;
                        if (op_type == 1'b0) begin
                            next_state <= UNION;
                        end else begin
                            next_state <= QUERY;
                        end
                    end else begin
                        current_node <= parent[current_node];
                        find_counter <= find_counter + 4'd1;
                        if (find_counter >= 4'd15) begin
                            root_b <= current_node;
                            find_counter <= 4'd0;
                            if (op_type == 1'b0) begin
                                next_state <= UNION;
                            end else begin
                                next_state <= QUERY;
                            end
                        end else begin
                            next_state <= FIND_B;
                        end
                    end
                end
                
                UNION: begin
                    // Union operation: set parent of root_b to root_a
                    parent[root_b] <= root_a;
                    next_state <= COMPLETE;
                end
                
                QUERY: begin
                    // Query operation: compare roots
                    if (root_a == root_b) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    next_state <= COMPLETE;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    op_counter <= op_counter + 8'd1;
                    if (op_counter >= MAX_OPS) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Path compression logic (combinational)
    always @(*) begin
        if (state == COMPRESS_A) begin
            // Compress path for a
            if (find_counter < 4'd16) begin
                temp_parent <= parent[current_node];
                if (temp_parent != current_node && temp_parent != root_a) begin
                    parent[current_node] <= root_a;
                end
            end
        end else if (state == COMPRESS_B) begin
            // Compress path for b
            if (find_counter < 4'd16) begin
                temp_parent <= parent[current_node];
                if (temp_parent != current_node && temp_parent != root_b) begin
                    parent[current_node] <= root_b;
                end
            end
        end
    end
    
    // Path compression state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            find_counter <= 4'd0;
        end else begin
            case (state)
                FIND_A: begin
                    if (find_counter == 4'd0) begin
                        current_node <= a;
                    end
                    if (parent[current_node] != current_node) begin
                        find_counter <= find_counter + 4'd1;
                    end
                end
                FIND_B: begin
                    if (find_counter == 4'd0) begin
                        current_node <= b;
                    end
                    if (parent[current_node] != current_node) begin
                        find_counter <= find_counter + 4'd1;
                    end
                end
                COMPRESS_A: begin
                    if (find_counter < 4'd16) begin
                        find_counter <= find_counter + 4'd1;
                        if (find_counter >= 4'd16 || parent[current_node] == root_a) begin
                            find_counter <= 4'd0;
                        end
                    end
                end
                COMPRESS_B: begin
                    if (find_counter < 4'd16) begin
                        find_counter <= find_counter + 4'd1;
                        if (find_counter >= 4'd16 || parent[current_node] == root_b) begin
                            find_counter <= 4'd0;
                        end
                    end
                end
                default: find_counter <= 4'd0;
            endcase
        end
    end
    
    // Next state logic for path compression
    always @(*) begin
        next_state = state;
        case (state)
            FIND_A: begin
                if (parent[current_node] == current_node || find_counter >= 4'd15) begin
                    next_state = FIND_B;
                end
            end
            FIND_B: begin
                if (parent[current_node] == current_node || find_counter >= 4'd15) begin
                    if (op_type == 1'b0) begin
                        next_state = UNION;
                    end else begin
                        next_state = QUERY;
                    end
                end
            end
            UNION: next_state = COMPLETE;
            QUERY: next_state = COMPLETE;
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
endmodule