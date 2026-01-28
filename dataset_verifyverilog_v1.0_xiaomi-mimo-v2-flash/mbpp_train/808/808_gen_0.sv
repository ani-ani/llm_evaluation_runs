module SearchArray (
    input clk,
    input rst_n,
    input start,
    input [7:0] K,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCHING = 2'd1;
    localparam [1:0] FINISHED = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;
    reg found;
    reg [3:0] cycle_count;

    // FSM State Transition
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SEARCHING;
                else
                    next_state = IDLE;
            end
            SEARCHING: begin
                if (found || (index >= len))
                    next_state = FINISHED;
                else
                    next_state = SEARCHING;
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            found <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    found <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 4'd0;
                end

                SEARCHING: begin
                    if (!found && (index < len)) begin
                        if (arr[index] == K) begin
                            found <= 1'b1;
                            result <= 1'b1;
                            index <= index + 4'd1; // Increment to handle logic
                        end else begin
                            index <= index + 4'd1;
                        end
                    end else if (found) begin
                        // Found early, just advance index to finish loop
                        if (index < len)
                            index <= index + 4'd1;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule