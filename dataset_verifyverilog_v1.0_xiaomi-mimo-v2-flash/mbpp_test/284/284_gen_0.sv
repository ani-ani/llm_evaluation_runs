module AllEqualCheck (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [7:0] target,
    output reg result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [2:0] index;           // 0 to 7 for 8 elements
    reg match_flag;            // Starts HIGH, becomes LOW if mismatch
    reg [3:0] cycle_count;     // To enforce 16 cycle limit
    localparam [3:0] MAX_CYCLES = 4'd15;  // 0-15 = 16 cycles
    
    // State transition and next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPARE;
                else
                    next_state = IDLE;
            end
            COMPARE: begin
                if (index == 3'd7 || cycle_count >= MAX_CYCLES)
                    next_state = COMPLETE;
                else
                    next_state = COMPARE;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 3'd0;
            match_flag <= 1'b1;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    match_flag <= 1'b1;
                    cycle_count <= 4'd0;
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Compare current element with target
                    if (arr[index] != target) begin
                        match_flag <= 1'b0;
                    end
                    
                    // Increment index if not done
                    if (index < 3'd7 && cycle_count < MAX_CYCLES) begin
                        index <= index + 3'd1;
                    end
                end
                
                COMPLETE: begin
                    result <= match_flag;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule