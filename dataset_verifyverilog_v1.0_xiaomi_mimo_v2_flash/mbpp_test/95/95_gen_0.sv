module Find_Min_Length #(
    parameter NUM_LISTS = 4,
    parameter MAX_LEN = 8,
    parameter LEN_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [NUM_LISTS-1:0][LEN_WIDTH-1:0] lengths,
    output reg [LEN_WIDTH-1:0] min_length,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD_FIRST = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state, next_state;
    reg [LEN_WIDTH-1:0] current_min;
    reg [3:0] index;  // Counter for iterating through NUM_LISTS (max 16)
    reg [3:0] max_index;  // NUM_LISTS - 1
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_FIRST;
                else
                    next_state = IDLE;
            end
            
            LOAD_FIRST: begin
                if (NUM_LISTS == 1)
                    next_state = FINISH;
                else
                    next_state = COMPARE;
            end
            
            COMPARE: begin
                if (index == max_index)
                    next_state = FINISH;
                else
                    next_state = COMPARE;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_length <= {LEN_WIDTH{1'b0}};
            current_min <= {LEN_WIDTH{1'b0}};
            index <= 4'd0;
            max_index <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    if (start) begin
                        max_index <= (NUM_LISTS > 1) ? NUM_LISTS - 1 : 4'd0;
                    end
                end
                
                LOAD_FIRST: begin
                    current_min <= lengths[0];
                    if (NUM_LISTS > 1)
                        index <= 4'd1;  // Start comparing from element 1
                    else
                        index <= 4'd0;
                end
                
                COMPARE: begin
                    if (lengths[index] < current_min) begin
                        current_min <= lengths[index];
                    end
                    index <= index + 4'd1;
                end
                
                FINISH: begin
                    min_length <= current_min;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule