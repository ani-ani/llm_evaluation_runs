module uniform_check(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [2:0] index;
    reg [7:0] reference;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 3'd0;
            reference <= 8'd0;
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
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                if (index == len - 1 || len <= 1) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 3'd0;
            reference <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (index == 0) begin
                        reference <= arr[0];
                        result <= 1'b1;
                    end else begin
                        if (arr[index] != reference) begin
                            result <= 1'b0;
                        end
                    end
                    
                    if (index < len - 1 && len > 1) begin
                        index <= index + 3'd1;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    index <= 3'd0;
                end
                
                default: begin
                    index <= 3'd0;
                    reference <= 8'd0;
                    result <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule