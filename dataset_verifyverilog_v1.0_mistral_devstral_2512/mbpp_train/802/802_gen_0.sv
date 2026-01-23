module rotation_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:7],
    input wire [3:0] array_len,
    output reg [3:0] rotation_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rotation_count <= 4'd0;
            done <= 1'b0;
            index <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CHECK;
                    index = 4'd1;
                    cycle_count = 4'd0;
                end
            end

            CHECK: begin
                if (index < array_len) begin
                    if (arr[index] < arr[index - 1]) begin
                        rotation_count = index;
                        next_state = FINISH;
                    end else begin
                        index = index + 4'd1;
                        cycle_count = cycle_count + 4'd1;
                    end
                end else begin
                    rotation_count = 4'd0;
                    next_state = FINISH;
                end
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule