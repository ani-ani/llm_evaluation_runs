module geometric_sum(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam COMPUTING = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] count;
    reg [3:0] next_count;
    reg [31:0] term;
    reg [31:0] next_term;
    reg [31:0] sum;
    reg [31:0] next_sum;
    reg next_done;
    reg [31:0] next_result;

    // Constant for 1.0 in Q16.16 format
    localparam [31:0] ONE = 32'h00010000;

    // State transition and output logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        next_term = term;
        next_sum = sum;
        next_done = 1'b0;
        next_result = result;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = COMPUTING;
                    next_count = 4'd0;
                    next_term = ONE;
                    next_sum = 32'd0;
                end
            end

            COMPUTING: begin
                if (count < n) begin
                    // Add term to sum and shift term for next iteration
                    next_sum = sum + term;
                    next_term = term >> 1;
                    next_count = count + 1;
                end else begin
                    // Computation complete, capture final result
                    next_state = DONE;
                    next_result = sum;
                    next_done = 1'b1;
                end
            end

            DONE: begin
                // Hold result until next start
                next_done = 1'b1;
                if (start) begin
                    next_state = COMPUTING;
                    next_count = 4'd0;
                    next_term = ONE;
                    next_sum = 32'd0;
                    next_done = 1'b0;
                end else if (!rst_n) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
                next_done = 1'b0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            term <= 32'd0;
            sum <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            term <= next_term;
            sum <= next_sum;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule