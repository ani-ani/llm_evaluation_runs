module uniformity_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPARE   = 2'd1;
    localparam [1:0] COMPLETE  = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg reg_result;
    reg [7:0] ref_value;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (len <= 4'd1) begin
                        next_state = COMPLETE;
                    end else begin
                        next_state = COMPARE;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPARE: begin
                if (index >= len - 4'd1) begin
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
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            reg_result <= 1'b0;
            ref_value <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (len <= 4'd1) begin
                            reg_result <= 1'b1;
                        end else begin
                            ref_value <= arr[0];
                            reg_result <= 1'b1;
                            index <= 4'd1;
                        end
                    end
                end
                
                COMPARE: begin
                    if (arr[index] != ref_value) begin
                        reg_result <= 1'b0;
                    end
                    index <= index + 4'd1;
                end
                
                COMPLETE: begin
                    result <= reg_result;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    index <= 4'd0;
                    reg_result <= 1'b0;
                    ref_value <= 8'd0;
                end
            endcase
        end
    end

endmodule