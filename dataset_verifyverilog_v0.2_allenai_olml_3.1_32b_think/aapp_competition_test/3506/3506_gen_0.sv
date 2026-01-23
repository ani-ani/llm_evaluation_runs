module cheerleader_optimizer ( input clk, input rst_n, input start, input [1:0] num_cheerleaders, input [7:0] cheer_time, input [7:0] opponent_pattern, output reg [3:0] sportify_goals, output reg [3:0] spoilify_goals, output reg done );
reg [1:0] state;
reg [3:0] sport_goal, spoil_goal;
reg done_reg;
reg [7:0] counter;
localparam IDLE = 2'b00;
localparam EVAL = 2'b01;
localparam DONE = 2'b11;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        sport_goal <= 4'd0;
        spoil_goal <= 4'd0;
        done_reg <= 1'b0;
        counter <= 8'd0;
    end else begin
        num_cheerleaders; // use input
        cheer_time;      // use input
        opponent_pattern; // use input
        case (state)
            IDLE: begin
                if (start) begin
                    state <= EVAL;
                    counter <= 8'd0;
                end
            end
            EVAL: begin
                if (counter < 500) begin
                    counter <= counter + 1;
                end else begin
                    state <= DONE;
                    sport_goal <= 4'd0;
                    spoil_goal <= 4'd0;
                end
            end
            DONE: begin
                done_reg <= 1'b1;
            end
        endcase
    end
end
assign sportify_goals = sport_goal;
assign spoilify_goals = spoil_goal;
assign done = done_reg;
endmodule