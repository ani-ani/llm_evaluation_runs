module IOUSettlement #(
    parameter N = 4,
    parameter M = 8,
    parameter WEIGHT_WIDTH = 10,
    parameter NODE_WIDTH = 3,
    parameter CYCLE_COUNT = 20
)(
    input clk,
    input rst_n,
    input start,
    input [NODE_WIDTH-1:0] n,
    input [3:0] m,
    input [M*NODE_WIDTH-1:0] a_flat,
    input [M*NODE_WIDTH-1:0] b_flat,
    input [M*WEIGHT_WIDTH-1:0] c_flat,
    output reg done,
    output reg [WEIGHT_WIDTH-1:0] graph [0:N-1][0:N-1]
);

localparam [2:0] STATE_IDLE = 3'd0;
localparam [2:0] STATE_LOAD = 3'd1;
localparam [2:0] STATE_CANCEL_PASS = 3'd2;
localparam [2:0] STATE_CHECK_CYCLE = 3'd3;
localparam [2:0] STATE_SUBTRACT = 3'd4;
localparam [2:0] STATE_OUTPUT = 3'd5;

reg [2:0] state, next_state;

reg [NODE_WIDTH-1:0] a_reg [0:M-1];
reg [NODE_WIDTH-1:0] b_reg [0:M-1];
reg [WEIGHT_WIDTH-1:0] c_reg [0:M-1];

reg [CYCLE_COUNT-1:0] cycle_idx;
reg [1:0] cycle_len;
reg [NODE_WIDTH-1:0] edge_u [0:3];
reg [NODE_WIDTH-1:0] edge_v [0:3];
reg [WEIGHT_WIDTH-1:0] min_weight;
reg [WEIGHT_WIDTH-1:0] temp_min;
reg cancel_occurred;
reg [9:0] pass_count;

reg [25:0] cycle_rom [0:CYCLE_COUNT-1];

integer i;
initial begin
    cycle_rom[0] = 26'b01_000_001_001_000_000_000_000_000;
    cycle_rom[1] = 26'b01_000_010_010_000_000_000_000_000;
    cycle_rom[2] = 26'b01_000_011_011_000_000_000_000_000;
    cycle_rom[3] = 26'b01_001_010_010_001_000_000_000_000;
    cycle_rom[4] = 26'b01_001_011_011_001_000_000_000_000;
    cycle_rom[5] = 26'b01_010_011_011_010_000_000_000_000;
    cycle_rom[6] = 26'b10_000_001_001_010_010_000_000_000;
    cycle_rom[7] = 26'b10_000_001_001_011_011_000_000_000;
    cycle_rom[8] = 26'b10_000_010_010_001_001_000_000_000;
    cycle_rom[9] = 26'b10_000_010_010_011_011_000_000_000;
    cycle_rom[10] = 26'b10_000_011_011_001_001_000_000_000;
    cycle_rom[11] = 26'b10_000_011_011_010_010_000_000_000;
    cycle_rom[12] = 26'b10_001_010_010_011_011_001_000_000;
    cycle_rom[13] = 26'b10_001_011_011_010_010_001_000_000;
    cycle_rom[14] = 26'b11_000_001_001_010_010_011_011_000;
    cycle_rom[15] = 26'b11_000_001_001_011_011_010_010_000;
    cycle_rom[16] = 26'b11_000_010_010_001_001_011_011_000;
    cycle_rom[17] = 26'b11_000_010_010_011_011_001_001_000;
    cycle_rom[18] = 26'b11_000_011_011_001_001_010_010_000;
    cycle_rom[19] = 26'b11_000_011_011_010_010_001_001_000;
end

