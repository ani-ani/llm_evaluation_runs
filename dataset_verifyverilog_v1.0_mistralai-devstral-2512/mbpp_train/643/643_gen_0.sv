module text_match_wordz_middle(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_data [0:15],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] SCAN   = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (len < 3) begin
                            next_state <= FINISH;
                            result <= 1'b0;
                        end else begin
                            next_state <= SCAN;
                            index <= 4'd1;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_data[index] == 8'd122) begin
                        result <= 1'b1;
                        next_state <= FINISH;
                    end else if (index == len - 2) begin
                        result <= 1'b0;
                        next_state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                        next_state <= SCAN;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule