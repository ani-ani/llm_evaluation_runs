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
    
    input wire [DATA_WIDTH-1:0] y_0,
    input wire [DATA_WIDTH-1:0] x_0,
    input wire [SPIN_WIDTH-1:0] s_0,
    input wire [DATA_WIDTH-1:0] y_1,
    input wire [DATA_WIDTH-1:0] x_1,
    input wire [SPIN_WIDTH-1:0] s_1,
    input wire [DATA_WIDTH-1:0] y_2,
    input wire [DATA_WIDTH-1:0] x_2,
    input wire [SPIN_WIDTH-1:0] s_2,
    input wire [DATA_WIDTH-1:0] y_3,
    input wire [DATA_WIDTH-1:0] x_3,
    input wire [SPIN_WIDTH-1:0] s_3,
    input wire [DATA_WIDTH-1:0] y_4,
    input wire [DATA_WIDTH-1:0] x_4,
    input wire [SPIN_WIDTH-1:0] s_4,
    input wire [DATA_WIDTH-1:0] y_5,
    input wire [DATA_WIDTH-1:0] x_5,
    input wire [SPIN_WIDTH-1:0] s_5,
    input wire [DATA_WIDTH-1:0] y_6,
    input wire [DATA_WIDTH-1:0] x_6,
    input wire [SPIN_WIDTH-1:0] s_6,
    input wire [DATA_WIDTH-1:0] y_7,
    input wire [DATA_WIDTH-1:0] x_7,
    input wire [SPIN_WIDTH-1:0] s_7,
    
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

localparam [1:0] IDLE = 2'd0;
localparam [1:0] PROCESS = 2'd1;
localparam [1:0] DONE_STATE = 2'd2;

reg [1:0] state, next_state;
reg [3:0] parent [0:15];
reg parity [0:15];
reg [3:0] idx;
reg inconsistent;
reg [DATA_WIDTH-1:0] N_reg, M_reg, K_reg;

reg [3:0] current_y;
reg [3:0] current_x;
reg current_s;
reg [3:0] u;
reg [3:0] v;

always @(*) begin
    case (idx)
        4'd0: begin current_y = y_0; current_x = x_0; current_s = s_0; end
        4'd1: begin current_y = y_1; current_x = x_1; current_s = s_1; end
        4'd2: begin current_y = y_2; current_x = x_2; current_s = s_2; end
        4'd3: begin current_y = y_3; current_x = x_3; current_s = s_3; end
        4'd4: begin current_y = y_4; current_x = x_4; current_s = s_4; end
        4'd5: begin current_y = y_5; current_x = x_5; current_s = s_5; end
        4'd6: begin current_y = y_6; current_x = x_6; current_s = s_6; end
        4'd7: begin current_y = y_7; current_x = x_7; current_s = s_7; end
        default: begin current_y = 4'd0; current_x = 4'd0; current_s = 1'd0; end
    endcase
    u = current_y;
    v = N_reg + current_x;
end

function [4:0] find_root;
    input [3:0] node;
    reg [3:0] current;
    reg p;
    integer i;
    begin
        current = node;
        p = 1'b0;
        for (i = 0; i < 16; i = i + 1) begin
            if (parent[current] != current) begin
                p = p ^ parity[current];
                current = parent[current];
            end
        end
        find_root = {current, p};
    end
endfunction

wire [4:0] ru = find_root(u);
wire [4:0] rv = find_root(v);
wire [3:0] ru_root = ru[4:1];
wire [3:0] rv_root = rv[4:1];
wire ru_parity = ru[0];
wire rv_parity = rv[0];

reg [4:0] roots_count;
integer j;
always @(*) begin
    roots_count = 5'd0;
    for (j = 0; j < (N_reg + M_reg); j = j + 1) begin
        if (parent[j] == 4'(j)) begin
            roots_count = roots_count + 5'd1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        idx <= 4'd0;
        inconsistent <= 1'b0;
        for (integer i = 0; i < 16; i = i + 1) begin
            parent[i] <= 4'(i);
            parity[i] <= 1'b0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    N_reg <= N;
                    M_reg <= M;
                    K_reg <= K;
                    idx <= 4'd0;
                    inconsistent <= 1'b0;
                    for (integer i = 0; i < 16; i = i +1) begin
                        parent[i] <= (i < (N + M)) ? 4'(i) : 4'd0;
                        parity[i] <= 1'b0;
                    end
                    next_state <= PROCESS;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            PROCESS: begin
                if (idx < K_reg) begin
                    if (ru_root == rv_root) begin
                        if ((ru_parity ^ rv_parity) != current_s) begin
                            inconsistent <= 1'b1;
                        end
                    end else begin
                        parent[ru_root] <= rv_root;
                        parity[ru_root] <= (ru_parity ^ rv_parity ^ current_s);
                    end
                    idx <= idx + 4'd1;
                    next_state <= PROCESS;
                end else begin
                    next_state <= DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                if (inconsistent) begin
                    result <= 32'd0;
                end else begin
                    if (roots_count == 5'd0) begin
                        result <= 32'd0;
                    end else begin
                        result <= (32'd1 << (roots_count - 5'd1)) % 32'd1000000007;
                    end
                end
                done <= 1'b1;
                next_state <= IDLE;
            end
            
            default: begin
                next_state <= IDLE;
            end
        endcase
    end
end

endmodule