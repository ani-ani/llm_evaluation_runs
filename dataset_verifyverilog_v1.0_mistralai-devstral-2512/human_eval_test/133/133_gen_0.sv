module sum_of_squares(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data_in [0:15],
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [15:0] ceiling_val;
    reg signed [31:0] square_val;
    reg signed [31:0] accum;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            ceiling_val <= 16'd0;
            square_val <= 32'd0;
            accum <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and datapath logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = COMPUTE;
                    index = 4'd0;
                    accum = 32'd0;
                    cycle_count = 8'd0;
                end
            end

            COMPUTE: begin
                // Extract components
                reg sign_bit = data_in[index][15];
                reg [6:0] int_part = data_in[index][14:8];
                reg [7:0] frac_part = data_in[index][7:0];

                // Ceiling operation
                if (sign_bit) begin
                    // Negative number
                    if (frac_part != 8'd0) begin
                        ceiling_val = {1'b1, int_part} - 16'd1;
                    end else begin
                        ceiling_val = {1'b1, int_part};
                    end
                end else begin
                    // Positive number
                    if (frac_part != 8'd0) begin
                        ceiling_val = {1'b0, int_part} + 16'd1;
                    end else begin
                        ceiling_val = {1'b0, int_part};
                    end
                end

                // Square and accumulate
                square_val = $signed(ceiling_val) * $signed(ceiling_val);
                accum = accum + square_val;

                // Update index
                if (index == len - 1) begin
                    next_state = FINISH;
                end else begin
                    index = index + 4'd1;
                end

                cycle_count = cycle_count + 8'd1;
            end

            FINISH: begin
                next_state = IDLE;
                done = 1'b1;
                result = accum;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule