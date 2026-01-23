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
    
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] RESET_PARENT = 3'd2;
    localparam [2:0] PROCESS = 3'd3;
    localparam [2:0] NEXT_PASS = 3'd4;
    localparam [2:0] CHECK = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;
    
    reg [2:0] min_blue;
    reg [2:0] max_blue;
    reg [2:0] current_blue;
    reg phase;
    reg [4:0] edge_idx;
    reg weight_group;
    reg [2:0] parent [0:N-1];
    reg [2:0] state;
    reg [0:M-1] color_reg;
    reg [2:0] src_reg [0:M-1];
    reg [2:0] dst_reg [0:M-1];
    
    wire current_color;
    wire [2:0] current_src;
    wire [2:0] current_dst;
    
    assign current_color = color_reg[edge_idx];
    assign current_src = src_reg[edge_idx];
    assign current_dst = dst_reg[edge_idx];
    
    wire match;
    wire increment_flag;
    wire should_union;
    
    assign match = (phase == 1'b0) ? (current_color == weight_group) : (current_color == ~weight_group);
    assign increment_flag = (phase == 1'b0 && weight_group == 1'b1) || (phase == 1'b1 && weight_group == 1'b0);
    
    function [2:0] find;
        input [2:0] node;
        begin
            find = node;
            if (parent[find] != find) find = parent[find];
            if (parent[find] != find) find = parent[find];
            if (parent[find] != find) find = parent[find];
            if (parent[find] != find) find = parent[find];
            if (parent[find] != find) find = parent[find];
            if (parent[find] != find) find = parent[find];
            if (parent[find] != find) find = parent[find];
        end
    endfunction
    
    wire [2:0] find_src;
    wire [2:0] find_dst;
    
    assign find_src = find(current_src);
    assign find_dst = find(current_dst);
    
    assign should_union = match && (find_src != find_dst);
    
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
            integer i;
            for (i = 0; i < N; i = i + 1) begin
                parent[i] <= 3'd0;
            end
            for (i = 0; i < M; i = i + 1) begin
                color_reg[i] <= 1'b0;
                src_reg[i] <= 3'd0;
                dst_reg[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    integer i;
                    for (i = 0; i < M; i = i + 1) begin
                        color_reg[i] <= edge[i][6];
                        src_reg[i] <= edge[i][5:3];
                        dst_reg[i] <= edge[i][2:0];
                    end
                    min_blue <= 3'd0;
                    max_blue <= 3'd0;
                    phase <= 1'b0;
                    state <= RESET_PARENT;
                end
                
                RESET_PARENT: begin
                    integer i;
                    for (i = 0; i < N; i = i + 1) begin
                        parent[i] <= i;
                    end
                    current_blue <= 3'd0;
                    edge_idx <= 5'd0;
                    weight_group <= 1'b0;
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    if (should_union) begin
                        parent[find_src] <= find_dst;
                        if (increment_flag) begin
                            current_blue <= current_blue + 3'd1;
                        end
                    end
                    if (edge_idx == 5'd31) begin
                        state <= NEXT_PASS;
                        edge_idx <= 5'd0;
                    end else begin
                        edge_idx <= edge_idx + 5'd1;
                    end
                end
                
                NEXT_PASS: begin
                    if (weight_group == 1'b0) begin
                        weight_group <= 1'b1;
                        state <= PROCESS;
                    end else begin
                        if (phase == 1'b0) begin
                            min_blue <= current_blue;
                            phase <= 1'b1;
                            state <= RESET_PARENT;
                        end else begin
                            max_blue <= current_blue;
                            state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    if (k >= min_blue && k <= max_blue) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule