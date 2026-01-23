module same_chars (
    input clk,
    input rst_n,
    input start,
    input [7:0] s0 [0:7],
    input [7:0] s1 [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SETUP   = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] DONE_ST = 3'd3;
    
    reg [2:0] state, next_state;
    reg [2:0] counter;
    reg [255:0] mask0;
    reg [255:0] mask1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 3'd0;
            mask0 <= 256'd0;
            mask1 <= 256'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) next_state <= SETUP;
                    else next_state <= IDLE;
                end
                
                SETUP: begin
                    counter <= 3'd0;
                    mask0 <= 256'd0;
                    mask1 <= 256'd0;
                    next_state <= PROCESS;
                end
                
                PROCESS: begin
                    // Set corresponding bits
                    mask0 <= mask0 | (256'd1 << s0[counter]);
                    mask1 <= mask1 | (256'd1 << s1[counter]);
                    
                    if (counter == 3'd7) begin
                        next_state <= DONE_ST;
                    end else begin
                        counter <= counter + 3'd1;
                        next_state <= PROCESS;
                    end
                end
                
                DONE_ST: begin
                    result <= (mask0 == mask1);
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule
