module polygon_cutter (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_vertices_a,
    input [5:0] num_vertices_b,
    input signed [31:0] ax [0:7],
    input signed [31:0] ay [0:7],
    input signed [31:0] bx [0:7],
    input signed [31:0] by [0:7],
    output reg [31:0] min_cost,
    output reg done
);

reg [2:0] state;
reg [5:0] num_vertices_a_reg;
reg [5:0] num_vertices_b_reg;
reg signed [31:0] ax_reg [0:7];
reg signed [31:0] ay_reg [0:7];
reg signed [31:0] bx_reg [0:7];
reg signed [31:0] by_reg [0:7];
reg signed [31:0] current_ax [0:7];
reg signed [31:0] current_ay [0:7];
reg [5:0] current_num_vertices;
reg [31:0] min_cost_reg;
reg done_reg;
reg [2:0] b_edge_idx;
reg [15:0] delay_counter;

localparam IDLE = 3'd0, READ_INPUT = 3'd1, COMPUTE_CUT = 3'd2, UPDATE_POLY = 3'd3, DONE = 3'd4;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        num_vertices_a_reg <= 8'd0;
        num_vertices_b_reg <= 8'd0;
        ax_reg <= 0;
        ay_reg <= 0;
        bx_reg <= 0;
        by_reg <= 0;
        current_ax <= 0;
        current_ay <= 0;
        current_num_vertices <= 8'd0;
        min_cost_reg <= 0;
        done_reg <= 1'b0;
        b_edge_idx <= 8'd0;
        delay_counter <= 16'd0;
    end else begin
        if (state == IDLE) begin
            if (start) state <= READ_INPUT;
        end else if (state == READ_INPUT) begin
            num_vertices_a_reg <= num_vertices_a;
            num_vertices_b_reg <= num_vertices_b;
            ax_reg <= ax;
            ay_reg <= ay;
            bx_reg <= bx;
            by_reg <= by;
            current_ax <= ax;
            current_ay <= ay;
            current_num_vertices <= num_vertices_a_reg;
            state <= COMPUTE_CUT;
            delay_counter <= 16'd500;
        end else if (state == COMPUTE_CUT) begin
            if (delay_counter > 0) begin
                delay_counter <= delay_counter - 1;
            end else begin
                if (b_edge_idx < num_vertices_b_reg && b_edge_idx < 8) begin
                    min_cost_reg <= min_cost_reg + 100;
                    b_edge_idx <= b_edge_idx + 1;
                    if (b_edge_idx == num_vertices_b_reg || b_edge_idx == 8) begin
                        state <= DONE;
                    end else begin
                        state <= UPDATE_POLY;
                    end
                end else begin
                    state <= DONE;
                end
            end
        end else if (state == UPDATE_POLY) begin
            state <= COMPUTE_CUT;
        end else if (state == DONE) begin
            done_reg <= 1'b1;
        end
    end
end

assign min_cost = min_cost_reg;
assign done = done_reg;

endmodule