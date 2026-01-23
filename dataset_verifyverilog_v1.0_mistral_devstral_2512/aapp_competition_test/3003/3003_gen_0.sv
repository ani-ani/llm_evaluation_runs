module graph_coloring (
    input wire clk,
    input wire rst_n,
    input wire start,
    // Adjacency matrix: adj_i[j] = 1 if edge between vertex i and j
    input wire [7:0] adj_0,
    input wire [7:0] adj_1,
    input wire [7:0] adj_2,
    input wire [7:0] adj_3,
    input wire [7:0] adj_4,
    input wire [7:0] adj_5,
    input wire [7:0] adj_6,
    input wire [7:0] adj_7,
    output reg [3:0] result,
    output reg done
);

parameter MAX_VERTICES = 8;
parameter MAX_COLORS = 8;

// State definitions
localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_START_K = 4'd1;
localparam [3:0] S_NEXT_VERT = 4'd2;
localparam [3:0] S_CHECK_COLOR = 4'd3;
localparam [3:0] S_VALIDATE = 4'd4;
localparam [3:0] S_BACKTRACK = 4'd5;
localparam [3:0] S_SUCCESS = 4'd6;
localparam [3:0] S_FAIL = 4'd7;
localparam [3:0] S_DONE = 4'd8;

reg [3:0] state;
reg [3:0] k;                    // Current color count being tried
reg [2:0] vertex_idx;           // Current vertex (0-7)
reg [2:0] color_try;            // Color trying for current vertex
reg [7:0] adj [0:7];            // Adjacency matrix storage
reg [2:0] colors [0:7];         // Color assignments
reg [7:0] colored_mask;         // Which vertices are colored
reg [2:0] stack_vertex [0:7];   // Stack for backtracking
reg [2:0] stack_color [0:7];    // Color at each stack level
reg [2:0] stack_ptr;

integer i;

// Load adjacency on start
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        adj[0] <= 8'd0; adj[1] <= 8'd0; adj[2] <= 8'd0; adj[3] <= 8'd0;
        adj[4] <= 8'd0; adj[5] <= 8'd0; adj[6] <= 8'd0; adj[7] <= 8'd0;
    end else if (start && state == S_IDLE) begin
        adj[0] <= adj_0; adj[1] <= adj_1; adj[2] <= adj_2; adj[3] <= adj_3;
        adj[4] <= adj_4; adj[5] <= adj_5; adj[6] <= adj_6; adj[7] <= adj_7;
    end
end

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE; done <= 1'b0; result <= 4'd0;
        k <= 4'd1; vertex_idx <= 3'd0; color_try <= 3'd0; colored_mask <= 8'd0; stack_ptr <= 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            colors[i] <= 3'd0; stack_vertex[i] <= 3'd0; stack_color[i] <= 3'd0;
        end
    end else begin
        case (state)
            S_IDLE: if (start) begin k <= 4'd1; state <= S_START_K; end
            S_START_K: begin vertex_idx <= 3'd0; color_try <= 3'd0; colored_mask <= 8'd0; stack_ptr <= 3'd0; state <= S_NEXT_VERT; end
            S_NEXT_VERT: if (vertex_idx >= 8) state <= S_SUCCESS; else state <= S_CHECK_COLOR;
            S_CHECK_COLOR: if (color_try >= k) state <= S_BACKTRACK; else state <= S_VALIDATE;
            S_VALIDATE: begin
                if (is_color_valid(vertex_idx, color_try)) begin
                    colors[vertex_idx] <= color_try; colored_mask[vertex_idx] <= 1'b1;
                    stack_vertex[stack_ptr] <= vertex_idx; stack_color[stack_ptr] <= color_try; stack_ptr <= stack_ptr + 1'b1;
                    vertex_idx <= vertex_idx + 1'b1; state <= S_NEXT_VERT;
                end else begin
                    color_try <= color_try + 1'b1; state <= S_CHECK_COLOR;
                end
            end
            S_BACKTRACK: begin
                if (stack_ptr == 3'd0) state <= S_FAIL;
                else begin
                    stack_ptr <= stack_ptr - 1'b1;
                    vertex_idx <= stack_vertex[stack_ptr];
                    color_try <= stack_color[stack_ptr] + 1'b1;
                    colored_mask[vertex_idx] <= 1'b0; state <= S_CHECK_COLOR;
                end
            end
            S_SUCCESS: begin result <= k; state <= S_DONE; end
            S_FAIL: begin
                if (k >= 8) begin result <= 8; state <= S_DONE; end
                else begin k <= k + 1'b1; state <= S_START_K; end
            end
            S_DONE: begin done <= 1'b1; state <= S_IDLE; end
            default: state <= S_IDLE;
        endcase
    end
end

function automatic is_color_valid(input [2:0] v, input [2:0] c);
    reg [7:0] neighbors; integer j;
begin
    neighbors = adj[v]; is_color_valid = 1'b1;
    for (j = 0; j < 8; j = j + 1)
        if (neighbors[j] && colored_mask[j] && colors[j] == c) is_color_valid = 1'b0;
end
endfunction

endmodule