module wire_untangle (
    input clk,
    input rst_n,
    input start,
    input char_in,
    input valid_in,
    input last,
    output reg done,
    output reg result
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [15:0] stack_data;
    reg [4:0] stack_depth;
    reg finished;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            stack_data <= 16'd0;
            stack_depth <= 5'd0;
            done <= 1'b0;
            result <= 1'b0;
            finished <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    finished <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        stack_data <= 16'd0;
                        stack_depth <= 5'd0;
                        result <= 1'b0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (valid_in && !finished) begin
                        if (stack_depth != 0 && stack_data[0] == char_in) begin
                            stack_data <= {1'b0, stack_data[15:1]};
                            stack_depth <= stack_depth - 1;
                        end else begin
                            if (stack_depth < 16) begin
                                stack_data <= {stack_data[14:0], char_in};
                                stack_depth <= stack_depth + 1;
                            end
                        end
                        
                        if (last) begin
                            state <= FINISH;
                            finished <= 1'b1;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        finished <= 1'b1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= (stack_depth == 0) ? 1'b1 : 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule