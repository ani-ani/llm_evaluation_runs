module sequential_search(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [7:0] item,
    input [3:0] len,
    output reg found,
    output reg [3:0] index,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] current_index;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 4'd0;
            cycle_count <= 4'd0;
            found <= 1'b0;
            index <= 4'd0;
            done <= 1'b0;
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
                    next_state = CHECKING;
                end
            end

            CHECKING: begin
                if (arr[current_index] == item) begin
                    next_state = COMPLETE;
                end else if (current_index == len - 1) begin
                    next_state = COMPLETE;
                end else if (cycle_count >= MAX_CYCLES - 1) begin
                    next_state = COMPLETE;
                end
            end

            COMPLETE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_index <= 4'd0;
            cycle_count <= 4'd0;
            found <= 1'b0;
            index <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    current_index <= 4'd0;
                    cycle_count <= 4'd0;
                    found <= 1'b0;
                    done <= 1'b0;
                end

                CHECKING: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (arr[current_index] == item) begin
                        found <= 1'b1;
                        index <= current_index;
                    end else if (current_index == len - 1) begin
                        found <= 1'b0;
                    end
                    current_index <= current_index + 4'd1;
                end

                COMPLETE: begin
                    done <= 1'b1;
                end

                default: begin
                    current_index <= 4'd0;
                    cycle_count <= 4'd0;
                    found <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule