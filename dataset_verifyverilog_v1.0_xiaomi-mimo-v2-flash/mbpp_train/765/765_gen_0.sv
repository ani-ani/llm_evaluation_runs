module polite_number (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [11:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers for state machine
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Combinational logic for next state and computation
    reg [15:0] next_result;
    reg next_done;

    // State transition and output logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_result = result;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
                next_done = 1'b0;
            end

            COMPUTE: begin
                // Computation: If n is 0, result = 1; else result = n | 1
                if (n == 12'd0) begin
                    next_result = 16'd1;
                end else begin
                    next_result = {4'd0, n} | 16'd1;
                end
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic for state and output registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule