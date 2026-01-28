module rotation_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE  = 2'd2;

    // Internal signals
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] rotation_count;
    reg found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 4'd0;
            rotation_count <= 4'd0;
            found <= 1'b0;
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
                    next_state = CHECK;
                    index = 4'd1;
                    rotation_count = 4'd0;
                    found = 1'b0;
                end
            end
            CHECK: begin
                if (index < len) begin
                    if (arr[index] < arr[index - 1]) begin
                        rotation_count = index;
                        found = 1'b1;
                    end
                    index = index + 4'd1;
                    if (index == len || found) begin
                        next_state = DONE;
                    end
                else begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 4'd0;
                    done <= 1'b0;
                end
                CHECK: begin
                    result <= 4'd0;
                    done <= 1'b0;
                end
                DONE: begin
                    result <= rotation_count;
                    done <= 1'b1;
                end
                default: begin
                    result <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule