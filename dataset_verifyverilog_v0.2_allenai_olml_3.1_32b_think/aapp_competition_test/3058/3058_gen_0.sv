module evolution_solver (
    input clk,
    input rst_n,
    input start,
    input [15:0][15:0][7:0] fossils,
    input [4:0] num_fossils,
    input [15:0][7:0] target,
    output reg [15:0] result_mask1,
    output reg [15:0] result_mask2,
    output reg valid,
    output reg impossible
);

reg [2:0] state;
reg [15:0] current_fossil_idx;
reg [15:0] path1_mask, path2_mask;
reg [15:0] path1_value, path2_value;
reg [15:0] assigned_count;
reg [4:0] num_total;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'd0;
        current_fossil_idx <= 16'd0;
        path1_mask <= 16'd0;
        path2_mask <= 16'd0;
        path1_value <= 16'd0;
        path2_value <= 16'd0;
        assigned_count <= 16'd0;
        num_total <= num_fossils;
        valid <= 1'b0;
        impossible <= 1'b0;
    end else begin
        case (state)
            3'd0: begin
                if (start)
                    state <= 3'd1;
                else
                    state <= 3'd0;
            end
            3'd1: begin
                num_total <= num_fossils;
                assigned_count <= 16'd0;
                current_fossil_idx <= 16'd0;
                path1_mask <= 16'd0;
                path2_mask <= 16'd0;
                path1_value <= 16'd0;
                path2_value <= 16'd0;
                state <= 3'd2;
            end
            3'd2: begin
                if (current_fossil_idx < num_total) begin
                    path1_mask <= path1_mask | (1 << current_fossil_idx);
                    path1_value <= fossils[current_fossil_idx][15:0];
                    current_fossil_idx <= current_fossil_idx + 1;
                    state <= 3'd2;
                end else begin
                    valid <= 1'b1;
                    impossible <= 1'b0;
                    state <= 3'd5;
                end
            end
            3'd3: state <= 3'd2;
            3'd4: state <= 3'd2;
            3'd5: state <= 3'd5;
            3'd6: begin
                impossible <= 1'b1;
                state <= 3'd6;
            end
        endcase
    end
endmodule