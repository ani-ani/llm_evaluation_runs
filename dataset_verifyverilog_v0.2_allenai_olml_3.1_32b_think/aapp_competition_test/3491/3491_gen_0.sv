module hogwarts_staircases (
    input clk,
    input rst_n,
    input start,
    input [63:0] current_state,
    input [63:0] target_state,
    output reg [7:0] action_type,
    output reg [2:0] floor_num,
    output reg valid,
    output reg done
);

reg [63:0] curr_state;
reg [63:0] target;
reg [7:0] step_count;
reg [2:0] state;
reg [3:0] best_action;
reg [3:0] counter;
reg [31:0] best_distance;
reg [2:0] g_counter;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        curr_state <= 0;
        target <= 0;
        step_count <=0;
        state <= 0;
        best_action <=0;
        counter <=0;
        best_distance <=0;
        g_counter <=0;
    end else begin
        case (state)
            0: begin
                if (start) begin
                    state <=1;
                    curr_state <= current_state;
                    target <= target_state;
                    step_count <=0;
                end
            end
            1: begin
                if (counter < 12) begin
                    counter <= counter +1;
                end else begin
                    state <=2;
                    counter <=0;
                end
            end
            2: begin
                state <=3;
            end
            3: begin
                if (step_count >= 128) begin
                    state <=4;
                end else begin
                    state <=1;
                    counter <=0;
                end
            end
            4: begin
                // done
            end
        endcase
    end
end

// Assign outputs
assign action_type = 0;
assign floor_num = 0;
assign valid = 0;
assign done = (state ==4);

endmodule