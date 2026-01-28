module obfuscation_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] char_0,
    input wire [4:0] char_1,
    input wire [4:0] char_2,
    input wire [4:0] char_3,
    input wire [4:0] char_4,
    input wire [4:0] char_5,
    input wire [4:0] char_6,
    input wire [4:0] char_7,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROC = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [2:0] index;
    reg [7:0] seen;
    reg [2:0] next_expected;
    reg [2:0] cycle_counter;
    localparam [2:0] MAX_CYCLES = 3'd7;

    wire [4:0] current_char;
    assign current_char = (index == 3'd0) ? char_0 :
                          (index == 3'd1) ? char_1 :
                          (index == 3'd2) ? char_2 :
                          (index == 3'd3) ? char_3 :
                          (index == 3'd4) ? char_4 :
                          (index == 3'd5) ? char_5 :
                          (index == 3'd6) ? char_6 :
                          char_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            seen <= 8'd0;
            next_expected <= 3'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_counter <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 3'd0;
                    if (start) begin
                        state <= PROC;
                        index <= 3'd0;
                        seen <= 8'd0;
                        next_expected <= 3'd0;
                        result <= 1'b1;
                    end
                end

                PROC: begin
                    if (index < len) begin
                        if (seen[current_char[2:0]]) begin
                            index <= index + 3'd1;
                        end else begin
                            if (current_char[2:0] == next_expected) begin
                                seen <= seen | (8'd1 << current_char[2:0]);
                                next_expected <= next_expected + 3'd1;
                                index <= index + 3'd1;
                            end else begin
                                result <= 1'b0;
                                state <= DONE;
                                done <= 1'b1;
                            end
                        end
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule