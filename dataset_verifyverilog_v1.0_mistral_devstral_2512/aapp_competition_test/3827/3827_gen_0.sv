module string_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [4:0] str_len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] count_a;
    reg [3:0] count_b;
    reg [3:0] count_c;
    reg [3:0] index;
    reg error;
    reg [7:0] current_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count_a <= 4'd0;
            count_b <= 4'd0;
            count_c <= 4'd0;
            index <= 4'd0;
            error <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        count_a <= 4'd0;
                        count_b <= 4'd0;
                        count_c <= 4'd0;
                        error <= 1'b0;
                    end
                end

                PROCESS: begin
                    if (index < str_len) begin
                        current_char = char_array[index];
                        index <= index + 4'd1;

                        // Check current state and character
                        if (state == IDLE) begin
                            if (current_char == 8'd97) begin  // 'a'
                                count_a <= count_a + 4'd1;
                            end else if (current_char == 8'd98) begin  // 'b'
                                state <= PROCESS;
                                count_b <= count_b + 4'd1;
                            end else if (current_char == 8'd99) begin  // 'c'
                                error <= 1'b1;
                            end else begin
                                error <= 1'b1;
                            end
                        end else if (state == PROCESS) begin
                            if (current_char == 8'd98) begin  // 'b'
                                count_b <= count_b + 4'd1;
                            end else if (current_char == 8'd99) begin  // 'c'
                                state <= PROCESS;
                                count_c <= count_c + 4'd1;
                            end else begin
                                error <= 1'b1;
                            end
                        end else begin
                            if (current_char == 8'd99) begin  // 'c'
                                count_c <= count_c + 4'd1;
                            end else begin
                                error <= 1'b1;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Validate the string
                    if (!error && count_a >= 4'd1 && count_b >= 4'd1 && 
                        (count_c == count_a || count_c == count_b)) begin
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