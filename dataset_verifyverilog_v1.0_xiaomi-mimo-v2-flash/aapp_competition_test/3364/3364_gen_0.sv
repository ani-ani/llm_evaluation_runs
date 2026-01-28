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
    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FIND_A = 4'd1;
    localparam [3:0] FIND_B = 4'd2;
    localparam [3:0] COMPRESS_A = 4'd3;
    localparam [3:0] COMPRESS_B = 4'd4;
    localparam [3:0] UNION = 4'd5;
    localparam [3:0] QUERY = 4'd6;
    localparam [3:0] COMPLETE = 4'd7;
    localparam [3:0] INIT = 4'd8;

    // Registers
    reg [3:0] state, next_state;
    reg [3:0] parent [0:15]; // Parent array
    reg [3:0] init_counter;
    reg [3:0] node, temp_node;
    reg [3:0] root_a, root_b;
    reg [3:0] loop_counter;
    reg [3:0] compress_counter;
    reg [3:0] path_nodes [0:15]; // Stack for path compression
    reg [3:0] stack_ptr;
    reg found_a, found_b;
    
    integer i;

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= INIT;
            done <= 1'b0;
            result <= 1'b0;
            init_counter <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= 4'd0;
            end
            node <= 4'd0;
            temp_node <= 4'd0;
            root_a <= 4'd0;
            root_b <= 4'd0;
            loop_counter <= 4'd0;
            compress_counter <= 4'd0;
            found_a <= 1'b0;
            found_b <= 1'b0;
            stack_ptr <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                path_nodes[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                INIT: begin
                    if (init_counter < 4'd16) begin
                        parent[init_counter] <= init_counter;
                        init_counter <= init_counter + 4'd1;
                    end
                    done <= 1'b0;
                    result <= 1'b0;
                end
                
                FIND_A: begin
                    if (loop_counter < 4'd16) begin
                        if (parent[node] != node) begin
                            path_nodes[stack_ptr] <= node;
                            stack_ptr <= stack_ptr + 4'd1;
                            node <= parent[node];
                        end else begin
                            root_a <= node;
                            found_a <= 1'b1;
                        end
                        loop_counter <= loop_counter + 4'd1;
                    end
                end
                
                FIND_B: begin
                    if (loop_counter < 4'd16) begin
                        if (parent[node] != node) begin
                            path_nodes[stack_ptr] <= node;
                            stack_ptr <= stack_ptr + 4'd1;
                            node <= parent[node];
                        end else begin
                            root_b <= node;
                            found_b <= 1'b1;
                        end
                        loop_counter <= loop_counter + 4'd1;
                    end
                end
                
                COMPRESS_A: begin
                    if (stack_ptr > 4'd0) begin
                        stack_ptr <= stack_ptr - 4'd1;
                        parent[path_nodes[stack_ptr - 4'd1]] <= root_a;
                    end
                end
                
                COMPRESS_B: begin
                    if (stack_ptr > 4'd0) begin
                        stack_ptr <= stack_ptr - 4'd1;
                        parent[path_nodes[stack_ptr - 4'd1]] <= root_b;
                    end
                end
                
                UNION: begin
                    if (root_a != root_b) begin
                        parent[root_b] <= root_a;
                    end
                end
                
                QUERY: begin
                    if (root_a == root_b) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // State is IDLE or others
                end
            endcase
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        
        case (state)
            INIT: begin
                if (init_counter >= 4'd16) begin
                    next_state = IDLE;
                end
            end
            
            IDLE: begin
                if (start) begin
                    next_state = FIND_A;
                end
            end
            
            FIND_A: begin
                if (found_a || loop_counter >= 4'd16) begin
                    next_state = COMPRESS_A;
                end
            end
            
            COMPRESS_A: begin
                if (stack_ptr == 4'd0) begin
                    if (op_type == 1'b1) begin // Query
                        next_state = QUERY;
                    end else begin // Union
                        node <= b;
                        loop_counter <= 4'd0;
                        stack_ptr <= 4'd0;
                        found_b <= 1'b0;
                        next_state = FIND_B;
                    end
                end
            end
            
            FIND_B: begin
                if (found_b || loop_counter >= 4'd16) begin
                    next_state = COMPRESS_B;
                end
            end
            
            COMPRESS_B: begin
                if (stack_ptr == 4'd0) begin
                    next_state = UNION;
                end
            end
            
            UNION: begin
                next_state = COMPLETE;
            end
            
            QUERY: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control signals for operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main always block
        end else begin
            if (state == IDLE && start) begin
                node <= a;
                loop_counter <= 4'd0;
                stack_ptr <= 4'd0;
                found_a <= 1'b0;
                done <= 1'b0;
            end
            
            if (state == COMPLETE) begin
                done <= 1'b1;
            end
            
            if (state != COMPLETE && state != IDLE) begin
                done <= 1'b0;
            end
        end
    end

endmodule