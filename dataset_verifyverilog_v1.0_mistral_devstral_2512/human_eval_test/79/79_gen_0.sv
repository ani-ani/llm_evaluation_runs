module decimal_to_binary(
    input clk,
    input rst_n,
    input start,
    input [7:0] decimal,
    output reg [95:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CONVERT = 2'd1;
    localparam [1:0] BUILD_STRING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] binary [0:7];
    reg [7:0] char_map [0:11];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 96'd0;
            for (i = 0; i < 8; i = i + 1) begin
                binary[i] <= 8'd0;
            end
            for (i = 0; i < 12; i = i + 1) begin
                char_map[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CONVERT;
                end
            end

            CONVERT: begin
                // Convert decimal to binary
                for (i = 0; i < 8; i = i + 1) begin
                    binary[i] = decimal[i];
                end
                next_state = BUILD_STRING;
            end

            BUILD_STRING: begin
                // Build the string: db + 8 binary digits + db
                char_map[0] = 8'h64;  // 'd'
                char_map[1] = 8'h62;  // 'b'
                for (i = 0; i < 8; i = i + 1) begin
                    char_map[i + 2] = binary[i] ? 8'h31 : 8'h30;  // '1' or '0'
                end
                char_map[10] = 8'h64;  // 'd'
                char_map[11] = 8'h62;  // 'b'
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Construct the 96-bit result from char_map
    always @(posedge clk) begin
        if (state == BUILD_STRING) begin
            result[7:0] <= char_map[0];
            result[15:8] <= char_map[1];
            result[23:16] <= char_map[2];
            result[31:24] <= char_map[3];
            result[39:32] <= char_map[4];
            result[47:40] <= char_map[5];
            result[55:48] <= char_map[6];
            result[63:56] <= char_map[7];
            result[71:64] <= char_map[8];
            result[79:72] <= char_map[9];
            result[87:80] <= char_map[10];
            result[95:88] <= char_map[11];
        end
    end

endmodule