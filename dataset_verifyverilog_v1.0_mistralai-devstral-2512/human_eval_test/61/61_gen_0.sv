module bracket_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] string_in,
    input wire [3:0] length,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_CHAR = 2'd1;
    localparam [1:0] CHECK_RESULT = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [7:0] balance;
    reg [7:0] current_char;
    reg [7:0] char_count;

    // ASCII values
    localparam [7:0] OPEN_BRACKET = 8'd40;
    localparam [7:0] CLOSE_BRACKET = 8'd41;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            balance <= 8'd0;
            current_char <= 8'd0;
            char_count <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        state <= CHECK_CHAR;
                        index <= 4'd0;
                        balance <= 8'd0;
                        char_count <= 8'd0;
                    end
                end

                CHECK_CHAR: begin
                    // Load current character
                    current_char <= string_in[(index * 8) +: 8];
                    char_count <= char_count + 8'd1;

                    // Check for open bracket
                    if (current_char == OPEN_BRACKET) begin
                        balance <= balance + 8'd1;
                    end
                    // Check for close bracket
                    else if (current_char == CLOSE_BRACKET) begin
                        balance <= balance - 8'd1;
                    end

                    // Check if we've processed all characters
                    if (char_count == length) begin
                        state <= CHECK_RESULT;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                CHECK_RESULT: begin
                    // Check if balance is zero and never went negative
                    if (balance == 8'd0 && balance[7] == 1'b0) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule