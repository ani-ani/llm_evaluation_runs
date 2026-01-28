module BinarySearchLast(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [7:0] target,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] MID       = 3'd2;
    localparam [2:0] COMPARE   = 3'd3;
    localparam [2:0] FOUND     = 3'd4;
    localparam [2:0] NOT_FOUND = 3'd5;
    localparam [2:0] COMPLETE  = 3'd6;

    // Internal signals
    reg [2:0] state, next_state;
    reg [2:0] low, high, mid;
    reg [7:0] temp_result;
    reg [3:0] iter_count;
    localparam [3:0] MAX_ITER = 4'd16;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd255;
            done <= 1'b0;
            low <= 3'd0;
            high <= 3'd7;
            mid <= 3'd0;
            temp_result <= 8'd255;
            iter_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iter_count <= 4'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    low <= 3'd0;
                    high <= 3'd7;
                    temp_result <= 8'd255;
                    next_state <= MID;
                end

                MID: begin
                    mid <= (low + high) >> 1;
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    if (arr[mid] > target) begin
                        next_state <= NOT_FOUND;
                    end else if (arr[mid] < target) begin
                        next_state <= NOT_FOUND;
                    end else begin
                        next_state <= FOUND;
                    end
                end

                FOUND: begin
                    temp_result <= mid;
                    low <= mid + 3'd1;
                    next_state <= MID;
                end

                NOT_FOUND: begin
                    if (arr[mid] > target) begin
                        high <= mid - 3'd1;
                    end else begin
                        low <= mid + 3'd1;
                    end
                    next_state <= MID;
                end

                COMPLETE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Iteration counter and completion logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iter_count <= 4'd0;
        end else begin
            case (state)
                IDLE: iter_count <= 4'd0;
                INIT: iter_count <= 4'd1;
                MID: iter_count <= iter_count + 4'd1;
                COMPARE: ;
                FOUND: ;
                NOT_FOUND: ;
                COMPLETE: ;
                default: ;
            endcase
            
            // Check completion conditions
            if (state == MID && iter_count >= MAX_ITER) begin
                next_state <= COMPLETE;
            end else if (state == MID && low > high) begin
                next_state <= COMPLETE;
            end
        end
    end

endmodule