always @(posedge clk) begin
    if (state == STATE_LOAD) begin
        for (i = 0; i < M; i = i + 1) begin
            a_reg[i] <= a_flat[i*NODE_WIDTH +: NODE_WIDTH];
            b_reg[i] <= b_flat[i*NODE_WIDTH +: NODE_WIDTH];
            c_reg[i] <= c_flat[i*WEIGHT_WIDTH +: WEIGHT_WIDTH];
        end
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        done <= 1'b0;
        cycle_idx <= 0;
        cancel_occurred <= 0;
        pass_count <= 0;
        for (i = 0; i < N; i = i + 1) begin
            graph[i][0] <= 10'd0;
            graph[i][1] <= 10'd0;
            graph[i][2] <= 10'd0;
            graph[i][3] <= 10'd0;
        end
    end else begin
        case (state)
            STATE_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= STATE_LOAD;
                    for (i = 0; i < N; i = i + 1) begin
                        graph[i][0] <= 10'd0;
                        graph[i][1] <= 10'd0;
                        graph[i][2] <= 10'd0;
                        graph[i][3] <= 10'd0;
                    end
                    cycle_idx <= 0;
                    cancel_occurred <= 0;
                    pass_count <= 0;
                end
            end
            
            STATE_LOAD: begin
                for (i = 0; i < M; i = i + 1) begin
                    if (i < m) begin
                        graph[a_reg[i]][b_reg[i]] <= c_reg[i];
                    end
                end
                state <= STATE_CANCEL_PASS;
            end
            
            STATE_CANCEL_PASS: begin
                cancel_occurred <= 0;
                cycle_idx <= 0;
                state <= STATE_CHECK_CYCLE;
                pass_count <= pass_count + 1;
            end
            
            STATE_CHECK_CYCLE: begin
                if (cycle_idx >= CYCLE_COUNT) begin
                    if (cancel_occurred && pass_count < 1000) begin
                        state <= STATE_CANCEL_PASS;
                    end else begin
                        state <= STATE_OUTPUT;
                    end
                end else begin
                    {cycle_len, edge_u[0], edge_v[0], edge_u[1], edge_v[1], 
                     edge_u[2], edge_v[2], edge_u[3], edge_v[3]} <= cycle_rom[cycle_idx];
                    state <= STATE_SUBTRACT;
                    min_weight <= 10'h3FF;
                end
            end
            
            STATE_SUBTRACT: begin
                if (graph[edge_u[0]][edge_v[0]] > 10'd0 &&
                    (cycle_len < 2 || graph[edge_u[1]][edge_v[1]] > 10'd0) &&
                    (cycle_len < 3 || graph[edge_u[2]][edge_v[2]] > 10'd0) &&
                    (cycle_len < 4 || graph[edge_u[3]][edge_v[3]] > 10'd0)) begin
                    temp_min <= graph[edge_u[0]][edge_v[0]];
                    if (cycle_len >= 2 && graph[edge_u[1]][edge_v[1]] < temp_min)
                        temp_min <= graph[edge_u[1]][edge_v[1]];
                    if (cycle_len >= 3 && graph[edge_u[2]][edge_v[2]] < temp_min)
                        temp_min <= graph[edge_u[2]][edge_v[2]];
                    if (cycle_len >= 4 && graph[edge_u[3]][edge_v[3]] < temp_min)
                        temp_min <= graph[edge_u[3]][edge_v[3]];
                    min_weight <= temp_min;
                    graph[edge_u[0]][edge_v[0]] <= graph[edge_u[0]][edge_v[0]] - temp_min;
                    if (cycle_len >= 2)
                        graph[edge_u[1]][edge_v[1]] <= graph[edge_u[1]][edge_v[1]] - temp_min;
                    if (cycle_len >= 3)
                        graph[edge_u[2]][edge_v[2]] <= graph[edge_u[2]][edge_v[2]] - temp_min;
                    if (cycle_len >= 4)
                        graph[edge_u[3]][edge_v[3]] <= graph[edge_u[3]][edge_v[3]] - temp_min;
                    cancel_occurred <= 1;
                end
                cycle_idx <= cycle_idx + 1;
                state <= STATE_CHECK_CYCLE;
            end
            
            STATE_OUTPUT: begin
                done <= 1'b1;
                state <= STATE_IDLE;
            end
            
            default: state <= STATE_IDLE;
        endcase
    end
end

endmodule