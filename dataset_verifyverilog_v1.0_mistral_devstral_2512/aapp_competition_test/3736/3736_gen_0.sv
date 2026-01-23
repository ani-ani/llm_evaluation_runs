module mirror_checker(
    input clk,
    input rst_n,
    input start,
    input [127:0] string_in,
    input [4:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] i;
    reg [7:0] char_i, char_j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Helper function to check if char is mirror-symmetric
    function is_in_set;
        input [7:0] char;
        begin
            case(char)
                8'h41, 8'h48, 8'h49, 8'h4D, 8'h4F,
                8'h54, 8'h55, 8'h56, 8'h57, 8'h58,
                8'h59: is_in_set = 1'b1;
                default: is_in_set = 1'b0;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                        i <= 4'd0;
                        result <= 1'b1;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    char_i = string_in[i*8 +: 8];
                    char_j = string_in[(len-1-i)*8 +: 8];

                    if (!is_in_set(char_i)) begin
                        result <= 1'b0;
                        state <= DONE;
                    end else if (i != (len-1-i)) begin
                        if (!is_in_set(char_j) || (char_i != char_j)) begin
                            result <= 1'b0;
                            state <= DONE;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        i <= i + 4'd1;
                    end

                    if (i > ((len-1) >> 1) || cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    i <= 4'd0;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule