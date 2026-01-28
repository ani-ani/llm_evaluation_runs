module ArraySearch(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] K,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SEARCHING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [2:0] index;
    reg found;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SEARCHING;
                else
                    next_state = IDLE;
            end
            
            SEARCHING: begin
                if (found || index == len - 1)
                    next_state = DONE_STATE;
                else
                    next_state = SEARCHING;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            found <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    index <= 3'd0;
                    found <= 1'b0;
                end
                
                SEARCHING: begin
                    done <= 1'b0;
                    if (!found) begin
                        if (arr[index] == K) begin
                            found <= 1'b1;
                            result <= 1'b1;
                        end
                        index <= index + 3'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= found;
                end
                
                default: begin
                    state <= IDLE;
                    index <= 3'd0;
                    found <= 1'b0;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule