module digit_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] sum;
    reg [2:0] index;
    reg negative_flag;
    reg [7:0] current_char;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum <= 16'd0;
            index <= 3'd0;
            negative_flag <= 1'b0;
            done <= 1'b0;
            result <= 16'd0;
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
                    next_state = PROCESS;
                    sum = 16'd0;
                    index = 3'd0;
                    negative_flag = 1'b0;
                    done = 1'b0;
                end
            end
            PROCESS: begin
                current_char = arr[index];
                if (current_char >= 8'd48 && current_char <= 8'd57) begin
                    // ASCII '0'-'9'
                    if (negative_flag) begin
                        sum = sum - (current_char - 8'd48);
                    end else begin
                        sum = sum + (current_char - 8'd48);
                    end
                    negative_flag = 1'b0;
                end else if (current_char == 8'd45) begin
                    // ASCII '-'
                    negative_flag = 1'b1;
                end else if (current_char == 8'd43) begin
                    // ASCII '+'
                    negative_flag = 1'b0;
                end
                // Skip all other characters

                if (index == 3'd7) begin
                    next_state = DONE_STATE;
                    result = sum;
                end else begin
                    index = index + 3'd1;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
                done = 1'b1;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule