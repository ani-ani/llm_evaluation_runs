module quantum_chip_solver #(
    parameter MAX_K = 8,
    parameter DATA_WIDTH = 4,
    parameter SPIN_WIDTH = 1,
    parameter RESULT_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [DATA_WIDTH-1:0] N,
    input wire [DATA_WIDTH-1:0] M,
    input wire [DATA_WIDTH-1:0] K,
    
    input wire [DATA_WIDTH-1:0] y_0, x_0,
    input wire [SPIN_WIDTH-1:0] s_0,
    input wire [DATA_WIDTH-1:0] y_1, x_1,
    input wire [SPIN_WIDTH-1:0] s_1,
    input wire [DATA_WIDTH-1:0] y_2, x_2,
    input wire [SPIN_WIDTH-1:0] s_2,
    input wire [DATA_WIDTH-1:0] y_3, x_3,
    input wire [SPIN_WIDTH-1:0] s_3,
    input wire [DATA_WIDTH-1:0] y_4, x_4,
    input wire [SPIN_WIDTH-1:0] s_4,
    input wire [DATA_WIDTH-1:0] y_5, x_5,
    input wire [SPIN_WIDTH-1:0] s_5,
    input wire [DATA_WIDTH-1:0] y_6, x_6,
    input wire [SPIN_WIDTH-1:0] s_6,
    input wire [DATA_WIDTH-1:0] y_7, x_7,
    input wire [SPIN_WIDTH-1:0] s_7,
    
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state;
    reg [DATA_WIDTH-1:0] idx;
    reg inconsistent;
    
    reg [DATA_WIDTH-1:0] parent [0:15];
    reg parity [0:15];
    
    function [DATA_WIDTH-1:0] find_root;
        input [DATA_WIDTH-1:0] node;
        reg [DATA_WIDTH-1:0] root;
        reg p;
        begin
            root = node;
            p = 1'b0;
            while (parent[root] != root) begin
                p = p ^ parity[root];
                root = parent[root];
            end
            find_root = root;
        end
    endfunction
    
    task union_nodes;
        input [DATA_WIDTH-1:0] u;
        input [DATA_WIDTH-1:0] v;
        input [SPIN_WIDTH-1:0] w;
        reg [DATA_WIDTH-1:0] root_u;
        reg [DATA_WIDTH-1:0] root_v;
        reg p_u;
        reg p_v;
        begin
            root_u = find_root(u);
            root_v = find_root(v);
            p_u = 1'b0;
            p_v = 1'b0;
            if (root_u == root_v) begin
                if (p_u ^ p_v != w) begin
                    inconsistent = 1'b1;
                end
            end else begin
                parent[root_v] = root_u;
                parity[root_v] = p_u ^ p_v ^ w;
            end
        end
    endtask
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            inconsistent <= 1'b0;
            done <= 1'b0;
            result <= 32'd0;
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                parity[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        idx <= 4'd0;
                        inconsistent <= 1'b0;
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            parent[i] <= i;
                            parity[i] <= 1'b0;
                        end
                    end
                end
                
                PROCESS: begin
                    if (idx < K) begin
                        case (idx)
                            4'd0: union_nodes(y_0, N + x_0, s_0);
                            4'd1: union_nodes(y_1, N + x_1, s_1);
                            4'd2: union_nodes(y_2, N + x_2, s_2);
                            4'd3: union_nodes(y_3, N + x_3, s_3);
                            4'd4: union_nodes(y_4, N + x_4, s_4);
                            4'd5: union_nodes(y_5, N + x_5, s_5);
                            4'd6: union_nodes(y_6, N + x_6, s_6);
                            4'd7: union_nodes(y_7, N + x_7, s_7);
                        endcase
                        idx <= idx + 4'd1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    if (inconsistent) begin
                        result <= 32'd0;
                    end else begin
                        reg [3:0] root_count;
                        reg [3:0] i;
                        reg [3:0] roots [0:15];
                        reg [3:0] unique_roots;
                        
                        for (i = 0; i < 16; i = i + 1) begin
                            roots[i] = find_root(i);
                        end
                        
                        unique_roots = 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            reg [3:0] j;
                            reg found;
                            found = 1'b0;
                            for (j = 0; j < i; j = j + 1) begin
                                if (roots[i] == roots[j]) begin
                                    found = 1'b1;
                                end
                            end
                            if (!found) begin
                                unique_roots = unique_roots + 4'd1;
                            end
                        end
                        
                        result <= 32'd1 << (unique_roots - 4'd1);
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule