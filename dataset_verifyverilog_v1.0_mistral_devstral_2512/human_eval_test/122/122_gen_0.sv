module sum_at_most_two_digits(
    input clk,
    input rst_n,
    input start,
    input [4:0] k,
    input [15:0] arr [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [15:0] sum;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd18;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (index == k - 1 || cycle_count >= MAX_CYCLES - 2)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and index management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            sum <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    sum <= 16'd0;
                    cycle_count <= 8'd0;
                end
                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (arr[index] < 16'd100)
                        sum <= sum + arr[index];
                    index <= index + 4'd1;
                end
                DONE_STATE: begin
                    result <= sum;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    index <= 4'd0;
                    sum <= 16'd0;
                    result <= 16'd0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule