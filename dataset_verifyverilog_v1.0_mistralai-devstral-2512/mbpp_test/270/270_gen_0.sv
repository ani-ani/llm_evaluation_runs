module sum_even_positions(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] index;
    reg [15:0] accumulator;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and computation logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = COMPUTING;
                    index = 3'd0;
                    accumulator = 16'd0;
                    cycle_count = 8'd0;
                end
            end

            COMPUTING: begin
                if (index < len && index[0] == 1'b0) begin
                    if (arr[index][0] == 1'b0) begin
                        accumulator = accumulator + arr[index];
                    end
                    index = index + 2'd2;
                    cycle_count = cycle_count + 8'd1;
                    
                    if (index >= len || cycle_count >= MAX_CYCLES) begin
                        next_state = DONE_STATE;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 16'd0;
                    done <= 1'b0;
                end

                COMPUTING: begin
                    result <= 16'd0;
                    done <= 1'b0;
                end

                DONE_STATE: begin
                    result <= accumulator;
                    done <= 1'b1;
                end

                default: begin
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule