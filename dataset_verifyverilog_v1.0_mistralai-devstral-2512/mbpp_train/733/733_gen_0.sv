module binary_search_fsm(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [7:0] arr_8,
    input wire [7:0] arr_9,
    input wire [7:0] x,
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] LOOP      = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] COMPLETE  = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] left, right, mid;
    reg [7:0] arr_mid;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Array access combinational logic
    always @(*) begin
        case (mid)
            4'd0: arr_mid = arr_0;
            4'd1: arr_mid = arr_1;
            4'd2: arr_mid = arr_2;
            4'd3: arr_mid = arr_3;
            4'd4: arr_mid = arr_4;
            4'd5: arr_mid = arr_5;
            4'd6: arr_mid = arr_6;
            4'd7: arr_mid = arr_7;
            4'd8: arr_mid = arr_8;
            4'd9: arr_mid = arr_9;
            default: arr_mid = 8'd0;
        endcase
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
            end
            INIT: begin
                next_state = LOOP;
            end
            LOOP: begin
                next_state = CHECK;
            end
            CHECK: begin
                if (left <= right)
                    next_state = UPDATE;
                else
                    next_state = COMPLETE;
            end
            UPDATE: begin
                next_state = LOOP;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd255;
            done <= 1'b0;
            left <= 4'd0;
            right <= 4'd0;
            mid <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    // Wait for start
                end
                INIT: begin
                    left <= 4'd0;
                    right <= len - 4'd1;
                    result <= 8'd255;
                    cycle_count <= 8'd0;
                end
                LOOP: begin
                    mid <= (left + right) >> 1;
                    cycle_count <= cycle_count + 8'd1;
                end
                CHECK: begin
                    if (arr_mid == x) begin
                        result <= mid;
                        right <= mid - 4'd1;
                    end else if (x < arr_mid) begin
                        right <= mid - 4'd1;
                    end else begin
                        left <= mid + 4'd1;
                    end
                end
                UPDATE: begin
                    // State transition handled in next_state logic
                end
                COMPLETE: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule