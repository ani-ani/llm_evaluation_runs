module max_filtered(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [2:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] index;
    reg [7:0] current_max;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            current_max <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPARE;
                        index <= 3'd0;
                        current_max <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        if (arr[index] != 8'd255) begin
                            if (arr[index] > current_max) begin
                                current_max <= arr[index];
                            end
                        end
                        index <= index + 3'd1;
                        next_state <= COMPARE;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= current_max;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule