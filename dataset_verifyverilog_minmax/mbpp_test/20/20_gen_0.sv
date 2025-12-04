module woodall_checker (
    input clk,
    input rst_n,
    input [15:0] x_in,
    input start,
    output reg is_woodall,
    output reg done
);
    
    localparam IDLE = 0, CHECK_EVEN = 1, ADD_ONE = 2, DIVIDE = 3, CHECK_EQUAL = 4, DONE = 5;
    
    reg [2:0] state;
    reg [15:0] x_capture;
    reg [15:0] x;
    reg [15:0] p;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_woodall <= 0;
            done <= 0;
            x_capture <= 0;
            x <= 0;
            p <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        x_capture <= x_in;
                        state <= CHECK_EVEN;
                        done <= 0;
                    end
                    else begin
                        state <= IDLE;
                    end
                end
                
                CHECK_EVEN: begin
                    if (x_capture[0] == 1'b0 || x_capture == 0) begin
                        is_woodall <= 0;
                        done <= 1;
                        state <= DONE;
                    end
                    else begin
                        state <= ADD_ONE;
                    end
                end
                
                ADD_ONE: begin
                    x <= x_capture + 1;
                    p <= 0;
                    state <= DIVIDE;
                end
                
                DIVIDE: begin
                    if ((p + 1) > (x >> 1)) begin
                        is_woodall <= 0;
                        done <= 1;
                        state <= DONE;
                    end
                    else begin
                        x <= x >> 1;
                        p <= p + 1;
                        if ((x >> 1) & 1) begin
                            state <= CHECK_EQUAL;
                        end
                        else begin
                            state <= DIVIDE;
                        end
                    end
                end
                
                CHECK_EQUAL: begin
                    if (p == x) begin
                        is_woodall <= 1;
                    end
                    else begin
                        is_woodall <= 0;
                    end
                    done <= 1;
                    state <= DONE;
                end
                
                DONE: begin
                    if (start) begin
                        x_capture <= x_in;
                        state <= CHECK_EVEN;
                        done <= 0;
                    end
                    else begin
                        state <= DONE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule