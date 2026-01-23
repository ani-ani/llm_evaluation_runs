module identifier_validator (
    input clk,
    input rst_n, // active low
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg result,
    output reg error,
    output reg done
);

localparam IDLE = 3'd0;
localparam WAIT_START = 3'd1;
localparam READ_CHAR = 3'd2;
localparam VALIDATE = 3'd3;
localparam ERROR = 3'd4;
localparam DONE = 3'd5;

reg [7:0] next_expected;
reg [7:0] current_char;
reg [255:0] seen;
reg [3:0] state;
reg error;
reg done;
reg result;

always @(posedge clk) begin
    if (!rst_n) begin
        next_expected <= 8'h61;
        current_char <= 8'h00;
        seen <= 0;
        state <= IDLE;
        error <= 1'b0;
        done <= 1'b0;
        result <= 1'b0;
        return;
    end

    case (state)
        IDLE: begin
            if (start) begin
                next_expected <= 8'h61;
                seen <= 0;
                error <= 1'b0;
                done <= 1'b0;
                result <= 1'b0;
                state <= WAIT_START;
            end else begin
                state <= IDLE;
            end
        end

        WAIT_START: begin
            if (valid_in) begin
                state <= READ_CHAR;
            end else begin
                if (!error) begin
                    done <= 1'b1;
                    state <= DONE;
                end else begin
                    state <= DONE;
                end
            end
        end

        READ_CHAR: begin
            current_char <= char_in;
            state <= VALIDATE;
        end

        VALIDATE: begin
            if (!seen[current_char]) begin // new character
                if (current_char < next_expected) begin
                    seen[current_char] <= 1'b1;
                    result <= 1'b1;
                    error <= 1'b0;
                    state <= WAIT_START;
                end else if (current_char == next_expected) begin
                    next_expected <= current_char + 1;
                    seen[current_char] <= 1'b1;
                    result <= 1'b1;
                    error <= 1'b0;
                    state <= WAIT_START;
                end else begin // current_char > next_expected
                    seen[current_char] <= 1'b1; // mark as seen? Or not necessary, but harmless
                    result <= 1'b0;
                    error <= 1'b1;
                    done <= 1'b1;
                    state <= ERROR;
                end
            end else begin // duplicate
                result <= 1'b1;
                error <= 1'b0;
                state <= WAIT_START;
            end
        end

        ERROR: begin
            error <= 1'b1;
            done <= 1'b1;
            state <= ERROR;
        end

        DONE: begin
            done <= 1'b1;
            state <= DONE;
        end

        default: state <= IDLE;
    endcase
end

assign result = result;
assign error = error;
assign done = done;

endmodule