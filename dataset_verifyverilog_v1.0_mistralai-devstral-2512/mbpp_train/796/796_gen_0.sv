module dict_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] keys [0:7],
    input wire [15:0] values [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SUM = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] index;
    reg [15:0] sum;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 3'd0;
            sum <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and datapath logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SUM;
                    sum = 16'd0;
                    index = 3'd0;
                    cycle_count = 8'd0;
                end
            end

            SUM: begin
                if (index < len) begin
                    if (keys[index] != 8'd0) begin
                        sum = sum + values[index];
                    end
                    index = index + 3'd1;
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
                    done <= 1'b0;
                end

                SUM: begin
                    done <= 1'b0;
                end

                DONE_STATE: begin
                    result <= sum;
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