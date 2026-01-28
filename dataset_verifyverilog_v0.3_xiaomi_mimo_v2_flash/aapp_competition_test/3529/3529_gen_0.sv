module spanning_tree_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] edge [0:31],
    input wire [2:0] k,
    output reg result,
    output reg done
);
    parameter N = 8;
    parameter M = 32;
    
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] RESET_PARENT = 3'd2;
    localparam [2:0] PROCESS    = 3'd3;
    localparam [2:0] NEXT_PASS  = 3'd4;
    localparam [2:0] CHECK      = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;
    
    reg [2:0] state, next_state;
    reg [2:0] min_blue, max_blue;
    reg [2:0] current_blue;
    reg phase;
    reg [4:0] edge_idx;
    reg weight_group;
    reg [2:0] parent [0:N-1];
    reg color_reg [0:M-1];
    reg [2:0] src_reg [0:M-1];
    reg [2:0] dst_reg [0:M-1];
    reg done_reg;
    reg result_reg;
    
    integer i;
    reg [2:0] find_src_temp;
    reg [2:0] find_dst_temp;
    
    function automatic [2:0] find_node;
        input [2:0] node;
        reg [2:0] current;
        begin
            current = node;
            if (parent[current] != current) current = parent[current];
            if (parent[current] != current) current = parent[current];
            if (parent[current] != current) current = parent[current];
            if (parent[current] != current) current = parent[current];
            find_node = current;
        end
    endfunction
    
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD : IDLE;
            LOAD:       next_state = RESET_PARENT;
            RESET_PARENT: next_state = PROCESS;
            PROCESS:    next_state = (edge_idx == M - 1) ? NEXT_PASS : PROCESS;
            NEXT_PASS:  next_state = (weight_group == 1 && phase == 1) ? CHECK : (weight_group == 1 ? RESET_PARENT : PROCESS);
            CHECK:      next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            min_blue <= 3'd0;
            max_blue <= 3'd0;
            current_blue <= 3'd0;
            phase <= 1'b0;
            edge_idx <= 5'd0;
            weight_group <= 1'b0;
            done_reg <= 1'b0;
            result_reg <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                parent[i] <= 3'd0;
            end
            for (i = 0; i < M; i = i + 1) begin
                color_reg[i] <= 1'b0;
                src_reg[i] <= 3'd0;
                dst_reg[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
            done <= done_reg;
            result <= result_reg;
            
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        result_reg <= 1'b0;
                        min_blue <= 3'd0;
                        max_blue <= 3'd0;
                        current_blue <= 3'd0;
                        phase <= 1'b0;
                        weight_group <= 1'b0;
                    end
                end
                
                LOAD: begin
                    for (i = 0; i < M; i = i + 1) begin
                        color_reg[i] <= edge[i][6];
                        src_reg[i] <= edge[i][5:3];
                        dst_reg[i] <= edge[i][2:0];
                    end
                end
                
                RESET_PARENT: begin
                    for (i = 0; i < N; i = i + 1) begin
                        parent[i] <= i;
                    end
                    edge_idx <= 5'd0;
                    current_blue <= 3'd0;
                end
                
                PROCESS: begin
                    find_src_temp = find_node(src_reg[edge_idx]);
                    find_dst_temp = find_node(dst_reg[edge_idx]);
                    
                    if (color_reg[edge_idx] == weight_group && find_src_temp != find_dst_temp) begin
                        parent[find_src_temp] <= find_dst_temp;
                        if ((phase == 0 && weight_group == 1) || (phase == 1 && weight_group == 0)) begin
                            current_blue <= current_blue + 1;
                        end
                    end
                    edge_idx <= edge_idx + 1;
                end
                
                NEXT_PASS: begin
                    if (weight_group == 1'b0) begin
                        weight_group <= 1'b1;
                    end else begin
                        weight_group <= 1'b0;
                        if (phase == 1'b0) begin
                            min_blue <= current_blue;
                            phase <= 1'b1;
                        end else begin
                            max_blue <= current_blue;
                        end
                    end
                end
                
                CHECK: begin
                    if (k >= min_blue && k <= max_blue) begin
                        result_reg <= 1'b1;
                    end else begin
                        result_reg <= 1'b0;
                    end
                    done_reg <= 1'b1;
                end
                
                DONE_STATE: begin
                    done_reg <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule