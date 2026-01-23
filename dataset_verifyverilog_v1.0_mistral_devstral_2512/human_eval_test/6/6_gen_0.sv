module parse_nested_parens(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] COMPLETE   = 2'd2;

    // Character encoding constants
    localparam [7:0] SPACE = 8'd32;
    localparam [7:0] OPEN  = 8'd40;
    localparam [7:0] CLOSE = 8'd41;

    // Internal signals
    reg [1:0] state;
    reg [3:0] current_index;
    reg [3:0] current_depth;
    reg [3:0] max_depth;
    reg in_group;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 4'd0;
            current_depth <= 4'd0;
            max_depth <= 4'd0;
            in_group <= 1'b0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        current_index <= 4'd0;
                        current_depth <= 4'd0;
                        max_depth <= 4'd0;
                        in_group <= 1'b0;
                    end
                end

                PROCESSING: begin
                    // Process current character
                    if (char_array[current_index] == OPEN) begin
                        if (!in_group) begin
                            in_group <= 1'b1;
                            current_depth <= 4'd1;
                        end else begin
                            current_depth <= current_depth + 4'd1;
                        end
                        if (current_depth > max_depth) begin
                            max_depth <= current_depth;
                        end
                    end else if (char_array[current_index] == CLOSE) begin
                        if (in_group) begin
                            current_depth <= current_depth - 4'd1;
                            if (current_depth == 4'd0) begin
                                in_group <= 1'b0;
                            end
                        end
                    end else if (char_array[current_index] == SPACE) begin
                        in_group <= 1'b0;
                        current_depth <= 4'd0;
                    end

                    // Move to next character or complete
                    if (current_index == 4'd15) begin
                        state <= COMPLETE;
                        result <= max_depth;
                    end else begin
                        current_index <= current_index + 4'd1;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule