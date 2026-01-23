module Find_Min_Length #(
    parameter NUM_LISTS = 4,
    parameter MAX_LEN = 8,
    parameter LEN_WIDTH = 4
) (
    input clk,
    input rst_n,
    input start,
    input [LEN_WIDTH-1:0] lengths [0:NUM_LISTS-1],
    output reg [LEN_WIDTH-1:0] min_length,
    output reg done
);
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [LEN_WIDTH-1:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_length <= {LEN_WIDTH{1'b0}};
            counter <= {LEN_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        min_length <= lengths[0];
                        if (NUM_LISTS == 1) begin
                            state <= DONE_STATE;
                        end else begin
                            counter <= 1;
                            state <= COMPARE;
                        end
                    end
                end
                COMPARE: begin
                    done <= 1'b0;
                    if (counter < NUM_LISTS) begin
                        if (lengths[counter] < min_length) begin
                            min_length <= lengths[counter];
                        end
                        counter <= counter + 1;
                        if ((counter + 1) < NUM_LISTS) begin
                            state <= COMPARE;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule