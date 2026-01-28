module first_missing_natural(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] UPDATE  = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    // Registers
    reg [2:0] state, next_state;
    reg [7:0] low, high, mid;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            low <= 8'd0;
            high <= 8'd7;
            mid <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                if (low <= high) begin
                    mid = (low + high) >> 1;
                    next_state = UPDATE;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            UPDATE: begin
                if (arr[mid] == mid) begin
                    low = mid + 1;
                end else begin
                    high = mid - 1;
                end
                next_state = COMPARE;
            end
            
            DONE_STATE: begin
                done = 1'b1;
                result = low;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state == COMPARE || state == UPDATE) begin
            if (cycle_count >= MAX_CYCLES) begin
                cycle_count <= 8'd0;
                next_state = DONE_STATE;
            end else begin
                cycle_count <= cycle_count + 8'd1;
            end
        end else begin
            cycle_count <= 8'd0;
        end
    end
    
endmodule