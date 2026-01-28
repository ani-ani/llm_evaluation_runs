module TribonacciSequenceGenerator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    output reg [31:0] result,
    output reg [4:0] index,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [4:0] current_index, next_index;
    reg [31:0] result_reg, next_result;
    reg valid_reg, next_valid;
    reg done_reg, next_done;

    // Combinational logic for value computation
    wire [4:0] i;
    wire [4:0] half_i;
    wire [4:0] temp_odd;
    wire [4:0] half_temp;
    wire [31:0] square_val;
    wire [31:0] temp_val;
    wire is_even;

    assign i = current_index;
    assign half_i = i >> 1;  // i/2 for even i
    assign is_even = (i[0] == 1'b0);
    assign temp_odd = i + 5'd3;
    assign half_temp = temp_odd >> 1;  // (i+3)/2 for odd i

    // Square computation: 5-bit * 5-bit <= 10 bits, fit in 32 bits
    // For Q16.16 format, multiply by 65536
    // half_temp is max 11 (for i=19), square is 121, shifted left by 16
    wire [9:0] square_bits;
    assign square_bits = half_temp * half_temp;
    assign square_val = {22'd0, square_bits, 16'd0};  // Q16.16 format

    // Value computation
    always @(*) begin
        if (is_even) begin
            // i/2 + 1 in Q16.16 format
            temp_val = {27'd0, half_i, 16'd0} + 32'h00010000;  // +1.0
        end else begin
            // (square) - 1 in Q16.16 format
            temp_val = square_val - 32'h00010000;  // -1.0
        end
    end

    // State update and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 5'd0;
            result_reg <= 32'd0;
            valid_reg <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            current_index <= next_index;
            result_reg <= next_result;
            valid_reg <= next_valid;
            done_reg <= next_done;
        end
    end

    always @(*) begin
        // Default values
        next_state = state;
        next_index = current_index;
        next_result = result_reg;
        next_valid = 1'b0;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                next_valid = 1'b0;
                next_done = 1'b0;
                next_index = 5'd0;
                if (start) begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                next_valid = 1'b1;
                next_result = temp_val;
                next_done = 1'b0;
                
                if (current_index < n) begin
                    next_index = current_index + 5'd1;
                    next_state = COMPUTE;
                end else begin
                    // Last index (n) computed, move to finish
                    next_index = current_index;
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_valid = 1'b1;
                next_result = result_reg;
                next_done = 1'b1;
                next_index = current_index;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output assignments
    always @(*) begin
        result = result_reg;
        index = current_index;
        valid = valid_reg;
        done = done_reg;
    end

endmodule