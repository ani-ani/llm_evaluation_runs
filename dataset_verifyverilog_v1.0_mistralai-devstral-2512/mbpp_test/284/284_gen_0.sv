module array_compare(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [7:0] target,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPARE  = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    // Internal signals
    reg [1:0] state;
    reg [2:0] index;
    reg match_flag;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            match_flag <= 1'b1;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= COMPARE;
                        index <= 3'd0;
                        match_flag <= 1'b1;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Compare current element
                    if (arr[index] != target) begin
                        match_flag <= 1'b0;
                    end
                    
                    // Move to next element or complete
                    if (index == 3'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end else begin
                        index <= index + 3'd1;
                    end
                end
                
                COMPLETE: begin
                    result <= match_flag;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule