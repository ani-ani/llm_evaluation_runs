module count_X(
    input clk,
    input rst_n,
    input start,
    input [7:0] x,
    input [7:0] arr [0:15],
    input [4:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COUNT   = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] count;
    reg [4:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            count <= 8'd0;
            index <= 5'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = COUNT;
                    count = 8'd0;
                    index = 5'd0;
                    cycle_count = 8'd0;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COUNT: begin
                done <= 1'b0;
                if (index < len) begin
                    if (arr[index] == x) begin
                        count = count + 8'd1;
                    end
                    index = index + 5'd1;
                    cycle_count = cycle_count + 8'd1;
                    next_state = COUNT;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                result = count;
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                done <= 1'b0;
            end
        endcase
    end

endmodule