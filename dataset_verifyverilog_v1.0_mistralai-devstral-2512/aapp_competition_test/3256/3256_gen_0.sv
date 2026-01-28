module bits_game #(parameter N=8, parameter WIDTH=8) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WIDTH-1:0] A [0:N-1],
    input wire [3:0] K,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] UPDATE  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [15:0] best_result;
    reg [15:0] current_mask;
    reg [7:0] i, j;
    reg [15:0] current_or;
    reg [3:0] segment_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            best_result <= 16'd0;
            current_mask <= 16'd0;
            i <= 8'd0;
            j <= 8'd0;
            current_or <= 16'd0;
            segment_count <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = CHECK;
                    best_result = 16'd0;
                    current_mask = 16'd0;
                    i = 8'd0;
                    j = 8'd0;
                    current_or = 16'd0;
                    segment_count = 4'd0;
                    cycle_count = 8'd0;
                end
            end

            CHECK: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    cycle_count = cycle_count + 8'd1;
                    if (i == 8'd0) begin
                        current_mask = 16'd0;
                        j = 8'd0;
                        current_or = 16'd0;
                        segment_count = 4'd0;
                    end else begin
                        if (j < 8'd8) begin
                            if ((A[j] & current_mask) == current_mask) begin
                                current_or = current_or | A[j];
                                if ((current_or & current_mask) == current_mask) begin
                                    segment_count = segment_count + 4'd1;
                                    current_or = 16'd0;
                                end
                            end
                            j = j + 8'd1;
                        end else begin
                            if (segment_count >= K) begin
                                next_state = UPDATE;
                            end else begin
                                i = i + 8'd1;
                                current_mask = current_mask + 16'd1;
                            end
                        end
                    end
                end
            end

            UPDATE: begin
                best_result = current_mask;
                i = 8'd0;
                next_state = CHECK;
            end

            DONE_STATE: begin
                done <= 1'b1;
                result <= best_result;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule