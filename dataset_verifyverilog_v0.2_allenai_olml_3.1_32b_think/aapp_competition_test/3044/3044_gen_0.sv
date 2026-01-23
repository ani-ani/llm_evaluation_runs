module robot_path_fixer(input clk, input rst_n, input start, input [1:0] grid [0:15], input [2:0] cmd_length, input [7:0] commands, output reg [2:0] min_edits, output reg done);
localparam IDLE = 3'b000;
localparam EXPLORE_STATE = 3'b001;
localparam CHECK_GOAL = 3'b010;
localparam UPDATE_QUEUE = 3'b011;
localparam DONE = 3'b100;
reg [2:0] state;
reg [2:0] min_edits_reg;
reg done_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        min_edits_reg <= 3'b000;
        done_reg <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= EXPLORE_STATE;
            end
            EXPLORE_STATE: begin
                state <= CHECK_GOAL;
            end
            CHECK_GOAL: begin
                state <= UPDATE_QUEUE;
            end
            UPDATE_QUEUE: begin
                state <= EXPLORE_STATE;
            end
            DONE: begin
                min_edits <= min_edits_reg;
                done_reg <= 1;
            end
        endcase
    end
end
assign min_edits = min_edits_reg;
assign done = done_reg;
endmodule