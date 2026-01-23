module hex_key_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] len,
    output reg [4:0] result,
    output reg done,
    output reg [3:0] char_addr
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] next_addr;
    reg [4:0] next_result;
    reg next_done;

    // Prime hex digits in ASCII
    localparam [7:0] PRIME_2 = 8'h32;
    localparam [7:0] PRIME_3 = 8'h33;
    localparam [7:0] PRIME_5 = 8'h35;
    localparam [7:0] PRIME_7 = 8'h37;
    localparam [7:0] PRIME_B = 8'h42;
    localparam [7:0] PRIME_D = 8'h44;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            char_addr <= 4'd0;
        end else begin
            state <= state;
            result <= result;
            done <= done;
            char_addr <= char_addr;
        end
    end

    always @(*) begin
        next_addr = char_addr;
        next_result = result;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_addr = 4'd0;
                    next_result = 5'd0;
                    state = PROCESSING;
                end
            end

            PROCESSING: begin
                // Check if current character is a prime hex digit
                if (char_in == PRIME_2 || char_in == PRIME_3 || 
                    char_in == PRIME_5 || char_in == PRIME_7 || 
                    char_in == PRIME_B || char_in == PRIME_D) begin
                    next_result = result + 5'd1;
                end

                // Increment address
                next_addr = char_addr + 4'd1;

                // Check if done
                if (next_addr >= len) begin
                    state = DONE;
                end
            end

            DONE: begin
                next_done = 1'b1;
                state = IDLE;
            end

            default: state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (rst_n) begin
            char_addr <= next_addr;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule