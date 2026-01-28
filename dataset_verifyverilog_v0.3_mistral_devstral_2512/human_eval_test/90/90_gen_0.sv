module next_smallest(
    input clk,
    input rst_n,
    input start,
    input [31:0] arr [0:7],
    input [2:0] len,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] FIND_MIN = 3'd2;
    localparam [2:0] FIND_NEXT = 3'd3;
    localparam [2:0] DONE     = 3'd4;

    // Constants
    localparam [31:0] MAX_INT = 32'd2147483647;
    localparam [31:0] MIN_INT = 32'd2147483648;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] min1, min2;
    reg [2:0] idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= MIN_INT;
            done <= 1'b0;
            min1 <= MAX_INT;
            min2 <= MAX_INT;
            idx <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    min1 <= MAX_INT;
                    min2 <= MAX_INT;
                    idx <= 3'd0;
                    
                    if (len < 3'd2) begin
                        result <= MIN_INT;
                        next_state <= DONE;
                    end else begin
                        next_state <= FIND_MIN;
                    end
                end

                FIND_MIN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (arr[idx] < min1) begin
                        min2 <= min1;
                        min1 <= arr[idx];
                    end else if (arr[idx] < min2 && arr[idx] != min1) begin
                        min2 <= arr[idx];
                    end
                    
                    if (idx == len - 3'd1) begin
                        next_state <= FIND_NEXT;
                    end else begin
                        idx <= idx + 3'd1;
                        next_state <= FIND_MIN;
                    end
                end

                FIND_NEXT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (min2 == MAX_INT) begin
                        result <= MIN_INT;
                    end else begin
                        result <= min2;
                    end
                    
                    next_state <= DONE;
                end

                DONE: begin
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

endmodule