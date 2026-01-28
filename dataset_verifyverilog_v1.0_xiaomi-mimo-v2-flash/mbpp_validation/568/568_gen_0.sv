module empty_dict_array (
    input clk,
    input rst_n,
    input start,
    input [3:0] length,
    output reg done,
    output reg [31:0] result [0:15]
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] GENERATE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] counter;
    reg [3:0] next_counter;
    reg done_reg;
    reg [31:0] next_result [0:15];
    integer i;

    // State transition and output logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_counter = counter;
        done_reg = 1'b0;
        for (i = 0; i < 16; i = i + 1) begin
            next_result[i] = result[i];
        end

        case (state)
            IDLE: begin
                done_reg = 1'b0;
                next_counter = 4'd0;
                if (start) begin
                    next_state = GENERATE;
                end
            end

            GENERATE: begin
                if (counter < length) begin
                    // Set current entry to 0
                    next_result[counter] = 32'd0;
                    next_counter = counter + 4'd1;
                end
                // Transition to DONE when counter reaches length
                if (counter >= length) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                done_reg = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            counter <= next_counter;
            done <= done_reg;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= next_result[i];
            end
        end
    end

endmodule