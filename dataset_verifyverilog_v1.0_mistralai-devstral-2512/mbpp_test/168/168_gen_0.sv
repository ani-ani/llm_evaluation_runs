module count_occurrences(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [7:0] target,
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COUNT   = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [7:0] count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 4'd0;
            count <= 8'd0;
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
                if (start) begin
                    next_state = COUNT;
                end
            end
            
            COUNT: begin
                if (index == len || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 4'd0;
            count <= 8'd0;
            cycle_count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (arr[index] == target) begin
                        count <= count + 8'd1;
                    end
                    index <= index + 4'd1;
                end
                
                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                end
                
                default: begin
                    index <= 4'd0;
                    count <= 8'd0;
                    cycle_count <= 8'd0;
                    result <= 8'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule