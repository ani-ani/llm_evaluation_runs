module tree_assignment (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [4:0] edge_u [14:0],
    input [4:0] edge_v [14:0],
    output reg [14:0] l_mask,
    output reg valid,
    output reg done
);

// Internal registers
reg [14:0] l_mask_reg;
reg [7:0] left_tree_nodes;
reg [7:0] right_tree_nodes;
reg [3:0] current_edge;
reg [3:0] state;

localparam IDLE = 4'd0, PROCESSING = 4'd1, CHECKING = 4'd2, DONE_STATE = 4'd3;

// Reset handler (asynchronous)
always @(*) begin
    if (!rst_n) begin
        l_mask_reg <= 0;
        left_tree_nodes <= 1;
        right_tree_nodes <= 0;
        current_edge <= 0;
        state <= IDLE;
    end
end

// Clock-driven logic
always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
        case (state)
            IDLE: begin
                valid <= 0;
                done <= 0;
                if (start) begin
                    state <= PROCESSING;
                end
            end
            PROCESSING: begin
                valid <= 0;
                done <= 0;
                if (current_edge < 15) begin
                    current_edge <= current_edge + 1;
                end else begin
                    state <= CHECKING;
                end
            end
            CHECKING: begin
                if (left_tree_nodes == 255 && right_tree_nodes == 255) begin
                    valid <= 1;
                    done <= 1;
                end else begin
                    valid <= 0;
                    done <= 1;
                end
                state <= DONE_STATE;
            end
            DONE_STATE: begin
            end
        endcase
    end
end

// Assign outputs
assign l_mask = l_mask_reg;
assign valid = valid;
assign done = done;

endmodule