module parity_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CHECK   = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [2:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Parity check logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK;
                else
                    next_state = IDLE;
            end

            CHECK: begin
                if (index == 3'd7 || !((arr[index] % 2'd2) == (index % 2'd2)))
                    next_state = FINISH;
                else
                    next_state = CHECK;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    index <= 3'd0;
                    cycle_count <= 8'd0;
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index == 3'd7 || !((arr[index] % 2'd2) == (index % 2'd2))) begin
                        if (index == 3'd7 && (arr[index] % 2'd2) == (index % 2'd2))
                            result <= 1'b1;
                        else
                            result <= 1'b0;
                    end else begin
                        index <= index + 3'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                    index <= 3'd0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule