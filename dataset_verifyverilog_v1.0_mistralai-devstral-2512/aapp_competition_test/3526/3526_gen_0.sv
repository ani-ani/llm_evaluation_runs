module BinarySequenceCounter(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [4:0] m,
    input [3:0] hint_l [31:0],
    input [3:0] hint_r [31:0],
    input hint_type [31:0],
    input hint_valid [31:0],
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    localparam [31:0] MOD = 32'd1000000007;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    reg [3:0] parent [0:15];
    reg [3:0] rank [0:15];
    reg [15:0] components;
    reg conflict;
    
    integer i, j, k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 4'd0;
            end
            components <= 16'd0;
            conflict <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    conflict <= 1'b0;
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        parent[i] <= i;
                        rank[i] <= 4'd0;
                    end
                    
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count == 8'd1) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            parent[i] <= i;
                            rank[i] <= 4'd0;
                        end
                        components <= 16'd16;
                    end
                    
                    if (cycle_count > 8'd1 && cycle_count <= 8'd33) begin
                        k <= cycle_count - 8'd2;
                        if (hint_valid[k]) begin
                            if (hint_type[k]) begin
                                if (hint_l[k] > hint_r[k]) begin
                                    conflict <= 1'b1;
                                end else begin
                                    for (i = hint_l[k] - 4'd1; i < hint_r[k]; i = i + 1) begin
                                        for (j = i + 4'd1; j < hint_r[k]; j = j + 1) begin
                                            if (find(i) == find(j)) begin
                                                conflict <= 1'b1;
                                            end
                                        end
                                    end
                                end
                            end else begin
                                for (i = hint_l[k] - 4'd1; i < hint_r[k]; i = i + 1) begin
                                    union_nodes(i, i + 4'd1);
                                end
                            end
                        end
                    end
                    
                    if (cycle_count == 8'd34) begin
                        components <= 16'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (find(i) == i) begin
                                components <= components + 16'd1;
                            end
                        end
                    end
                    
                    if (cycle_count == 8'd35) begin
                        if (conflict) begin
                            result <= 16'd0;
                        end else begin
                            result <= pow_mod(2, components, MOD);
                        end
                        state <= FINISH;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    function [3:0] find;
        input [3:0] x;
        reg [3:0] root;
        begin
            root = x;
            while (parent[root] != root) begin
                root = parent[root];
            end
            
            while (parent[x] != x) begin
                parent[x] = root;
                x = parent[x];
            end
            find = root;
        end
    endfunction
    
    task union_nodes;
        input [3:0] x, y;
        reg [3:0] root_x, root_y;
        begin
            root_x = find(x);
            root_y = find(y);
            
            if (root_x != root_y) begin
                if (rank[root_x] < rank[root_y]) begin
                    parent[root_x] = root_y;
                end else if (rank[root_x] > rank[root_y]) begin
                    parent[root_y] = root_x;
                end else begin
                    parent[root_y] = root_x;
                    rank[root_x] = rank[root_x] + 4'd1;
                end
                components = components - 16'd1;
            end
        end
    endtask
    
    function [15:0] pow_mod;
        input [15:0] base, exp;
        input [31:0] mod;
        reg [15:0] result;
        reg [15:0] current;
        integer i;
        begin
            result = 16'd1;
            current = base;
            for (i = 0; i < 16; i = i + 1) begin
                if (exp[i]) begin
                    result = (result * current) % mod;
                end
                current = (current * current) % mod;
            end
            pow_mod = result;
        end
    endfunction
    
endmodule