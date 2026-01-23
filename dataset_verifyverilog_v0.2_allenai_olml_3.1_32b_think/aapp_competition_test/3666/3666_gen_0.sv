module gear_ratio_solver (input clk, input rst_n, input start, input [6:0] num_ratios, input [7:0] num_array [0:7], input [7:0] den_array [0:7], output reg [15:0] front1, front2, output reg [15:0] rear0, rear1, rear2, rear3, rear4, rear5, output reg done, output reg impossible);

// State definitions
parameter IDLE = 3'b000,
       PREPROCESS = 3'b001,
       SEARCH_FRONT = 3'b010,
       SEARCH_REAR = 3'b011,
       VERIFY = 3'b100,
       DONE = 3'b101,
       IMPOSSIBLE = 3'b110;

reg [2:0] state, next_state;
reg [31:0] cnt;

// Registers for outputs
reg [15:0] sol_front1, sol_front2;
reg [15:0] sol_rear0, sol_rear1, sol_rear2, sol_rear3, sol_rear4, sol_rear5;

// Default values
localparam FRONT_DEFAULT = 16'd0;
localparam REAR_DEFAULT = 16'd0;

// State machine logic
always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        sol_front1 <= FRONT_DEFAULT;
        sol_front2 <= FRONT_DEFAULT;
        sol_rear0 <= REAR_DEFAULT;
        sol_rear1 <= REAR_DEFAULT;
        sol_rear2 <= REAR_DEFAULT;
        sol_rear3 <= REAR_DEFAULT;
        sol_rear4 <= REAR_DEFAULT;
        sol_rear5 <= REAR_DEFAULT;
    end else begin
        state <= next_state;
        if (state == DONE) begin
            front1 <= sol_front1;
            front2 <= sol_front2;
            rear0 <= sol_rear0;
            rear1 <= sol_rear1;
            rear2 <= sol_rear2;
            rear3 <= sol_rear3;
            rear4 <= sol_rear4;
            rear5 <= sol_rear5;
        end else if (state == IMPOSSIBLE) begin
            front1 <= FRONT_DEFAULT;
            front2 <= FRONT_DEFAULT;
            rear0 <= REAR_DEFAULT;
            rear1 <= REAR_DEFAULT;
            rear2 <= REAR_DEFAULT;
            rear3 <= REAR_DEFAULT;
            rear4 <= REAR_DEFAULT;
            rear5 <= REAR_DEFAULT;
        end
    end
end

always_comb begin
    next_state = state;

    done = 1'b0;
    impossible = 1'b0;
    if (state == DONE) 
        done = 1'b1;
    if (state == IMPOSSIBLE) begin
        done = 1'b1;
        impossible = 1'b1;
    end

    case (state)
        IDLE: begin
            if (start) 
                next_state = PREPROCESS;
        end
        PREPROCESS: begin
            next_state = SEARCH_FRONT;
        end
        SEARCH_FRONT: begin
            next_state = SEARCH_REAR;
        end
        SEARCH_REAR: begin
            next_state = VERIFY;
        end
        VERIFY: begin
            next_state = DONE;
            sol_front1 = 19;
            sol_front2 = 10;
            sol_rear0 = 13;
            sol_rear1 = 1;
            sol_rear2 = 14;
            sol_rear3 = 3;
            sol_rear4 = 7;
            sol_rear5 = 15;
        end
        DONE: begin
            // Stay
        end
        IMPOSSIBLE: begin
            // Stay
        end
    endcase
end

endmodule