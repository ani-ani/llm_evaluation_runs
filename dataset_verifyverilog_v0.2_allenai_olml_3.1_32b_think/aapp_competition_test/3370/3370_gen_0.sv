module eagleton_solver (
    input clk,
    input rst_n, // Active-low reset
    input start,
    input [31:0] k,
    input [31:0] h_0,
    output reg [31:0] max_height,
    output done
);

// Internal signals
reg [2:0] state; // IDLE=0, ADD_LOOP=1, DONE=2
reg [2:0] counter;
reg [31:0] accumulator;
reg [2:0] next_state;
reg [31:0] next_accumulator;
reg [2:0] next_counter;

localparam IDLE = 3'd0;
localparam ADD_LOOP = 3'd1;
localparam DONE = 3'd2;

// Default values for synthesis
always @(*) begin
    state <= IDLE;
    counter <= 3'd0;
    accumulator <= 32'd0;
    next_state <= IDLE;
    next_accumulator <= 32'd0;
    next_counter <= 3'd0;
end

// Combinational assignment for done
assign done = (state == DONE);

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 3'd0;
        accumulator <= 32'd0;
        next_state <= IDLE;
        next_accumulator <= 32'd0;
        next_counter <= 3'd0;
    end else begin
        case (state)
            IDLE: 
                if (start) begin
                    next_state = ADD_LOOP;
                    next_accumulator = h_0;
                    next_counter = 3'd0;
                end else begin
                    next_state = IDLE;
                    next_accumulator = 32'd0;
                    next_counter = 3'd0;
                end
            ADD_LOOP: 
                if (counter < 7) begin
                    next_state = ADD_LOOP;
                    next_accumulator = accumulator + k;
                    next_counter = counter + 1;
                end else begin
                    next_state = DONE;
                    next_accumulator = accumulator;
                    next_counter = counter;
                end
            DONE: 
                next_state = DONE;
                next_accumulator = accumulator;
                next_counter = counter;
        endcase
        state <= next_state;
        accumulator <= next_accumulator;
        counter <= next_counter;
    end
end

// Output assignment
assign max_height = (state == DONE) ? accumulator : 32'd0;

endmodule