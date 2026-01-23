module next_smallest (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] arr [0:7],
    input wire [2:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] FIND_MIN = 3'd2;
    localparam [2:0] FIND_NEXT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // State registers
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [2:0] idx;
    reg [31:0] min1;
    reg [31:0] min2;
    reg [31:0] current_val;
    reg start_prev;
    
    // Constants
    localparam [31:0] MAX_INT = 32'h7FFFFFFF;
    localparam [31:0] SENTINEL = 32'h80000000;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && !start_prev) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end
            INIT: begin
                if (len < 2'd2) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = FIND_MIN;
                end
            end
            FIND_MIN: begin
                if (idx >= len) begin
                    next_state = FIND_NEXT;
                end else begin
                    next_state = FIND_MIN;
                end
            end
            FIND_NEXT: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            idx <= 3'd0;
            min1 <= 32'd0;
            min2 <= 32'd0;
            current_val <= 32'd0;
            start_prev <= 1'b0;
        end else begin
            start_prev <= start;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // Result keeps its value until next operation
                end
                
                INIT: begin
                    idx <= 3'd0;
                    min1 <= MAX_INT;
                    min2 <= MAX_INT;
                    if (len < 2'd2) begin
                        result <= SENTINEL;
                    end
                end
                
                FIND_MIN: begin
                    current_val <= arr[idx];
                    idx <= idx + 3'd1;
                    
                    if (idx < len) begin
                        // Update min1 and min2
                        if (arr[idx] < min1 && arr[idx] != min1) begin
                            min2 <= min1;
                            min1 <= arr[idx];
                        end else if (arr[idx] < min2 && arr[idx] != min1 && arr[idx] != min2) begin
                            min2 <= arr[idx];
                        end
                    end
                end
                
                FIND_NEXT: begin
                    if (min2 == MAX_INT) begin
                        result <= SENTINEL;
                    end else begin
                        result <= min2;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // Initialize all registers to safe values
                    result <= 32'd0;
                    done <= 1'b0;
                    idx <= 3'd0;
                    min1 <= 32'd0;
                    min2 <= 32'd0;
                    current_val <= 32'd0;
                end
            endcase
        end
    end

endmodule