module SymmetricSquareFinder(
    input clk,
    input rst_n,
    input start,
    input [255:0] matrix_in,
    input [4:0] R,
    input [4:0] C,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] CHECK_SIZE = 4'd1;
    localparam [3:0] CHECK_ROW  = 4'd2;
    localparam [3:0] CHECK_COL  = 4'd3;
    localparam [3:0] CHECK_CELL = 4'd4;
    localparam [3:0] FOUND      = 4'd5;

    // Internal registers
    reg [3:0] state, next_state;
    reg [4:0] current_S;
    reg [4:0] current_r;
    reg [4:0] current_c;
    reg [4:0] sub_r;
    reg [4:0] sub_c;
    reg [4:0] max_S;
    reg [4:0] cycle_count;
    reg [4:0] max_cycles;
    reg [4:0] half_S;
    reg [4:0] bit1, bit2;
    reg mismatch;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            current_S <= 5'd0;
            current_r <= 5'd0;
            current_c <= 5'd0;
            sub_r <= 5'd0;
            sub_c <= 5'd0;
            cycle_count <= 5'd0;
            max_cycles <= 5'd0;
            half_S <= 5'd0;
            bit1 <= 1'b0;
            bit2 <= 1'b0;
            mismatch <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    max_S = (R < C) ? R : C;
                    current_S = max_S;
                    current_r = 5'd0;
                    current_c = 5'd0;
                    sub_r = 5'd0;
                    sub_c = 5'd0;
                    cycle_count = 5'd0;
                    max_cycles = 5'd50000;
                    next_state = CHECK_SIZE;
                end
            end

            CHECK_SIZE: begin
                if (current_S < 2) begin
                    result = 5'd0;
                    next_state = FOUND;
                end else begin
                    current_r = 5'd0;
                    next_state = CHECK_ROW;
                end
            end

            CHECK_ROW: begin
                if (current_r > (R - current_S)) begin
                    current_S = current_S - 5'd1;
                    next_state = CHECK_SIZE;
                end else begin
                    current_c = 5'd0;
                    next_state = CHECK_COL;
                end
            end

            CHECK_COL: begin
                if (current_c > (C - current_S)) begin
                    current_r = current_r + 5'd1;
                    next_state = CHECK_ROW;
                end else begin
                    sub_r = 5'd0;
                    sub_c = 5'd0;
                    half_S = current_S >> 1;
                    mismatch = 1'b0;
                    next_state = CHECK_CELL;
                end
            end

            CHECK_CELL: begin
                if (mismatch) begin
                    current_c = current_c + 5'd1;
                    next_state = CHECK_COL;
                end else if (sub_r >= current_S) begin
                    result = current_S;
                    next_state = FOUND;
                end else if (sub_c >= half_S) begin
                    sub_r = sub_r + 5'd1;
                    sub_c = 5'd0;
                    next_state = CHECK_CELL;
                end else begin
                    bit1 = matrix_in[(current_r + sub_r) * C + (current_c + sub_c)];
                    bit2 = matrix_in[(current_r + current_S - 1 - sub_r) * C + (current_c + current_S - 1 - sub_c)];
                    if (bit1 != bit2) begin
                        mismatch = 1'b1;
                    end
                    sub_c = sub_c + 5'd1;
                    next_state = CHECK_CELL;
                end
            end

            FOUND: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 5'd0;
        end else if (state != IDLE && state != FOUND) begin
            if (cycle_count >= max_cycles) begin
                result <= 5'd0;
                done <= 1'b1;
                cycle_count <= 5'd0;
            end else begin
                cycle_count <= cycle_count + 5'd1;
            end
        end
    end

endmodule