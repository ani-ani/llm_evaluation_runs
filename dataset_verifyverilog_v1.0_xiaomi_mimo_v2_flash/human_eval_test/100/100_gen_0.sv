module make_a_pile(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg [2:0] index,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTE   = 2'd1;
    localparam [1:0] FINISHED  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] current_n;
    reg [3:0] max_index;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            index <= 3'd0;
            done <= 1'b0;
            current_n <= 4'd0;
            max_index <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_n <= n;
                        if (n == 4'd0) begin
                            result <= 16'd0;
                            index <= 3'd0;
                            done <= 1'b1;
                        end else begin
                            max_index <= n - 4'd1;
                            result <= {12'd0, n};
                            index <= 3'd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (index < max_index) begin
                        result <= result + 16'd2;
                        index <= index + 3'd1;
                    end else begin
                        // Last level reached
                        done <= 1'b1;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    result <= 16'd0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && (n != 4'd0)) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTE: begin
                if (index == max_index) begin
                    next_state = FINISHED;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
endmodule