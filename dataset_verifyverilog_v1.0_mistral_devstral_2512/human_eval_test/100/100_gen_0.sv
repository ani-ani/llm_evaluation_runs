module make_a_pile(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg [2:0] index,
    output reg done
);

    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] FINISHED = 2'd2;
    
    localparam [3:0] MAX_LEVELS = 4'd8;
    
    reg [1:0] state;
    reg [2:0] current_index;
    reg [15:0] current_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            index <= 3'd0;
            done <= 1'b0;
            current_index <= 3'd0;
            current_result <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_index <= 3'd0;
                        current_result <= {12'd0, n};
                        result <= current_result;
                        index <= current_index;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (current_index == (n - 1)) begin
                        done <= 1'b1;
                        state <= FINISHED;
                    end else begin
                        done <= 1'b0;
                        current_index <= current_index + 3'd1;
                        current_result <= current_result + 16'd2;
                        result <= current_result;
                        index <= current_index;
                    end
                end
                
                FINISHED: begin
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule