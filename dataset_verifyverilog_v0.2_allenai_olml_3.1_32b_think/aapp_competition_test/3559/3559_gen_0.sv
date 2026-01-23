module zergling_simulation ( input clk, input rst_n, input start, input [2:0] grid_in_00_to_07, input [2:0] grid_in_08_to_15, input [2:0] grid_in_16_to_23, input [2:0] grid_in_24_to_31, input [2:0] grid_in_32_to_39, input [2:0] grid_in_40_to_47, input [2:0] grid_in_48_to_55, input [2:0] grid_in_56_to_63, input [3:0] p1_atk_up, input [3:0] p1_arm_up, input [3:0] p2_atk_up, input [3:0] p2_arm_up, input [7:0] num_turns, output reg [2:0] grid_out_00_to_07, output reg [2:0] grid_out_08_to_15, output reg [2:0] grid_out_16_to_23, output reg [2:0] grid_out_24_to_31, output reg [2:0] grid_out_32_to_39, output reg [2:0] grid_out_40_to_47, output reg [2:0] grid_out_48_to_55, output reg [2:0] grid_out_56_to_63, output reg done );
localparam IDLE = 3'd0, LOAD=1, TURN_START=2, CHECK_ATTACK=3, EXECUTE_ATTACK=4, CHECK_MOVE=5, EXECUTE_MOVE=6, REGENERATE=7, NEXT_TURN=8, DONE=9;
reg [2:0] state;
reg [7:0] turn_count;
reg [7:0] remaining_turns;

always @(posedge clk or posedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        turn_count <= 8'd0;
        remaining_turns <= 8'd0;
    end else begin
        case (state)
            IDLE: if (start) state <= LOAD; else state <= IDLE;
            LOAD:  
                remaining_turns <= num_turns;
                state <= TURN_START;
            TURN_START:  
                turn_count <= turn_count + 1;
                if (turn_count > remaining_turns) begin
                    state <= DONE;
                end else begin
                    state <= CHECK_ATTACK;
                end
            CHECK_ATTACK: state <= EXECUTE_ATTACK;
            EXECUTE_ATTACK: state <= CHECK_MOVE;
            CHECK_MOVE: state <= EXECUTE_MOVE;
            EXECUTE_MOVE: state <= REGENERATE;
            REGENERATE: state <= NEXT_TURN;
            NEXT_TURN:  
                if (turn_count < remaining_turns) begin
                    turn_count <= turn_count +1;
                    state <= TURN_START;
                end else begin
                    state <= DONE;
                end
            DONE: state <= DONE;
            default: state <= IDLE;
        endcase
    end
end

assign grid_out_00_to_07 = 3'b000;
assign grid_out_08_to_15 = 3'b000;
assign grid_out_16_to_23 = 3'b000;
assign grid_out_24_to_31 = 3'b000;
assign grid_out_32_to_39 = 3'b000;
assign grid_out_40_to_47 = 3'b000;
assign grid_out_48_to_55 = 3'b000;
assign grid_out_56_to_63 = 3'b000;
assign done = (state == DONE);

endmodule