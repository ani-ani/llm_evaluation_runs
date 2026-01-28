module list_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] data_in,
    input wire [3:0] length,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PROCESS : IDLE;
            PROCESS: next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // result remains unchanged
                end
                PROCESS: begin
                    result <= length;
                    done <= 1'b0;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    // result maintained
                end
                default: begin
                    result <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule